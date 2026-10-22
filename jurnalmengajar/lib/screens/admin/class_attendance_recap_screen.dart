import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';
import '../../models/class_model.dart';
import '../../models/class_attendance_recap_model.dart';
import '../../models/journal_model.dart';
import '../../models/schedule_model.dart';
import '../../models/period_model.dart';
import '../../models/student_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../services/excel_export_service.dart';
import '../../services/journal_pdf_service.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/admin_period_selector_bar.dart';
import '../../widgets/app_scaffold.dart';

enum AttendanceTimeFilter { allPeriod, thisMonth, lastMonth, custom }

enum StudentSortBy { nameAsc, alphaDesc, sickDesc, permDesc, rateAsc, rateDesc }

class AdminClassAttendanceRecapScreen extends StatefulWidget {
  final String? initialClassId;

  const AdminClassAttendanceRecapScreen({super.key, this.initialClassId});

  @override
  State<AdminClassAttendanceRecapScreen> createState() =>
      _AdminClassAttendanceRecapScreenState();
}

class _AdminClassAttendanceRecapScreenState
    extends State<AdminClassAttendanceRecapScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedPeriodId;
  String? _selectedClassId;
  int _viewModeIndex = 0; // 0: Ringkasan Kelas, 1: Detail Kelas Terpilih
  int _detailSubTabIndex = 0; // 0: Rekap Siswa, 1: Log Pertemuan

  final TextEditingController _classSearchController = TextEditingController();
  final TextEditingController _studentSearchController =
      TextEditingController();

  String _classSearchQuery = '';
  String _studentSearchQuery = '';

  AttendanceTimeFilter _timeFilter = AttendanceTimeFilter.allPeriod;
  DateTimeRange? _customDateRange;

  String? _selectedSubjectId;
  String? _selectedTeacherId;
  StudentSortBy _studentSortBy = StudentSortBy.nameAsc;

  bool get _hasViewedClass =>
      _selectedClassId != null && _selectedClassId!.isNotEmpty;

  final Map<String, List<StudentModel>> _studentsCache = {};
  bool _isLoadingStudents = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.initialClassId;
    if (_selectedClassId != null && _selectedClassId!.isNotEmpty) {
      _viewModeIndex = 1;
    }

    _classSearchController.addListener(() {
      setState(() {
        _classSearchQuery = _classSearchController.text.trim().toLowerCase();
      });
    });

    _studentSearchController.addListener(() {
      setState(() {
        _studentSearchQuery = _studentSearchController.text
            .trim()
            .toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  @override
  void dispose() {
    _classSearchController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    final journalProvider = Provider.of<JournalProvider>(
      context,
      listen: false,
    );
    final scheduleProvider = Provider.of<ScheduleProvider>(
      context,
      listen: false,
    );

    final schoolId = authProvider.activeSchoolId;
    if (schoolId != null && schoolId.isNotEmpty) {
      await Future.wait([
        masterProvider.loadAllData(schoolId),
        journalProvider.loadAllJournals(schoolId),
        scheduleProvider.loadAllSchedules(schoolId),
      ]);
    }

    // Set default period
    if (_selectedPeriodId == null && masterProvider.periods.isNotEmpty) {
      final active = masterProvider.periods.firstWhere(
        (p) => p.isActive,
        orElse: () => masterProvider.periods.first,
      );
      setState(() {
        _selectedPeriodId = active.id;
      });
    }

    if (_selectedClassId != null && _selectedClassId!.isNotEmpty) {
      await _loadStudentsForClass(_selectedClassId!);
    }
  }

  Future<void> _loadStudentsForClass(String classId) async {
    if (_studentsCache.containsKey(classId)) return;
    setState(() => _isLoadingStudents = true);
    try {
      final masterProvider = Provider.of<MasterDataProvider>(
        context,
        listen: false,
      );
      final students = await masterProvider.studentRepository.getAllByClass(
        classId,
      );
      if (mounted) {
        setState(() {
          _studentsCache[classId] = students;
        });
      }
    } catch (e) {
      debugPrint(
        '[REKAP_KEHADIRAN] Error load students for class $classId: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingStudents = false);
      }
    }
  }

  // ── Helper Getters & Filters ────────────────────────────────────────────────
  List<PeriodModel> _getSortedPeriods(List<PeriodModel> periods) {
    final list = List<PeriodModel>.from(periods);
    list.sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return b.name.compareTo(a.name);
    });
    return list;
  }

  PeriodModel? _getSelectedPeriod(List<PeriodModel> periods) {
    if (periods.isEmpty) return null;
    return periods.firstWhere(
      (p) => p.id == _selectedPeriodId,
      orElse: () =>
          periods.firstWhere((p) => p.isActive, orElse: () => periods.first),
    );
  }

  bool _matchesTimeFilter(DateTime date) {
    final now = DateTime.now();
    switch (_timeFilter) {
      case AttendanceTimeFilter.allPeriod:
        return true;
      case AttendanceTimeFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case AttendanceTimeFilter.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        return date.year == lastMonth.year && date.month == lastMonth.month;
      case AttendanceTimeFilter.custom:
        if (_customDateRange == null) return true;
        final d = DateTime(date.year, date.month, date.day);
        final start = DateTime(
          _customDateRange!.start.year,
          _customDateRange!.start.month,
          _customDateRange!.start.day,
        );
        final end = DateTime(
          _customDateRange!.end.year,
          _customDateRange!.end.month,
          _customDateRange!.end.day,
        );
        return (d.isAtSameMomentAs(start) || d.isAfter(start)) &&
            (d.isAtSameMomentAs(end) || d.isBefore(end));
    }
  }

  String _getTimeFilterLabel() {
    switch (_timeFilter) {
      case AttendanceTimeFilter.allPeriod:
        return 'Semua Periode';
      case AttendanceTimeFilter.thisMonth:
        return 'Bulan Ini';
      case AttendanceTimeFilter.lastMonth:
        return 'Bulan Lalu';
      case AttendanceTimeFilter.custom:
        if (_customDateRange != null) {
          final f = DateFormat('dd/MM/yy');
          return '${f.format(_customDateRange!.start)} - ${f.format(_customDateRange!.end)}';
        }
        return 'Kustom';
    }
  }

  /// Journals for the selected period
  List<JournalModel> _getJournalsForPeriod(
    List<JournalModel> allJournals,
    ScheduleProvider scheduleProvider,
    String? periodId,
  ) {
    return allJournals.where((j) {
      if (j.isSoftDeleted) return false;
      final jPeriod = (j.periodId != null && j.periodId!.isNotEmpty)
          ? j.periodId
          : scheduleProvider.schedules
                .firstWhere(
                  (s) => s.id == j.scheduleId,
                  orElse: () => ScheduleModel(
                    id: '',
                    periodId: '',
                    date: DateTime.now(),
                    teachingHour: 0,
                    classId: '',
                    subjectId: '',
                    teacherId: '',
                    isActive: false,
                  ),
                )
                .periodId;

      if (periodId != null && periodId.isNotEmpty) {
        if (jPeriod != periodId) return false;
      }
      return _matchesTimeFilter(j.date);
    }).toList();
  }

  /// Classes relevant to the selected period
  List<ClassModel> _getClassesForPeriod(
    List<ClassModel> allClasses,
    List<JournalModel> periodJournals,
    String? periodId,
  ) {
    final classes = allClasses.where((c) {
      if (periodId == null || periodId.isEmpty) return true;
      return c.periodId == periodId ||
          periodJournals.any((j) => j.classId == c.id);
    }).toList();

    classes.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return classes;
  }

  /// Calculate summary for each class
  List<ClassAttendanceSummary> _calculateAllClassesSummary(
    List<ClassModel> classes,
    List<JournalModel> journals,
  ) {
    final List<ClassAttendanceSummary> list = [];

    for (final c in classes) {
      final classJournals = journals
          .where((j) => j.classId == c.id && !j.isTeacherAbsence)
          .toList();
      final totalMeetings = classJournals.length;
      final cachedStudents = _studentsCache[c.id];
      final totalStudents = cachedStudents != null && cachedStudents.isNotEmpty
          ? cachedStudents.length
          : (c.studentCount > 0 ? c.studentCount : 30);

      final totalSick = classJournals.fold<int>(
        0,
        (sum, j) => sum + j.sickCount,
      );
      final totalPerm = classJournals.fold<int>(
        0,
        (sum, j) => sum + j.permissionCount,
      );
      final totalAlpha = classJournals.fold<int>(
        0,
        (sum, j) => sum + j.alphaCount,
      );

      final totalPossible = totalMeetings * totalStudents;
      final totalAbsents = totalSick + totalPerm + totalAlpha;
      final totalPresent = (totalPossible - totalAbsents).clamp(
        0,
        totalPossible,
      );

      list.add(
        ClassAttendanceSummary(
          classModel: c,
          totalStudents: totalStudents,
          totalMeetings: totalMeetings,
          totalPresent: totalPresent,
          totalSick: totalSick,
          totalPermission: totalPerm,
          totalAlpha: totalAlpha,
          totalPossibleAttendances: totalPossible,
        ),
      );
    }

    return list;
  }

  /// Calculate student-level summaries for the selected class
  List<StudentAttendanceSummary> _calculateStudentSummaries({
    required List<StudentModel> students,
    required List<JournalModel> classJournals,
    required MasterDataProvider masterProvider,
  }) {
    final teachingJournals = classJournals
        .where((j) => !j.isTeacherAbsence)
        .toList();
    final List<Map<String, dynamic>> parsedJournals = [];

    for (final j in teachingJournals) {
      final absenceInfo = JournalAbsenceInfo.fromJournal(j);
      final subj = masterProvider.subjects.firstWhere(
        (s) => s.id == j.subjectId,
        orElse: () =>
            SubjectModel(id: j.subjectId, name: 'Mapel', isActive: false),
      );
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.id == j.teacherId,
        orElse: () => TeacherModel(
          id: j.teacherId,
          name: 'Guru',
          position: '',
          address: '',
          phoneNumber: '',
          email: '',
        ),
      );

      parsedJournals.add({
        'journal': j,
        'absenceInfo': absenceInfo,
        'subjectName': subj.name,
        'teacherName': teacher.name,
      });
    }

    final List<StudentAttendanceSummary> summaries = [];

    for (final student in students) {
      final studentNormName = student.name.trim().toLowerCase();
      final summary = StudentAttendanceSummary(student: student);

      for (final item in parsedJournals) {
        final JournalModel j = item['journal'] as JournalModel;
        final JournalAbsenceInfo absence =
            item['absenceInfo'] as JournalAbsenceInfo;
        final String subjName = item['subjectName'] as String;
        final String teacherName = item['teacherName'] as String;

        final isSick = absence.sickStudentNames.any(
          (n) => n.toLowerCase() == studentNormName,
        );
        final isPerm = absence.permissionStudentNames.any(
          (n) => n.toLowerCase() == studentNormName,
        );
        final isAlpha = absence.alphaStudentNames.any(
          (n) => n.toLowerCase() == studentNormName,
        );

        if (isSick) {
          summary.sickCount++;
          summary.records.add(
            StudentAbsenceRecord(
              date: j.date,
              subjectName: subjName,
              teacherName: teacherName,
              teachingHour: j.teachingHour,
              status: 'Sakit',
              journalId: j.id,
            ),
          );
        } else if (isPerm) {
          summary.permissionCount++;
          summary.records.add(
            StudentAbsenceRecord(
              date: j.date,
              subjectName: subjName,
              teacherName: teacherName,
              teachingHour: j.teachingHour,
              status: 'Izin',
              journalId: j.id,
            ),
          );
        } else if (isAlpha) {
          summary.alphaCount++;
          summary.records.add(
            StudentAbsenceRecord(
              date: j.date,
              subjectName: subjName,
              teacherName: teacherName,
              teachingHour: j.teachingHour,
              status: 'Alfa',
              journalId: j.id,
            ),
          );
        } else {
          summary.presentCount++;
        }
      }

      summaries.add(summary);
    }

    switch (_studentSortBy) {
      case StudentSortBy.nameAsc:
        summaries.sort(
          (a, b) => a.student.name.toLowerCase().compareTo(
            b.student.name.toLowerCase(),
          ),
        );
        break;
      case StudentSortBy.alphaDesc:
        summaries.sort((a, b) => b.alphaCount.compareTo(a.alphaCount));
        break;
      case StudentSortBy.sickDesc:
        summaries.sort((a, b) => b.sickCount.compareTo(a.sickCount));
        break;
      case StudentSortBy.permDesc:
        summaries.sort(
          (a, b) => b.permissionCount.compareTo(a.permissionCount),
        );
        break;
      case StudentSortBy.rateAsc:
        summaries.sort(
          (a, b) => a.attendancePercentage.compareTo(b.attendancePercentage),
        );
        break;
      case StudentSortBy.rateDesc:
        summaries.sort(
          (a, b) => b.attendancePercentage.compareTo(a.attendancePercentage),
        );
        break;
    }

    return summaries;
  }

  // ── Export Actions ──────────────────────────────────────────────────────────
  Future<void> _handleExport(ClassModel classModel, PeriodModel period) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    final journalProvider = Provider.of<JournalProvider>(
      context,
      listen: false,
    );
    final scheduleProvider = Provider.of<ScheduleProvider>(
      context,
      listen: false,
    );

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unduh Rekap Kehadiran',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                'Pilih format laporan presensi kelas ${classModel.name} untuk periode ${period.name}.',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12.5.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 18.h),

              // PDF Option
              InkWell(
                onTap: () => Navigator.pop(ctx, 'pdf'),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dokumen PDF (.pdf)',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Format resmi siap cetak lengkap dengan kop & tanda tangan',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.5.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Excel Option
              InkWell(
                onTap: () => Navigator.pop(ctx, 'excel'),
                borderRadius: BorderRadius.circular(14.r),
                child: Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: const Icon(
                          Icons.table_chart_rounded,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Spreadsheet Excel (.xlsx)',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Data rekap siswa & log pertemuan lengkap untuk olah data',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.5.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final allJournals = _getJournalsForPeriod(
      journalProvider.journals,
      scheduleProvider,
      period.id,
    );
    final classJournals = allJournals
        .where((j) => j.classId == classModel.id)
        .toList();

    // Ensure students loaded
    if (!_studentsCache.containsKey(classModel.id)) {
      await _loadStudentsForClass(classModel.id);
    }
    if (!mounted) return;

    final students = _studentsCache[classModel.id] ?? [];
    final studentSummaries = _calculateStudentSummaries(
      students: students,
      classJournals: classJournals,
      masterProvider: masterProvider,
    );

    final schoolName = authProvider.activeSchoolName;
    final school = authProvider.activeSchool;

    setState(() => _isExporting = true);

    try {
      if (choice == 'pdf') {
        final totalMeetings = classJournals
            .where((j) => !j.isTeacherAbsence)
            .length;
        final totalStudents = students.isNotEmpty
            ? students.length
            : (classModel.studentCount > 0 ? classModel.studentCount : 30);
        final totalSick = classJournals.fold<int>(
          0,
          (sum, j) => sum + j.sickCount,
        );
        final totalPerm = classJournals.fold<int>(
          0,
          (sum, j) => sum + j.permissionCount,
        );
        final totalAlpha = classJournals.fold<int>(
          0,
          (sum, j) => sum + j.alphaCount,
        );
        final totalPossible = totalMeetings * totalStudents;
        final totalPresent =
            (totalPossible - (totalSick + totalPerm + totalAlpha)).clamp(
              0,
              totalPossible,
            );
        final rate = totalPossible > 0
            ? (totalPresent / totalPossible) * 100.0
            : 100.0;

        final pdfBytes = await JournalPdfService.generateClassAttendancePdf(
          className: classModel.name,
          periodName: period.name,
          schoolName: schoolName,
          school: school,
          studentSummaries: studentSummaries,
          totalMeetings: totalMeetings,
          totalStudents: totalStudents,
          totalPresent: totalPresent,
          totalSick: totalSick,
          totalPermission: totalPerm,
          totalAlpha: totalAlpha,
          attendanceRate: rate,
          dateRangeText: _getTimeFilterLabel(),
        );

        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: 'Rekap_Presensi_${classModel.name}_${period.name}.pdf',
        );
      } else if (choice == 'excel') {
        await ExcelExportService.exportClassAttendanceRecap(
          className: classModel.name,
          periodName: period.name,
          schoolName: schoolName,
          studentSummaries: studentSummaries,
          classJournals: classJournals,
          masterProvider: masterProvider,
          dateRangeText: _getTimeFilterLabel(),
        );
        if (mounted) {
          AppHelper.showSnackBar(
            context,
            'Rekap kehadiran berhasil diekspor ke Excel.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(
          context,
          'Gagal memproses ekspor: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  // ── Show Student Absence History Modal ──────────────────────────────────────
  void _showStudentAbsenceModal(
    BuildContext context,
    StudentAttendanceSummary summary,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final f = DateFormat('dd MMMM yyyy', 'id_ID');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (sheetContext, scrollController) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44.w,
                      height: 4.5.h,
                      margin: EdgeInsets.only(bottom: 14.h),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 46.r,
                        height: 46.r,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF1E3A8A),
                                    const Color(0xFF2563EB),
                                  ]
                                : [
                                    const Color(0xFF3B82F6),
                                    const Color(0xFF1D4ED8),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Center(
                          child: Text(
                            summary.student.name.isNotEmpty
                                ? summary.student.name
                                      .substring(0, 1)
                                      .toUpperCase()
                                : '?',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              summary.student.name,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'NIS: ${summary.student.nis?.isNotEmpty == true ? summary.student.nis! : '-'}  ·  ${summary.student.gender == 'L' ? 'Laki-laki' : (summary.student.gender == 'P' ? 'Perempuan' : '-')}',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.5.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Mini Stats Row (Modern Cards)
                  Row(
                    children: [
                      _buildModernModalStatTile(
                        label: 'Hadir',
                        value: '${summary.presentCount}',
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                      SizedBox(width: 8.w),
                      _buildModernModalStatTile(
                        label: 'Sakit',
                        value: '${summary.sickCount}',
                        color: const Color(0xFFF59E0B),
                        isDark: isDark,
                      ),
                      SizedBox(width: 8.w),
                      _buildModernModalStatTile(
                        label: 'Izin',
                        value: '${summary.permissionCount}',
                        color: const Color(0xFF38BDF8),
                        isDark: isDark,
                      ),
                      SizedBox(width: 8.w),
                      _buildModernModalStatTile(
                        label: 'Alfa',
                        value: '${summary.alphaCount}',
                        color: const Color(0xFFF43F5E),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Attendance Rate Bar inside Modal
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Persentase Kehadiran',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${summary.attendancePercentage.toStringAsFixed(1)}%',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: summary.attendancePercentage >= 85
                                ? const Color(0xFF10B981)
                                : (summary.attendancePercentage >= 75
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFFF43F5E)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 18.h),

                  Text(
                    'Riwayat Ketidakhadiran (${summary.records.length} Catatan):',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 10.h),

                  Expanded(
                    child: summary.records.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(14.r),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    size: 38.r,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  'Kehadiran Sempurna 100%!',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tidak ada catatan sakit, izin, atau alfa.',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12.sp,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: summary.records.length,
                            separatorBuilder: (_, _) => SizedBox(height: 8.h),
                            itemBuilder: (c, idx) {
                              final r = summary.records[idx];
                              Color statusColor = Colors.grey;
                              if (r.status == 'Sakit') {
                                statusColor = const Color(0xFFF59E0B);
                              }
                              if (r.status == 'Izin') {
                                statusColor = const Color(0xFF38BDF8);
                              }
                              if (r.status == 'Alfa') {
                                statusColor = const Color(0xFFF43F5E);
                              }

                              return Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E293B)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                        border: Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.5,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        r.status.toUpperCase(),
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 10.5.sp,
                                          fontWeight: FontWeight.w800,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.subjectName,
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            '${f.format(r.date)} · Jam ke-${r.teachingHour} · Guru: ${r.teacherName}',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 11.sp,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 13.sp,
                                      ),
                                      tooltip: 'Buka Detail Jurnal',
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        context.push(
                                          '/admin/journal/${r.journalId}',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernModalStatTile({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = masterProvider.periods;

    final sortedPeriods = _getSortedPeriods(periods);
    final selectedPeriod = _getSelectedPeriod(periods);

    final allPeriodJournals = _getJournalsForPeriod(
      journalProvider.journals,
      scheduleProvider,
      selectedPeriod?.id,
    );

    final classesForPeriod = _getClassesForPeriod(
      masterProvider.classes,
      allPeriodJournals,
      selectedPeriod?.id,
    );

    ClassModel? currentClass;
    if (_selectedClassId != null && classesForPeriod.isNotEmpty) {
      currentClass = classesForPeriod.firstWhere(
        (c) => c.id == _selectedClassId,
        orElse: () => classesForPeriod.first,
      );
    } else if (classesForPeriod.isNotEmpty) {
      currentClass = classesForPeriod.first;
    }

    final classSummaries = _calculateAllClassesSummary(
      classesForPeriod,
      allPeriodJournals,
    );

    final filteredClassSummaries = classSummaries.where((cs) {
      if (_classSearchQuery.isEmpty) return true;
      return cs.classModel.name.toLowerCase().contains(_classSearchQuery);
    }).toList();

    return AppScaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      drawer: const AdminDrawer(currentRoute: '/admin/class-attendance-recap'),
      appBar: AppBar(
        title: Text(
          'Rekap Kehadiran Kelas',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 16.sp,
          ),
        ),
        actions: [
          if (currentClass != null && selectedPeriod != null)
            IconButton(
              icon: _isExporting
                  ? SizedBox(
                      width: 18.r,
                      height: 18.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.file_download_outlined),
              tooltip: 'Unduh / Cetak Rekap',
              onPressed: _isExporting
                  ? null
                  : () => _handleExport(currentClass!, selectedPeriod),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _initData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Period Selector Bar
              if (periods.isNotEmpty)
                AdminPeriodSelectorBar(
                  periods: sortedPeriods,
                  selectedPeriodId: _selectedPeriodId,
                  onPeriodChanged: (newId) {
                    setState(() {
                      _selectedPeriodId = newId;
                    });
                  },
                ),

              // 2. High-Level Metrics Banner (Sleek, Modern Card)
              _buildTopMetricsBanner(classSummaries, isDark),

              // 3. Segmented Pill Mode Switcher (Modern iOS/M3 Pill Slider)
              _buildModernModeSegmentedControl(isDark),

              // 4. Content by Mode
              if (_viewModeIndex == 0)
                _buildAllClassesOverview(
                  filteredClassSummaries,
                  selectedPeriod,
                  isDark,
                  classesForPeriod,
                )
              else
                _buildClassDetailView(
                  currentClass: currentClass,
                  classesForPeriod: classesForPeriod,
                  allPeriodJournals: allPeriodJournals,
                  selectedPeriod: selectedPeriod,
                  masterProvider: masterProvider,
                  isDark: isDark,
                ),

              SizedBox(height: 36.h),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Metrics Banner (Modern & Elegant Design) ────────────────────────────
  Widget _buildTopMetricsBanner(
    List<ClassAttendanceSummary> summaries,
    bool isDark,
  ) {
    final totalClasses = summaries.length;
    final totalMeetings = summaries.fold<int>(
      0,
      (sum, cs) => sum + cs.totalMeetings,
    );
    final totalPossible = summaries.fold<int>(
      0,
      (sum, cs) => sum + cs.totalPossibleAttendances,
    );
    final totalPresent = summaries.fold<int>(
      0,
      (sum, cs) => sum + cs.totalPresent,
    );
    final totalSick = summaries.fold<int>(0, (sum, cs) => sum + cs.totalSick);
    final totalPerm = summaries.fold<int>(
      0,
      (sum, cs) => sum + cs.totalPermission,
    );
    final totalAlpha = summaries.fold<int>(0, (sum, cs) => sum + cs.totalAlpha);

    final overallRate = totalPossible > 0
        ? (totalPresent / totalPossible) * 100.0
        : 100.0;
    final rateAccent = overallRate >= 85
        ? const Color(0xFF10B981)
        : overallRate >= 75
        ? const Color(0xFFF59E0B)
        : const Color(0xFFF43F5E);
    final statusLabel = overallRate >= 95
        ? 'Sangat Baik'
        : overallRate >= 85
        ? 'Baik'
        : overallRate >= 75
        ? 'Cukup'
        : 'Perlu Perhatian';

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
                : const [Color(0xFF1E40AF), Color(0xFF1D4ED8)],
          ),
          border: Border.all(
            color: isDark
                ? const Color(0xFF334155)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.35)
                  : const Color(0xFF1D4ED8).withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(18.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Analysis Tag + Circular Rate Indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6.r,
                                height: 6.r,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF60A5FA),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'ANALISIS KEHADIRAN KESELURUHAN',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF93C5FD),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10.w,
                          runSpacing: 4.h,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  overallRate.toStringAsFixed(1),
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 34.sp,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  '%',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFBFDBFE),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: rateAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: rateAccent.withValues(alpha: 0.6),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6.r,
                                    height: 6.r,
                                    decoration: BoxDecoration(
                                      color: rateAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 5.w),
                                  Text(
                                    statusLabel,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 10.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          '$totalClasses Kelas Aktif  ·  $totalMeetings Total Sesi Pertemuan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  SizedBox(
                    width: 62.r,
                    height: 62.r,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 62.r,
                          height: 62.r,
                          child: CircularProgressIndicator(
                            value: (overallRate / 100.0).clamp(0.0, 1.0),
                            strokeWidth: 6.5.r,
                            strokeCap: StrokeCap.round,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rateAccent,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.insights_rounded,
                          size: 22.sp,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Modern 4-Col Stat Cards (Replacing stark dividers)
              Row(
                children: [
                  _buildModernStatCard(
                    label: 'Hadir',
                    count: '$totalPresent',
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  SizedBox(width: 8.w),
                  _buildModernStatCard(
                    label: 'Sakit',
                    count: '$totalSick',
                    color: const Color(0xFFF59E0B),
                    icon: Icons.healing_rounded,
                  ),
                  SizedBox(width: 8.w),
                  _buildModernStatCard(
                    label: 'Izin',
                    count: '$totalPerm',
                    color: const Color(0xFF38BDF8),
                    icon: Icons.assignment_outlined,
                  ),
                  SizedBox(width: 8.w),
                  _buildModernStatCard(
                    label: 'Alpha',
                    count: '$totalAlpha',
                    color: const Color(0xFFF43F5E),
                    icon: Icons.cancel_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatCard({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 11.sp, color: color),
                  SizedBox(width: 4.w),
                  Text(
                    count,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modern Segmented Control ───────────────────────────────────────────────
  Widget _buildModernModeSegmentedControl(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildSegmentedTabButton(
                title: 'Ringkasan Kelas',
                icon: Icons.grid_view_rounded,
                isSelected: _viewModeIndex == 0,
                onTap: () => setState(() => _viewModeIndex = 0),
                isDark: isDark,
              ),
            ),
            Expanded(
              child: _buildSegmentedTabButton(
                title: 'Detail Kelas',
                icon: Icons.view_agenda_rounded,
                isSelected: _viewModeIndex == 1,
                enabled: _hasViewedClass,
                onTap: _hasViewedClass
                    ? () {
                        setState(() => _viewModeIndex = 1);
                        _loadStudentsForClass(_selectedClassId!);
                      }
                    : null,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
    required bool isDark,
    bool enabled = true,
  }) {
    final effectiveOnTap = enabled ? onTap : null;
    final activeBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final activeTextColor = isDark
        ? AppTheme.primaryAccent
        : AppTheme.primaryColor;
    final inactiveTextColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(12.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.05,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16.sp,
                  color: isSelected ? activeTextColor : inactiveTextColor,
                ),
                SizedBox(width: 6.w),
                Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.5.sp,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? activeTextColor : inactiveTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mode 1: Ringkasan Semua Kelas ───────────────────────────────────────────
  Widget _buildAllClassesOverview(
    List<ClassAttendanceSummary> summaries,
    PeriodModel? period,
    bool isDark,
    List<ClassModel> classesForPeriod,
  ) {
    final isSearching = _classSearchQuery.trim().isNotEmpty;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    final accentColor = isDark ? AppTheme.primaryAccent : AppTheme.primaryColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Chips Row
          _buildTimeFilterChips(isDark),
          SizedBox(height: 14.h),

          // Search Bar (Refined & Modern)
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _classSearchController,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama kelas...',
                hintStyle: GoogleFonts.hankenGrotesk(
                  fontSize: 13.sp,
                  color: onSurfaceVariant.withValues(alpha: 0.7),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20.sp,
                  color: onSurfaceVariant,
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 42.w,
                  minHeight: 40.h,
                ),
                suffixIcon: _classSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        iconSize: 18.sp,
                        color: onSurfaceVariant,
                        onPressed: () => _classSearchController.clear(),
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14.w,
                  vertical: 12.h,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14.r),
                  borderSide: BorderSide(color: accentColor, width: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(height: 18.h),

          // Section header with modern badge
          Row(
            children: [
              Text(
                'Daftar Kelas',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${summaries.length}',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          if (summaries.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 36.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56.r,
                    height: 56.r,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSearching
                          ? Icons.search_off_rounded
                          : Icons.school_outlined,
                      size: 26.r,
                      color: accentColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    isSearching
                        ? 'Kelas tidak ditemukan'
                        : 'Belum ada data kehadiran',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    isSearching
                        ? 'Coba kata kunci lain atau ubah periode.'
                        : 'Data akan muncul setelah jurnal kelas tersedia pada periode ini.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.5.sp,
                      height: 1.4,
                      color: onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: summaries.length,
              separatorBuilder: (_, _) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final cs = summaries[index];
                return _buildClassCard(cs, period, isDark);
              },
            ),
        ],
      ),
    );
  }

  void _openClassDetail(ClassAttendanceSummary cs) {
    setState(() {
      _selectedClassId = cs.classModel.id;
      _viewModeIndex = 1;
    });
    _loadStudentsForClass(cs.classModel.id);
  }

  // ── Class Card (Modern & Clean) ───────────────────────────────────────────
  Widget _buildClassCard(
    ClassAttendanceSummary cs,
    PeriodModel? period,
    bool isDark,
  ) {
    final rate = cs.attendanceRate;
    final Color statusColor;
    if (rate < 75) {
      statusColor = const Color(0xFFF43F5E);
    } else if (rate < 85) {
      statusColor = const Color(0xFFF59E0B);
    } else if (rate < 95) {
      statusColor = const Color(0xFF3B82F6);
    } else {
      statusColor = const Color(0xFF10B981);
    }

    final accentColor = isDark ? AppTheme.primaryAccent : AppTheme.primaryColor;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: () => _openClassDetail(cs),
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Class Info + Rate Badge
              Row(
                children: [
                  Container(
                    width: 44.r,
                    height: 44.r,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
                            : [
                                const Color(0xFFEFF6FF),
                                const Color(0xFFDBEAFE),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: isDark ? Colors.white : AppTheme.primaryColor,
                      size: 22.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cs.classModel.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          '${cs.totalStudents} siswa · ${cs.totalMeetings} pertemuan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 11.5.sp,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${rate.toStringAsFixed(1)}%',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),

              // Modern Slim Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (rate / 100.0).clamp(0.0, 1.0),
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  minHeight: 5.h,
                ),
              ),
              SizedBox(height: 12.h),

              // 4 Soft Metric Chips (Hadir, Sakit, Izin, Alfa)
              Row(
                children: [
                  _buildSoftMiniChip(
                    label: 'Hadir',
                    count: cs.totalPresent,
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                  SizedBox(width: 6.w),
                  _buildSoftMiniChip(
                    label: 'Sakit',
                    count: cs.totalSick,
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                  SizedBox(width: 6.w),
                  _buildSoftMiniChip(
                    label: 'Izin',
                    count: cs.totalPermission,
                    color: const Color(0xFF38BDF8),
                    isDark: isDark,
                  ),
                  SizedBox(width: 6.w),
                  _buildSoftMiniChip(
                    label: 'Alpha',
                    count: cs.totalAlpha,
                    color: const Color(0xFFF43F5E),
                    isDark: isDark,
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // Bottom Actions Row
              Row(
                children: [
                  if (period != null)
                    TextButton.icon(
                      icon: Icon(Icons.download_rounded, size: 15.sp),
                      label: const Text('Unduh'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant,
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () => _handleExport(cs.classModel, period),
                    ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: accentColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openClassDetail(cs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Detail',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Icon(Icons.arrow_forward_rounded, size: 14.sp),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoftMiniChip({
    required String label,
    required int count,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.25 : 0.15),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode 2: Detail Kelas Terpilih ───────────────────────────────────────────
  Widget _buildClassDetailView({
    required ClassModel? currentClass,
    required List<ClassModel> classesForPeriod,
    required PeriodModel? selectedPeriod,
    required MasterDataProvider masterProvider,
    required bool isDark,
    required List<JournalModel> allPeriodJournals,
  }) {
    if (!_hasViewedClass || currentClass == null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded, size: 40.r, color: Colors.grey),
              SizedBox(height: 8.h),
              Text(
                'Silakan pilih kelas terlebih dahulu.',
                style: GoogleFonts.hankenGrotesk(fontSize: 14.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                'Ketuk salah satu kartu kelas pada tab Ringkasan untuk melihat rekapnya.',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final classJournals = allPeriodJournals.where((j) {
      if (j.classId != currentClass.id) return false;
      if (_selectedSubjectId != null && j.subjectId != _selectedSubjectId) {
        return false;
      }
      if (_selectedTeacherId != null && j.teacherId != _selectedTeacherId) {
        return false;
      }
      return true;
    }).toList();

    final students = _studentsCache[currentClass.id] ?? [];
    final studentSummaries = _calculateStudentSummaries(
      students: students,
      classJournals: classJournals,
      masterProvider: masterProvider,
    );

    final filteredStudentSummaries = studentSummaries.where((s) {
      if (_studentSearchQuery.isEmpty) return true;
      final nameMatches = s.student.name.toLowerCase().contains(
        _studentSearchQuery,
      );
      final nisMatches =
          s.student.nis?.toLowerCase().contains(_studentSearchQuery) ?? false;
      return nameMatches || nisMatches;
    }).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 12.h),

          // Class Selector Dropdown & Back Button (Modern Header)
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Kembali ke Semua Kelas',
                onPressed: () {
                  setState(() => _viewModeIndex = 0);
                },
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 2.h,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentClass.id,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      borderRadius: BorderRadius.circular(14.r),
                      dropdownColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      items: classesForPeriod.map((c) {
                        return DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(
                            'Kelas ${c.name} (${c.studentCount} Siswa)',
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5.sp,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newClassId) {
                        if (newClassId != null &&
                            newClassId != currentClass.id) {
                          setState(() {
                            _selectedClassId = newClassId;
                          });
                          _loadStudentsForClass(newClassId);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Time Filter Chips
          _buildTimeFilterChips(isDark),
          SizedBox(height: 12.h),

          // Filters Row: Subject & Sort & Search
          _buildAdvancedFiltersRow(masterProvider, isDark),
          SizedBox(height: 14.h),

          // Sub-Tab Switcher: Rekap Siswa vs Log Pertemuan (Segmented Pill)
          Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSubTabButton(
                    title:
                        'Presensi Siswa (${filteredStudentSummaries.length})',
                    isSelected: _detailSubTabIndex == 0,
                    onTap: () => setState(() => _detailSubTabIndex = 0),
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildSubTabButton(
                    title: 'Log Pertemuan (${classJournals.length})',
                    isSelected: _detailSubTabIndex == 1,
                    onTap: () => setState(() => _detailSubTabIndex = 1),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 14.h),

          if (_isLoadingStudents)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 36.h),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (_detailSubTabIndex == 0)
            _buildStudentSummariesList(filteredStudentSummaries, isDark)
          else
            _buildJournalLogsList(classJournals, masterProvider, isDark),
        ],
      ),
    );
  }

  Widget _buildSubTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final activeBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final activeTextColor = isDark
        ? AppTheme.primaryAccent
        : AppTheme.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected
                  ? activeTextColor
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  // ── Time Filter Chips ───────────────────────────────────────────────────────
  Widget _buildTimeFilterChips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 13.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 5.w),
            Text(
              'Periode Waktu',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            _buildFilterChip('Semua', AttendanceTimeFilter.allPeriod, isDark),
            _buildFilterChip(
              'Bulan Ini',
              AttendanceTimeFilter.thisMonth,
              isDark,
            ),
            _buildFilterChip(
              'Bulan Lalu',
              AttendanceTimeFilter.lastMonth,
              isDark,
            ),
            _buildFilterChip('Rentang', AttendanceTimeFilter.custom, isDark),
          ],
        ),
        if (_timeFilter == AttendanceTimeFilter.custom &&
            _customDateRange != null) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: (isDark ? AppTheme.primaryAccent : AppTheme.primaryColor)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.date_range_rounded,
                  size: 12.sp,
                  color: isDark
                      ? AppTheme.primaryAccent
                      : AppTheme.primaryColor,
                ),
                SizedBox(width: 6.w),
                Text(
                  '${DateFormat("dd/MM/yyyy").format(_customDateRange!.start)} - ${DateFormat("dd/MM/yyyy").format(_customDateRange!.end)}',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppTheme.primaryAccent
                        : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    AttendanceTimeFilter filter,
    bool isDark,
  ) {
    final isSelected = _timeFilter == filter;
    final selectedColor = isDark
        ? AppTheme.primaryAccent
        : AppTheme.primaryColor;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      elevation: 0,
      pressElevation: 0,
      onSelected: (val) async {
        if (filter == AttendanceTimeFilter.custom) {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
            initialDateRange:
                _customDateRange ??
                DateTimeRange(
                  start: DateTime.now().subtract(const Duration(days: 30)),
                  end: DateTime.now(),
                ),
          );
          if (range != null) {
            setState(() {
              _customDateRange = range;
              _timeFilter = AttendanceTimeFilter.custom;
            });
          }
        } else {
          setState(() {
            _timeFilter = filter;
          });
        }
      },
      selectedColor: selectedColor,
      labelStyle: GoogleFonts.hankenGrotesk(
        fontSize: 11.5.sp,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : inactiveColor,
      ),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: isSelected
              ? selectedColor
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: 1,
        ),
      ),
    );
  }

  // ── Advanced Filters Row (Subject, Teacher, Sort) ───────────────────────────
  Widget _buildAdvancedFiltersRow(
    MasterDataProvider masterProvider,
    bool isDark,
  ) {
    return Column(
      children: [
        Row(
          children: [
            // Subject Filter
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _selectedSubjectId,
                    hint: Text(
                      'Semua Mata Pelajaran',
                      style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                    ),
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12.r),
                    dropdownColor: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          'Semua Mapel',
                          style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                        ),
                      ),
                      ...masterProvider.subjects.map((s) {
                        return DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(
                            s.name,
                            style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedSubjectId = val);
                    },
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),

            // Sort Dropdown
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<StudentSortBy>(
                  value: _studentSortBy,
                  icon: const Icon(Icons.sort_rounded, size: 18),
                  borderRadius: BorderRadius.circular(12.r),
                  dropdownColor: isDark
                      ? const Color(0xFF1E293B)
                      : Colors.white,
                  items: [
                    DropdownMenuItem(
                      value: StudentSortBy.nameAsc,
                      child: Text(
                        'Nama (A-Z)',
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                      ),
                    ),
                    DropdownMenuItem(
                      value: StudentSortBy.alphaDesc,
                      child: Text(
                        'Alfa Terbanyak',
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                      ),
                    ),
                    DropdownMenuItem(
                      value: StudentSortBy.sickDesc,
                      child: Text(
                        'Sakit Terbanyak',
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                      ),
                    ),
                    DropdownMenuItem(
                      value: StudentSortBy.permDesc,
                      child: Text(
                        'Izin Terbanyak',
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                      ),
                    ),
                    DropdownMenuItem(
                      value: StudentSortBy.rateAsc,
                      child: Text(
                        'Kehadiran Terendah',
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                      ),
                    ),
                    DropdownMenuItem(
                      value: StudentSortBy.rateDesc,
                      child: Text(
                        'Kehadiran Tertinggi',
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.sp),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _studentSortBy = val);
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),

        // Student Search Field
        TextField(
          controller: _studentSearchController,
          style: GoogleFonts.hankenGrotesk(fontSize: 12.5.sp),
          decoration: InputDecoration(
            hintText: 'Cari siswa berdasarkan nama atau NIS...',
            hintStyle: GoogleFonts.hankenGrotesk(
              fontSize: 12.sp,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 19),
            suffixIcon: _studentSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () => _studentSearchController.clear(),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14.w,
              vertical: 10.h,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Sub-Tab 1: Student Summaries List ───────────────────────────────────────
  Widget _buildStudentSummariesList(
    List<StudentAttendanceSummary> summaries,
    bool isDark,
  ) {
    if (summaries.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 36.h),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.person_search_rounded, size: 40.r, color: Colors.grey),
            SizedBox(height: 8.h),
            Text(
              'Tidak ada data siswa yang cocok dengan filter.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: summaries.length,
      separatorBuilder: (_, _) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final s = summaries[index];
        final rate = s.attendancePercentage;

        Color rateColor = const Color(0xFF10B981);
        if (rate < 75) {
          rateColor = const Color(0xFFF43F5E);
        } else if (rate < 85) {
          rateColor = const Color(0xFFF59E0B);
        } else if (rate < 95) {
          rateColor = const Color(0xFF3B82F6);
        }

        return InkWell(
          onTap: () => _showStudentAbsenceModal(context, s),
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38.r,
                  height: 38.r,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.student.name,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'NIS: ${s.student.nis?.isNotEmpty == true ? s.student.nis! : '-'}  ·  ${s.totalMeetings} Sesi (${s.presentCount} Hadir)',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          _buildMiniBadge(
                            'S: ${s.sickCount}',
                            const Color(0xFFF59E0B),
                          ),
                          SizedBox(width: 6.w),
                          _buildMiniBadge(
                            'I: ${s.permissionCount}',
                            const Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 6.w),
                          _buildMiniBadge(
                            'A: ${s.alphaCount}',
                            const Color(0xFFF43F5E),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: rateColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: rateColor.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${rate.toStringAsFixed(1)}%',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: rateColor,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Detail',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(width: 2.w),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14.sp,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        text,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ── Sub-Tab 2: Journal Logs List ───────────────────────────────────────────
  Widget _buildJournalLogsList(
    List<JournalModel> journals,
    MasterDataProvider masterProvider,
    bool isDark,
  ) {
    if (journals.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 36.h),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.menu_book_outlined, size: 40.r, color: Colors.grey),
            SizedBox(height: 8.h),
            Text(
              'Belum ada pertemuan / jurnal untuk kelas ini pada periode terpilih.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final sortedJournals = List<JournalModel>.from(journals)
      ..sort((a, b) => b.date.compareTo(a.date));
    final f = DateFormat('dd MMM yyyy', 'id_ID');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedJournals.length,
      separatorBuilder: (_, _) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final j = sortedJournals[index];
        final subj = masterProvider.subjects.firstWhere(
          (s) => s.id == j.subjectId,
          orElse: () =>
              SubjectModel(id: j.subjectId, name: 'Mapel', isActive: false),
        );
        final teacher = masterProvider.teachers.firstWhere(
          (t) => t.id == j.teacherId,
          orElse: () => TeacherModel(
            id: j.teacherId,
            name: 'Guru',
            position: '',
            address: '',
            phoneNumber: '',
            email: '',
          ),
        );

        final absenceInfo = JournalAbsenceInfo.fromJournal(j);

        return InkWell(
          onTap: () => context.push('/admin/journal/${j.id}'),
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '${f.format(j.date)} · Jam ke-${j.teachingHour}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Text(
                      'S:${j.sickCount}  I:${j.permissionCount}  A:${j.alphaCount}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  subj.name,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Guru: ${teacher.name}',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.5.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (j.material.trim().isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Materi: ${j.material.trim()}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.5.sp,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (absenceInfo.sickStudentNames.isNotEmpty ||
                    absenceInfo.permissionStudentNames.isNotEmpty ||
                    absenceInfo.alphaStudentNames.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: [
                      ...absenceInfo.sickStudentNames.map(
                        (name) => _buildAbsentStudentTag(
                          name,
                          'Sakit',
                          const Color(0xFFF59E0B),
                        ),
                      ),
                      ...absenceInfo.permissionStudentNames.map(
                        (name) => _buildAbsentStudentTag(
                          name,
                          'Izin',
                          const Color(0xFF38BDF8),
                        ),
                      ),
                      ...absenceInfo.alphaStudentNames.map(
                        (name) => _buildAbsentStudentTag(
                          name,
                          'Alfa',
                          const Color(0xFFF43F5E),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAbsentStudentTag(String name, String status, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        '$name ($status)',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
