import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/class_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';
import '../../widgets/guru_drawer.dart';
import '../../widgets/app_scaffold.dart';

class GuruStatistikScreen extends StatefulWidget {
  const GuruStatistikScreen({super.key});

  @override
  State<GuruStatistikScreen> createState() => _GuruStatistikScreenState();
}

class _GuruStatistikScreenState extends State<GuruStatistikScreen> {
  DateTime _selectedMonth = DateTime.now();

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  String _getMonthName(DateTime date) {
    final List<String> months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  void _showMonthPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int tempYear = _selectedMonth.year;
    final List<String> monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final now = DateTime.now();
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              insetPadding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 20.h,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 360,
                ),
                child: Padding(
                  padding: EdgeInsets.all(18.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            color: AppTheme.primaryColor,
                            size: 20.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Pilih Bulan & Tahun',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Year Selector
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              onPressed: () {
                                setDialogState(() {
                                  tempYear--;
                                });
                              },
                              tooltip: 'Tahun Sebelumnya',
                            ),
                            Text(
                              '$tempYear',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: () {
                                setDialogState(() {
                                  tempYear++;
                                });
                              },
                              tooltip: 'Tahun Berikutnya',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),

                      // 12 Months Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8.h,
                          crossAxisSpacing: 8.w,
                          childAspectRatio: 2.2,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final mNum = index + 1;
                          final isSelectedMonth =
                              tempYear == _selectedMonth.year &&
                              mNum == _selectedMonth.month;
                          final isCurrentMonth =
                              tempYear == now.year && mNum == now.month;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedMonth = DateTime(tempYear, mNum, 1);
                              });
                              Navigator.pop(dialogCtx);
                            },
                            borderRadius: BorderRadius.circular(8.r),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelectedMonth
                                    ? AppTheme.primaryColor
                                    : (isDark
                                        ? const Color(0xFF334155).withValues(alpha: 0.5)
                                        : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color: isSelectedMonth
                                      ? AppTheme.primaryColor
                                      : (isCurrentMonth
                                          ? AppTheme.primaryColor.withValues(alpha: 0.5)
                                          : (isDark
                                              ? const Color(0xFF475569)
                                              : const Color(0xFFCBD5E1))),
                                  width: isSelectedMonth || isCurrentMonth ? 1.5 : 1.0,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                monthNames[index],
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12.sp,
                                  fontWeight: isSelectedMonth
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelectedMonth
                                      ? Colors.white
                                      : (isCurrentMonth
                                          ? AppTheme.primaryColor
                                          : Theme.of(context).colorScheme.onSurface),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 14.h),

                      // Shortcut: "Bulan Ini"
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(now.year, now.month, 1);
                            });
                            Navigator.pop(dialogCtx);
                          },
                          icon: const Icon(Icons.today_rounded, size: 16),
                          label: Text(
                            'Bulan Ini',
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.sp,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final Color cardBg = Theme.of(context).colorScheme.surface;
    final Color cardBorder = Theme.of(context).colorScheme.outlineVariant;
    final Color textPrimary = Theme.of(context).colorScheme.onSurface;
    final Color textSecondary = Theme.of(context).colorScheme.onSurfaceVariant;

    final cleanActiveSchoolId =
        AppHelper.parseSingleCleanSchoolId(authProvider.activeSchoolId) ??
        authProvider.activeSchoolId?.trim();

    // 1. Filter active schedules for this teacher in the selected month
    final schedulesInMonth = scheduleProvider.cachedTeacherSchedules.where((s) {
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final sSchoolId =
            AppHelper.parseSingleCleanSchoolId(s.schoolId) ??
            s.schoolId?.trim();
        if (sSchoolId != null &&
            sSchoolId.isNotEmpty &&
            sSchoolId != cleanActiveSchoolId) {
          return false;
        }
      }
      return s.isActive &&
          s.date.year == _selectedMonth.year &&
          s.date.month == _selectedMonth.month;
    }).toList();

    // 2. Filter journals for this teacher in the selected month
    final journalsInMonth = journalProvider.teacherJournals.where((j) {
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final jSchoolId =
            AppHelper.parseSingleCleanSchoolId(j.schoolId) ??
            j.schoolId?.trim();
        if (jSchoolId != null &&
            jSchoolId.isNotEmpty &&
            jSchoolId != cleanActiveSchoolId) {
          return false;
        }
      }
      return j.date.year == _selectedMonth.year &&
          j.date.month == _selectedMonth.month;
    }).toList();

    // 3. Jurnal Terisi calculations (Grouped by unique session: date + classId + subjectId)
    final Set<String> uniqueScheduledSessions = {};
    for (final s in schedulesInMonth) {
      uniqueScheduledSessions.add(
        '${s.date.year}-${s.date.month}-${s.date.day}|${s.classId}|${s.subjectId}',
      );
    }
    final int totalMeetings = uniqueScheduledSessions.length;

    final Set<String> uniqueFilledSessions = {};
    for (final j in journalsInMonth) {
      uniqueFilledSessions.add(
        '${j.date.year}-${j.date.month}-${j.date.day}|${j.classId}|${j.subjectId}',
      );
    }
    final int filledMeetings = uniqueFilledSessions.length;

    final double fillRate = totalMeetings > 0
        ? (filledMeetings / totalMeetings) * 100
        : 0.0;

    // 4. Kehadiran Siswa calculations
    int totalPresents = 0;
    int totalStudents = 0;
    for (final j in journalsInMonth) {
      final cls = masterProvider.classes.firstWhere(
        (c) => c.id == j.classId,
        orElse: () =>
            ClassModel(id: '', name: '', periodId: '', studentCount: 0),
      );
      if (cls.id.isNotEmpty && cls.studentCount > 0) {
        final absents = j.sickCount + j.permissionCount + j.alphaCount;
        final presents = cls.studentCount - absents;
        totalPresents += presents > 0 ? presents : 0;
        totalStudents += cls.studentCount;
      }
    }
    final double attendanceRate = totalStudents > 0
        ? (totalPresents / totalStudents) * 100
        : 100.0;

    // 5. Status Verifikasi
    final int disetujuiCount = journalsInMonth
        .where((j) => j.status == 'verified')
        .length;
    final int pendingCount = journalsInMonth
        .where((j) => j.status == 'pending')
        .length;
    final int ditolakCount = journalsInMonth
        .where((j) => j.status == 'rejected')
        .length;

    // 6. Ketidakhadiran
    int sakitCount = 0;
    int izinCount = 0;
    int alphaCount = 0;
    for (final j in journalsInMonth) {
      sakitCount += j.sickCount;
      izinCount += j.permissionCount;
      alphaCount += j.alphaCount;
    }

    // 7. per Kelas
    final classIds = {
      ...schedulesInMonth.map((s) => s.classId),
      ...journalsInMonth.map((j) => j.classId),
    }.toList();

    final List<ClassModel> classesInMonth = classIds.map((cid) {
      return masterProvider.classes.firstWhere(
        (c) => c.id == cid,
        orElse: () =>
            ClassModel(id: cid, name: 'Kelas--', periodId: '', studentCount: 0),
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return AppScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const GuruDrawer(currentRoute: '/guru/statistics'),
      appBar: AppBar(
        leading: AppMenuButton(
          child: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () {
                Scaffold.of(ctx).openDrawer();
              },
            ),
          ),
        ),
        title: const Text('Statistik Mengajar'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Month Selector ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: cardBorder),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: _prevMonth,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      tooltip: 'Bulan Sebelumnya',
                    ),
                    InkWell(
                      onTap: _showMonthPicker,
                      borderRadius: BorderRadius.circular(8.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 6.h,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getMonthName(_selectedMonth),
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20.sp,
                              color: AppTheme.primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: _nextMonth,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      tooltip: 'Bulan Berikutnya',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),

              // ─── Jurnal Terisi & Kehadiran Siswa Row ─────────────────────────
              Row(
                children: [
                  // Jurnal Terisi
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: cardBorder),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 10.w,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Jurnal Terisi',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 56.w,
                                height: 56.w,
                                child: CircularProgressIndicator(
                                  value: fillRate / 100,
                                  strokeWidth: 5.w,
                                  backgroundColor: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFEFF6FF),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isDark
                                        ? const Color(0xFF60A5FA)
                                        : const Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                              Text(
                                '${fillRate.toStringAsFixed(1)}%',
                                style: GoogleFonts.hankenGrotesk(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.sp,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            '$filledMeetings / $totalMeetings Pertemuan',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 10.sp,
                              color: textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  // Kehadiran Siswa
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: cardBorder),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: 12.h,
                        horizontal: 10.w,
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Kehadiran Siswa',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: textSecondary,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.people_outline,
                              color: const Color(0xFF10B981),
                              size: 20.w,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            '${attendanceRate.toStringAsFixed(1)}%',
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.sp,
                              color: textPrimary,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: LinearProgressIndicator(
                              value: attendanceRate / 100,
                              minHeight: 4.h,
                              backgroundColor: isDark
                                  ? const Color(0xFF1A1D21)
                                  : const Color(0xFFEFF6FF),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),

              // ─── Status Jurnal ─────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: cardBorder),
                ),
                padding: EdgeInsets.all(isLandscape ? 12 : 12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Jurnal',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 8 : 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildVerificationCard(
                            icon: Icons.check_circle_outline,
                            color: isDark
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF10B981),
                            bgColor: isDark
                                ? const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.15)
                                : const Color(0xFFE8F5E9),
                            value: '$disetujuiCount',
                            isLandscape: isLandscape,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildVerificationCard(
                            icon: Icons.hourglass_empty,
                            color: isDark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB),
                            bgColor: isDark
                                ? const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.15)
                                : const Color(0xFFEBF5FF),
                            value: '$pendingCount',
                            isLandscape: isLandscape,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildVerificationCard(
                            icon: Icons.cancel_outlined,
                            color: isDark
                                ? const Color(0xFFF87171)
                                : Colors.red,
                            bgColor: isDark
                                ? const Color(
                                    0xFFDC2626,
                                  ).withValues(alpha: 0.15)
                                : const Color(0xFFFFEBEE),
                            value: '$ditolakCount',
                            isLandscape: isLandscape,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),

              // ─── Ketidakhadiran Siswa ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: cardBorder),
                ),
                padding: EdgeInsets.all(isLandscape ? 12 : 12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ketidakhadiran Siswa',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    SizedBox(height: isLandscape ? 8 : 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAbsenceCard(
                            label: 'Sakit',
                            value: sakitCount,
                            bgColor: isDark
                                ? const Color(
                                    0xFFD97706,
                                  ).withValues(alpha: 0.15)
                                : const Color(0xFFFEF3C7),
                            textColor: isDark
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFD97706),
                            isLandscape: isLandscape,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildAbsenceCard(
                            label: 'Izin',
                            value: izinCount,
                            bgColor: isDark
                                ? const Color(
                                    0xFF0284C7,
                                  ).withValues(alpha: 0.15)
                                : const Color(0xFFE0F2FE),
                            textColor: isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0284C7),
                            isLandscape: isLandscape,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildAbsenceCard(
                            label: 'Alpha',
                            value: alphaCount,
                            bgColor: isDark
                                ? const Color(
                                    0xFFDC2626,
                                  ).withValues(alpha: 0.15)
                                : const Color(0xFFFEE2E2),
                            textColor: isDark
                                ? const Color(0xFFF87171)
                                : const Color(0xFFDC2626),
                            isLandscape: isLandscape,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),

              // ─── Mengajar Per Kelas ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: cardBorder),
                ),
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mengajar Per Kelas',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    if (classesInMonth.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.h),
                        child: Center(
                          child: Text(
                            'Tidak ada data realisasi kelas.',
                            style: GoogleFonts.hankenGrotesk(
                              color: textSecondary,
                              fontSize: 11.sp,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: classesInMonth.length,
                        separatorBuilder: (context, _) =>
                            SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final cls = classesInMonth[index];
                          final Set<String> clsScheduledSessions = {};
                          for (final s in schedulesInMonth.where(
                            (s) => s.classId == cls.id,
                          )) {
                            clsScheduledSessions.add(
                              '${s.date.year}-${s.date.month}-${s.date.day}|${s.subjectId}',
                            );
                          }
                          final scheduledCount = clsScheduledSessions.length;

                          final Set<String> clsFilledSessions = {};
                          for (final j in journalsInMonth.where(
                            (j) => j.classId == cls.id,
                          )) {
                            clsFilledSessions.add(
                              '${j.date.year}-${j.date.month}-${j.date.day}|${j.subjectId}',
                            );
                          }
                          final filledCount = clsFilledSessions.length;

                          final double rate = scheduledCount > 0
                              ? (filledCount / scheduledCount)
                              : 0.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    cls.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '$filledCount / $scheduledCount Jurnal',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4.r),
                                child: LinearProgressIndicator(
                                  value: rate,
                                  minHeight: 3.h,
                                  backgroundColor: isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFEFF6FF),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationCard({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String value,
    bool isLandscape = false,
  }) {
    return Container(
      constraints: isLandscape ? const BoxConstraints(minHeight: 64.0) : null,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: isLandscape
          ? const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0)
          : EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isLandscape ? 18.0 : 14.w),
          SizedBox(height: isLandscape ? 6.0 : 6.h),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 15.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenceCard({
    required String label,
    required int value,
    required Color bgColor,
    required Color textColor,
    bool isLandscape = false,
  }) {
    return Container(
      constraints: isLandscape ? const BoxConstraints(minHeight: 64.0) : null,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: isLandscape
          ? const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0)
          : EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: isLandscape ? 6.0 : 4.h),
          Text(
            '$value',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
