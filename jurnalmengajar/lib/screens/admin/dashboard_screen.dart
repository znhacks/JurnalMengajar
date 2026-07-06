import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../models/schedule_model.dart';
import '../../core/utils/schedule_grouper.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);

    await Future.wait([
      masterProvider.loadAllData(),
      scheduleProvider.loadAllSchedules(),
      journalProvider.loadAllJournals(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final totalJournals = journalProvider.journals.length;
    final totalSchedules = scheduleProvider.schedules.length;
    final totalPending = journalProvider.journals.where((j) => j.status == 'pending').length;

    // Calculate unsubmitted schedules for selected day
    final schedulesForDay = scheduleProvider.schedules.where((s) =>
        s.date.year == _selectedDay.year &&
        s.date.month == _selectedDay.month &&
        s.date.day == _selectedDay.day).toList();

    final unsubmittedCount = schedulesForDay.where((s) {
      final hasJournal = journalProvider.journals.any((j) => j.scheduleId == s.id);
      return !hasJournal;
    }).length;

    final isLoading = masterProvider.isLoading || scheduleProvider.isLoading || journalProvider.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/dashboard'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryColor,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero Header Card ──────────────────────────────────────
                      _buildHeroHeader(totalPending),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Counter Grid Layout ─────────────────────────────────
                            GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 2,
                              crossAxisSpacing: 12.w,
                              mainAxisSpacing: 12.h,
                              childAspectRatio: 1.35,
                              children: [
                                _buildStatCard(
                                  'Total Jurnal',
                                  '$totalJournals',
                                  Icons.assignment_outlined,
                                  AppTheme.primaryColor,
                                ),
                                _buildStatCard(
                                  'Total Jadwal',
                                  '$totalSchedules',
                                  Icons.calendar_month_outlined,
                                  const Color(0xFF565E74),
                                ),
                                _buildStatCard(
                                  'Butuh Approval',
                                  '$totalPending',
                                  Icons.rate_review_outlined,
                                  const Color(0xFF825100),
                                ),
                                _buildStatCard(
                                  'Belum Input',
                                  '$unsubmittedCount',
                                  Icons.pending_actions_outlined,
                                  const Color(0xFFBA1A1A),
                                  subtitle: 'Hari terpilih',
                                ),
                              ],
                            ),
                            SizedBox(height: 24.h),

                            // ── Calendar Card ─────────────────────────────────────
                            _buildSectionTitle('Kalender Pemantauan'),
                            SizedBox(height: 12.h),
                            _buildCalendarCard(),
                            SizedBox(height: 24.h),

                            // ── Today's Schedule ─────────────────────────────────
                            _buildSectionTitle(
                                'Jadwal Mengajar — ${AppHelper.formatDateShort(_selectedDay)}'),
                            SizedBox(height: 12.h),
                            _buildScheduleSection(schedulesForDay, masterProvider, journalProvider),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Hero Header ───────────────────────────────────────────────────────────
  Widget _buildHeroHeader(int pendingCount) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00685F), Color(0xFF0D9488)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 2.5),
            ),
            child: CircleAvatar(
              radius: 28.r,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              child: const Icon(Icons.admin_panel_settings, size: 28, color: Colors.white),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, Selamat Datang 👋',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Administrator',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Portal Kontrol & Rekapitulasi Sekolah',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (pendingCount > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions,
                      color: Colors.white, size: 14),
                  SizedBox(width: 4.w),
                  Text(
                    '$pendingCount',
                    style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.sp),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── Section Title ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: AppTheme.onBackground,
      ),
    );
  }

  // ─── Stat Card ─────────────────────────────────────────────────────────────
  Widget _buildStatCard(String title, String count, IconData icon, Color color, {String? subtitle}) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18.w),
              ),
              if (subtitle != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subtitle,
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 8.sp, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onBackground,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11.sp,
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Calendar Card ─────────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.month,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleTextStyle: GoogleFonts.hankenGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.onBackground,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, color: AppTheme.onSurfaceVariant),
          rightChevronIcon: const Icon(Icons.chevron_right, color: AppTheme.onSurfaceVariant),
        ),
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: GoogleFonts.hankenGrotesk(
              color: Colors.white, fontWeight: FontWeight.w700),
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: GoogleFonts.hankenGrotesk(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w700,
          ),
          weekendTextStyle: GoogleFonts.hankenGrotesk(color: const Color(0xFF825100)),
          defaultTextStyle: GoogleFonts.hankenGrotesk(color: AppTheme.onBackground),
          outsideTextStyle: GoogleFonts.hankenGrotesk(color: AppTheme.outline),
        ),
      ),
    );
  }

  // ─── Schedule Section ──────────────────────────────────────────────────────
  Widget _buildScheduleSection(
    List<dynamic> schedulesForDay,
    MasterDataProvider masterProvider,
    JournalProvider journalProvider,
  ) {
    if (schedulesForDay.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
        decoration: BoxDecoration(
          color: AppTheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(Icons.event_available_outlined, color: AppTheme.outlineVariant, size: 44.w),
            SizedBox(height: 10.h),
            Text(
              'Tidak ada jadwal',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4.h),
            Text(
              'Tidak ada jadwal terdaftar untuk hari ini.',
              style: GoogleFonts.hankenGrotesk(fontSize: 12.sp, color: AppTheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final groupedSchedules = groupDailySchedules(schedulesForDay.cast<ScheduleModel>());

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedSchedules.length,
      separatorBuilder: (context, _) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final scheduleGroup = groupedSchedules[index];
        final sched = scheduleGroup.primarySchedule;
        
        final cls = masterProvider.classes.firstWhere(
          (c) => c.id == sched.classId,
          orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
        );
        final subj = masterProvider.subjects.firstWhere(
          (s) => s.id == sched.subjectId,
          orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
        );
        final teacher = masterProvider.teachers.firstWhere(
          (t) => t.id == sched.teacherId,
          orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
        );

        final hasJournal = journalProvider.journals.any((j) => scheduleGroup.scheduleIds.contains(j.scheduleId));
        final statusColor = hasJournal ? AppTheme.primaryColor : const Color(0xFFBA1A1A);
        final hoursStr = scheduleGroup.teachingHours.join(', ');

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left border accent
                Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(14.w),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          child: Icon(
                            hasJournal ? Icons.check_circle_outline : Icons.pending_actions,
                            color: statusColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${cls.name} • ${subj.name} (Jam $hoursStr)',
                                style: GoogleFonts.hankenGrotesk(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.onBackground),
                              ),
                              SizedBox(height: 3.h),
                              Text(
                                'Guru: ${teacher.name}',
                                style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12.sp,
                                    color: AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            hasJournal ? 'Sudah Input' : 'Belum Input',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
