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
import '../../widgets/guru_drawer.dart';

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
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User session not found')),
      );
    }

    // 1. Filter active schedules for this teacher in the selected month
    final schedulesInMonth = scheduleProvider.cachedTeacherSchedules.where((s) {
      return s.isActive &&
          s.date.year == _selectedMonth.year &&
          s.date.month == _selectedMonth.month;
    }).toList();

    // 2. Filter journals for this teacher in the selected month
    final journalsInMonth = journalProvider.teacherJournals.where((j) {
      return j.date.year == _selectedMonth.year &&
          j.date.month == _selectedMonth.month;
    }).toList();

    // 3. Jurnal Terisi calculations (Grouped by unique session: date + classId + subjectId)
    final Set<String> uniqueScheduledSessions = {};
    for (final s in schedulesInMonth) {
      uniqueScheduledSessions.add('${s.date.year}-${s.date.month}-${s.date.day}|${s.classId}|${s.subjectId}');
    }
    final int totalMeetings = uniqueScheduledSessions.length;

    final Set<String> uniqueFilledSessions = {};
    for (final j in journalsInMonth) {
      uniqueFilledSessions.add('${j.date.year}-${j.date.month}-${j.date.day}|${j.classId}|${j.subjectId}');
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
        orElse: () => ClassModel(id: '', name: '', periodId: '', studentCount: 0),
      );
      if (cls.id.isNotEmpty && cls.studentCount > 0) {
        final absents = j.sickCount + j.permissionCount + j.alphaCount;
        final presents = cls.studentCount - absents;
        totalPresents += presents > 0 ? presents : 0;
        totalStudents += cls.studentCount;
      }
    }
    final double attendanceRate =
        totalStudents > 0 ? (totalPresents / totalStudents) * 100 : 100.0;

    // 5. Status Verifikasi
    final int disetujuiCount = journalsInMonth.where((j) => j.status == 'verified').length;
    final int pendingCount = journalsInMonth.where((j) => j.status == 'pending').length;
    final int ditolakCount = journalsInMonth.where((j) => j.status == 'rejected').length;

    // 6. Distribusi Ketidakhadiran
    int sakitCount = 0;
    int izinCount = 0;
    int alphaCount = 0;
    for (final j in journalsInMonth) {
      sakitCount += j.sickCount;
      izinCount += j.permissionCount;
      alphaCount += j.alphaCount;
    }

    // 7. Realisasi per Kelas
    final classIds = {
      ...schedulesInMonth.map((s) => s.classId),
      ...journalsInMonth.map((j) => j.classId),
    }.toList();

    final List<ClassModel> classesInMonth = classIds.map((cid) {
      return masterProvider.classes.firstWhere(
        (c) => c.id == cid,
        orElse: () => ClassModel(id: cid, name: 'Kelas--', periodId: '', studentCount: 0),
      );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      backgroundColor: AppTheme.background,
      drawer: const GuruDrawer(currentRoute: '/guru/statistics'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () {
              Scaffold.of(ctx).openDrawer();
            },
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 2.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppTheme.primaryColor),
                      onPressed: _prevMonth,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                    ),
                    Text(
                      _getMonthName(_selectedMonth),
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppTheme.primaryColor),
                      onPressed: _nextMonth,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
                      child: Column(
                        children: [
                          Text(
                            'Jurnal Terisi',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurfaceVariant,
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
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                              Text(
                                '${fillRate.toStringAsFixed(1)}%',
                                style: GoogleFonts.hankenGrotesk(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.sp,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            '$filledMeetings / $totalMeetings Pertemuan',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 10.sp,
                              color: AppTheme.outline,
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
                      child: Column(
                        children: [
                          Text(
                            'Kehadiran Siswa',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 10.h),
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
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
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4.r),
                            child: LinearProgressIndicator(
                              value: attendanceRate / 100,
                              minHeight: 4.h,
                              backgroundColor: const Color(0xFFEFF6FF),
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

              // ─── Status Verifikasi Jurnal ─────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status Verifikasi Jurnal',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    // Disetujui
                    _buildVerificationRow(
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF10B981),
                      label: 'Disetujui',
                      value: '$disetujuiCount Jurnal',
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 10),
                    // Pending
                    _buildVerificationRow(
                      icon: Icons.hourglass_empty,
                      color: const Color(0xFF2563EB),
                      label: 'Pending / Proses',
                      value: '$pendingCount Jurnal',
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 10),
                    // Ditolak
                    _buildVerificationRow(
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                      label: 'Ditolak',
                      value: '$ditolakCount Jurnal',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),

              // ─── Distribusi Ketidakhadiran Siswa ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distribusi Ketidakhadiran Siswa',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Expanded(
                          child: _buildAbsenceCard(
                            label: 'Sakit',
                            value: sakitCount,
                            bgColor: const Color(0xFFFEF3C7),
                            textColor: const Color(0xFFD97706),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildAbsenceCard(
                            label: 'Izin',
                            value: izinCount,
                            bgColor: const Color(0xFFE0F2FE),
                            textColor: const Color(0xFF0284C7),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: _buildAbsenceCard(
                            label: 'Alpha',
                            value: alphaCount,
                            bgColor: const Color(0xFFFEE2E2),
                            textColor: const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10.h),

              // ─── Realisasi Mengajar Per Kelas ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Realisasi Mengajar Per Kelas',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
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
                              color: AppTheme.outline,
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
                        separatorBuilder: (context, _) => SizedBox(height: 10.h),
                        itemBuilder: (context, index) {
                          final cls = classesInMonth[index];
                          final Set<String> clsScheduledSessions = {};
                          for (final s in schedulesInMonth.where((s) => s.classId == cls.id)) {
                            clsScheduledSessions.add('${s.date.year}-${s.date.month}-${s.date.day}|${s.subjectId}');
                          }
                          final scheduledCount = clsScheduledSessions.length;

                          final Set<String> clsFilledSessions = {};
                          for (final j in journalsInMonth.where((j) => j.classId == cls.id)) {
                            clsFilledSessions.add('${j.date.year}-${j.date.month}-${j.date.day}|${j.subjectId}');
                          }
                          final filledCount = clsFilledSessions.length;

                          final double rate = scheduledCount > 0
                              ? (filledCount / scheduledCount)
                              : 0.0;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    cls.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    '$filledCount / $scheduledCount Jurnal',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryColor,
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
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor,
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

  Widget _buildVerificationRow({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 14.w),
        SizedBox(width: 6.w),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF475569),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAbsenceCard({
    required String label,
    required int value,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 6.w),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '$value',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Kasus',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 9.sp,
              color: textColor.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
