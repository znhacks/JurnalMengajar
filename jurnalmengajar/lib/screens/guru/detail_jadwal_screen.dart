import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/schedule_model.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/period_model.dart';
import '../../models/teacher_model.dart';
import '../../core/utils/helper.dart';
import 'form_jurnal_screen.dart';

class DetailJadwalScreen extends StatefulWidget {
  final String scheduleId;
  const DetailJadwalScreen({super.key, required this.scheduleId});

  @override
  State<DetailJadwalScreen> createState() => _DetailJadwalScreenState();
}

class _DetailJadwalScreenState extends State<DetailJadwalScreen> {
  JournalModel? _existingJournal;
  bool _checkingJournal = true;

  @override
  void initState() {
    super.initState();
    _checkExistingJournal();
  }

  Future<void> _checkExistingJournal() async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

    // Let's first wait for a tiny delay or wait for frames to ensure schedules are loaded
    await Future.delayed(Duration.zero);
    
    // Find schedule
    ScheduleModel? schedule;
    try {
      schedule = scheduleProvider.cachedTeacherSchedules.firstWhere(
        (s) => s.id == widget.scheduleId,
        orElse: () => scheduleProvider.schedules.firstWhere(
          (s) => s.id == widget.scheduleId,
          orElse: () => scheduleProvider.teacherSchedulesForSelectedDate.firstWhere(
            (s) => s.id == widget.scheduleId,
          ),
        ),
      );
    } catch (_) {}

    if (schedule == null) {
      await scheduleProvider.loadAllSchedules();
      try {
        schedule = scheduleProvider.schedules.firstWhere(
          (s) => s.id == widget.scheduleId,
        );
      } catch (_) {}
    }

    if (schedule != null) {
      final uniqueSchedulesMap = <String, ScheduleModel>{};
      for (final s in scheduleProvider.cachedTeacherSchedules) {
        uniqueSchedulesMap[s.id] = s;
      }
      for (final s in scheduleProvider.schedules) {
        uniqueSchedulesMap[s.id] = s;
      }
      for (final s in scheduleProvider.teacherSchedulesForSelectedDate) {
        uniqueSchedulesMap[s.id] = s;
      }
      final allSchedules = uniqueSchedulesMap.values.toList();
          
      final groupSchedules = allSchedules.where((s) {
        return s.date.year == schedule!.date.year &&
            s.date.month == schedule.date.month &&
            s.date.day == schedule.date.day &&
            s.classId == schedule.classId &&
            s.subjectId == schedule.subjectId &&
            s.teacherId == schedule.teacherId &&
            s.periodId == schedule.periodId;
      }).toList();

      JournalModel? foundJournal;
      for (final s in groupSchedules) {
        final journal = await journalProvider.getJournalForSchedule(s.id);
        if (journal != null) {
          foundJournal = journal;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _existingJournal = foundJournal;
          _checkingJournal = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _checkingJournal = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.currentUser?.role == 'admin';

    // Find schedule
    ScheduleModel? schedule;
    try {
      schedule = scheduleProvider.cachedTeacherSchedules.firstWhere(
        (s) => s.id == widget.scheduleId,
        orElse: () => scheduleProvider.schedules.firstWhere(
          (s) => s.id == widget.scheduleId,
          orElse: () => scheduleProvider.teacherSchedulesForSelectedDate.firstWhere(
            (s) => s.id == widget.scheduleId,
          ),
        ),
      );
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Jadwal')),
        body: const Center(child: Text('Jadwal tidak ditemukan')),
      );
    }

    // Find all schedule IDs in same group
    final uniqueSchedulesMap = <String, ScheduleModel>{};
    for (final s in scheduleProvider.cachedTeacherSchedules) {
      uniqueSchedulesMap[s.id] = s;
    }
    for (final s in scheduleProvider.schedules) {
      uniqueSchedulesMap[s.id] = s;
    }
    for (final s in scheduleProvider.teacherSchedulesForSelectedDate) {
      uniqueSchedulesMap[s.id] = s;
    }
    final allSchedules = uniqueSchedulesMap.values.toList();
        
    final groupSchedules = allSchedules.where((s) {
      return s.date.year == schedule!.date.year &&
          s.date.month == schedule.date.month &&
          s.date.day == schedule.date.day &&
          s.classId == schedule.classId &&
          s.subjectId == schedule.subjectId &&
          s.teacherId == schedule.teacherId &&
          s.periodId == schedule.periodId;
    }).toList()..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

    final hoursStr = groupSchedules.map((s) => s.teachingHour).join(', ');
    final matchedHours = masterProvider.hours
        .where((h) => groupSchedules.map((s) => s.teachingHour).contains(h.teachingHour))
        .toList()
      ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));
    final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '00:00';
    final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '00:00';

    // Resolve entities
    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.id == schedule?.teacherId,
      orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
    );

    final cls = masterProvider.classes.firstWhere(
      (c) => c.id == schedule?.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );

    final subject = masterProvider.subjects.firstWhere(
      (s) => s.id == schedule?.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final period = masterProvider.periods.firstWhere(
      (p) => p.id == schedule?.periodId,
      orElse: () => PeriodModel(id: '', name: 'Periode--', isActive: false),
    );

    if (_checkingJournal) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!isAdmin && _existingJournal == null && !_isFutureDate(schedule.date)) {
      return FormJurnalScreen(scheduleId: widget.scheduleId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Jadwal'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Informasi Kegiatan Mengajar',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const Divider(height: 32),

                        _buildDetailRow(Icons.person, 'Guru Pengampu', teacher.name),
                        _buildDetailRow(Icons.class_, 'Kelas / Siswa', '${cls.name} (${cls.studentCount} Siswa)'),
                        _buildDetailRow(Icons.menu_book, 'Mata Pelajaran', subject.name),
                        _buildDetailRow(Icons.calendar_today, 'Tanggal', AppHelper.formatDate(schedule.date)),
                        _buildDetailRow(
                          Icons.access_time,
                          'Jam Pelajaran',
                          'Jam Ke-$hoursStr ($hrStart - $hrEnd)',
                        ),
                        _buildDetailRow(Icons.date_range, 'Periode Akademik', period.name),
                        _buildDetailRow(
                          Icons.description,
                          'Catatan Jadwal',
                          (schedule.note != null && schedule.note!.trim().isNotEmpty)
                              ? schedule.note!
                              : 'Tidak Ada',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Floating Bottom Button
            Padding(
              padding: EdgeInsets.all(20.w),
              child: isAdmin
                  ? (_existingJournal != null
                      ? Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push('/admin/journal/${_existingJournal!.id}');
                                },
                                icon: const Icon(Icons.assignment),
                                label: const Text('Lihat Jurnal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Color(0xFFDC2626)),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  'Jurnal belum diinput oleh guru pengampu.',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                  : _existingJournal != null
                      ? Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push('/guru/journal/${_existingJournal!.id}');
                                },
                                icon: const Icon(Icons.assignment),
                                label: const Text('Lihat Jurnal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            if (_existingJournal!.status == 'rejected') ...[
                              SizedBox(width: 12.w),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    context.push('/guru/journal-form?scheduleId=${schedule!.id}');
                                  },
                                  icon: const Icon(Icons.edit_note),
                                  label: const Text('Revisi Jurnal'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFEA580C),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        )
                      : _buildFutureDateBanner(schedule.date),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Future-date helpers ───────────────────────────────────────────────────

  /// Returns true when [date] is strictly after today (date comparison only).
  bool _isFutureDate(DateTime date) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.isAfter(todayOnly);
  }

  Widget _buildFutureDateBanner(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock_outlined,
              color: Color(0xFFF59E0B), size: 22),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belum bisa mengisi jurnal',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Tidak bisa mengisi jurnal sekarang, tunggu sampai hari tersebut tiba ($day/$month/$year).',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: const Color(0xFF78350F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22.w, color: const Color(0xFF2563EB)),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
