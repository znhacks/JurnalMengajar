import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/warning_letter_provider.dart';

class GuruDashboardScreen extends StatefulWidget {
  const GuruDashboardScreen({super.key});

  @override
  State<GuruDashboardScreen> createState() => _GuruDashboardScreenState();
}

class _GuruDashboardScreenState extends State<GuruDashboardScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  bool _hasCheckedReminder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      await masterProvider.loadAllData();

      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
        orElse: () => TeacherModel(
          id: '',
          name: currentUser.fullName,
          position: currentUser.position ?? 'Guru',
          address: currentUser.address ?? '',
          phoneNumber: currentUser.phoneNumber ?? '',
          email: currentUser.email,
        ),
      );

      if (teacher.id.isNotEmpty) {
        await Future.wait([
          scheduleProvider.loadTeacherSchedules(teacher.id, _selectedDay),
          journalProvider.loadTeacherJournals(teacher.id),
        ]);

        // Run Warning Letters Check & Issue if late
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        await settingsProvider.loadSettings();
        final maxDays = settingsProvider.settings?.maxJournalInputDays ?? 3;

        final warningProvider = Provider.of<WarningLetterProvider>(context, listen: false);
        await warningProvider.checkAndIssueWarnings(
          schedules: scheduleProvider.cachedTeacherSchedules,
          journals: journalProvider.teacherJournals,
          maxDays: maxDays,
          masterProvider: masterProvider,
        );
        await warningProvider.loadTeacherWarningLetters(teacher.id);

        if (!_hasCheckedReminder) {
          _hasCheckedReminder = true;
          _checkAndShowReminder(
            teacher,
            scheduleProvider,
            journalProvider,
            masterProvider,
          );
        }
      }
    }
  }

  void _checkAndShowReminder(
    TeacherModel teacher,
    ScheduleProvider scheduleProvider,
    JournalProvider journalProvider,
    MasterDataProvider masterProvider,
  ) {
    final today = DateTime.now();
    final activeSchedulesToday = scheduleProvider.cachedTeacherSchedules.where((s) {
      return s.isActive &&
          s.date.year == today.year &&
          s.date.month == today.month &&
          s.date.day == today.day;
    }).toList();

    if (activeSchedulesToday.isEmpty) return;

    final unfinishedSchedules = activeSchedulesToday.where((schedule) {
      return !journalProvider.teacherJournals.any((j) => j.scheduleId == schedule.id);
    }).toList();

    if (unfinishedSchedules.isEmpty) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
          elevation: 8,
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Stylized Warning/Calendar Icon
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFED7AA),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.assignment_late_rounded,
                    color: Color(0xFFEA580C),
                    size: 36,
                  ),
                ),
                SizedBox(height: 16.h),
                // Title
                Text(
                  'Pengingat Jurnal Mengajar',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                // Subtitle
                Text(
                  'Halo ${teacher.name}, Anda memiliki ${unfinishedSchedules.length} jadwal mengajar hari ini yang belum diisi jurnalnya. Silakan segera melengkapi:',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.sp,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                // List of Unfinished Schedules
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(12.w),
                      itemCount: unfinishedSchedules.length,
                      separatorBuilder: (context, _) => const Divider(
                        color: Color(0xFFE2E8F0),
                        height: 12,
                      ),
                      itemBuilder: (context, index) {
                        final schedule = unfinishedSchedules[index];
                        final cls = masterProvider.classes.firstWhere(
                          (c) => c.id == schedule.classId,
                          orElse: () => ClassModel(
                            id: '',
                            name: 'Kelas--',
                            periodId: '',
                            studentCount: 0,
                          ),
                        );
                        final subject = masterProvider.subjects.firstWhere(
                          (s) => s.id == schedule.subjectId,
                          orElse: () => SubjectModel(
                            id: '',
                            name: 'Mapel--',
                            isActive: false,
                          ),
                        );
                        return Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'Jam ${schedule.teachingHour}',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cls.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    subject.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.sp,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                // Action Buttons
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Oke, Saya Isi Jurnal',
                    style: GoogleFonts.hankenGrotesk(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('User session not found')));
    }

    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
      orElse: () => TeacherModel(
        id: '',
        name: currentUser.fullName,
        position: currentUser.position ?? 'Guru',
        address: currentUser.address ?? '',
        phoneNumber: currentUser.phoneNumber ?? '',
        email: currentUser.email,
        photoUrl: currentUser.photoUrl,
      ),
    );

    final totalSchedulesToday = scheduleProvider.teacherSchedulesForSelectedDate.length;
    final totalJournals = journalProvider.teacherJournals.length;
    final pendingJournals = journalProvider.teacherJournals.where((j) => j.status == 'pending').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryColor,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Header Card ──────────────────────────────────────
                _buildHeroHeader(teacher, pendingJournals),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Quick Stats Row ───────────────────────────────────
                      _buildQuickStats(totalSchedulesToday, totalJournals),
                      SizedBox(height: 24.h),

                      // ── Calendar Card ─────────────────────────────────────
                      _buildSectionTitle('Kalender Jadwal'),
                      SizedBox(height: 12.h),
                      _buildCalendarCard(teacher, scheduleProvider),
                      SizedBox(height: 24.h),

                      // ── Today's Schedule ─────────────────────────────────
                      _buildSectionTitle(
                          'Jadwal — ${AppHelper.formatDateShort(_selectedDay)}'),
                      SizedBox(height: 12.h),
                      _buildScheduleSection(masterProvider, scheduleProvider, journalProvider),
                      SizedBox(height: 24.h),

                      // ── Recent Journals ───────────────────────────────────
                      _buildSectionTitle('Jurnal Terbaru'),
                      SizedBox(height: 12.h),
                      _buildJournalSection(journalProvider, masterProvider),
                      SizedBox(height: 32.h),
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
  Widget _buildHeroHeader(TeacherModel teacher, int pendingCount) {
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
          // Avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.4), width: 2.5),
            ),
            child: CircleAvatar(
              radius: 28.r,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              backgroundImage: teacher.photoUrl != null &&
                      teacher.photoUrl!.startsWith('http')
                  ? NetworkImage(teacher.photoUrl!)
                  : null,
              child: teacher.photoUrl == null
                  ? Icon(Icons.person, size: 28.r, color: Colors.white70)
                  : null,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang 👋',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  teacher.name,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  teacher.position,
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

  // ─── Quick Stats ───────────────────────────────────────────────────────────
  Widget _buildQuickStats(int scheduleCount, int journalCount) {
    return Row(
      children: [
        Expanded(
          child: _buildStatChip(
            icon: Icons.calendar_today_outlined,
            label: 'Jadwal Hari Ini',
            value: '$scheduleCount',
            color: AppTheme.primaryColor,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildStatChip(
            icon: Icons.assignment_outlined,
            label: 'Total Jurnal',
            value: '$journalCount',
            color: const Color(0xFF825100),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18.w),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onBackground),
                ),
                Text(
                  label,
                  style: GoogleFonts.hankenGrotesk(
                      fontSize: 10.sp,
                      color: AppTheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500),
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

  // ─── Calendar Card ─────────────────────────────────────────────────────────

  /// Returns true if [day] has at least one active schedule in the cache.
  bool _hasScheduleOnDay(ScheduleProvider scheduleProvider, DateTime day) {
    return scheduleProvider.cachedTeacherSchedules.any((s) =>
        s.isActive &&
        s.date.year == day.year &&
        s.date.month == day.month &&
        s.date.day == day.day);
  }

  /// Builds a calendar day cell with yellow highlight when it has a schedule.
  Widget _buildScheduledDayCell(DateTime day, bool isSelected, bool isToday,
      bool isOutside, ScheduleProvider scheduleProvider) {
    final hasSchedule = _hasScheduleOnDay(scheduleProvider, day);

    Color bgColor = Colors.transparent;
    Color textColor = isOutside ? AppTheme.outline : AppTheme.onBackground;
    FontWeight fontWeight = FontWeight.w500;

    if (isSelected) {
      bgColor = AppTheme.primaryColor;
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
    } else if (isToday) {
      bgColor = AppTheme.primaryColor.withValues(alpha: 0.15);
      textColor = AppTheme.primaryColor;
      fontWeight = FontWeight.w700;
    } else if (hasSchedule) {
      bgColor = const Color(0xFFFFEB3B).withValues(alpha: 0.35);
      textColor = isOutside ? AppTheme.outline : AppTheme.onBackground;
      fontWeight = FontWeight.w700;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: hasSchedule && !isSelected && !isToday
            ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 13.sp,
          fontWeight: fontWeight,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCalendarCard(TeacherModel teacher, ScheduleProvider scheduleProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 365)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              if (teacher.id.isNotEmpty) {
                scheduleProvider.loadTeacherSchedules(teacher.id, selectedDay);
              }
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                return _buildScheduledDayCell(
                    day, false, false, false, scheduleProvider);
              },
              outsideBuilder: (context, day, focusedDay) {
                return _buildScheduledDayCell(
                    day, false, false, true, scheduleProvider);
              },
              todayBuilder: (context, day, focusedDay) {
                return _buildScheduledDayCell(
                    day, false, true, false, scheduleProvider);
              },
              selectedBuilder: (context, day, focusedDay) {
                return _buildScheduledDayCell(
                    day, true, false, false, scheduleProvider);
              },
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              formatButtonDecoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: GoogleFonts.hankenGrotesk(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              titleTextStyle: GoogleFonts.hankenGrotesk(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.onBackground,
              ),
              leftChevronIcon: const Icon(Icons.chevron_left,
                  color: AppTheme.onSurfaceVariant),
              rightChevronIcon: const Icon(Icons.chevron_right,
                  color: AppTheme.onSurfaceVariant),
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
              weekendTextStyle: GoogleFonts.hankenGrotesk(
                  color: const Color(0xFF825100)),
              defaultTextStyle: GoogleFonts.hankenGrotesk(
                  color: AppTheme.onBackground),
              outsideTextStyle:
                  GoogleFonts.hankenGrotesk(color: AppTheme.outline),
            ),
          ),
          // ── Legend ────────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 12.h, top: 4.h),
            child: Row(
              children: [
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEB3B).withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                  ),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Ada jadwal mengajar',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.sp,
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Schedule Section ──────────────────────────────────────────────────────
  Widget _buildScheduleSection(MasterDataProvider master,
      ScheduleProvider scheduleProvider, JournalProvider journalProvider) {
    if (scheduleProvider.isLoading) {
      return const Center(
          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (scheduleProvider.teacherSchedulesForSelectedDate.isEmpty) {
      return _buildEmptyState(
        icon: Icons.event_available_outlined,
        title: 'Tidak ada jadwal',
        subtitle: 'Tidak ada jadwal mengajar pada tanggal ini.',
      );
    }
    final groupedSchedules = groupDailySchedules(scheduleProvider.teacherSchedulesForSelectedDate);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedSchedules.length,
      separatorBuilder: (context, _) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        final scheduleGroup = groupedSchedules[index];
        return _buildScheduleCard(scheduleGroup, master, journalProvider);
      },
    );
  }

  // ─── Journal Section ───────────────────────────────────────────────────────
  Widget _buildJournalSection(
      JournalProvider journalProvider, MasterDataProvider masterProvider) {
    if (journalProvider.teacherJournals.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: 'Belum ada jurnal',
        subtitle: 'Jurnal yang Anda isi akan muncul di sini.',
      );
    }
    final list = journalProvider.teacherJournals.length > 3
        ? journalProvider.teacherJournals.sublist(0, 3)
        : journalProvider.teacherJournals;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, _) => SizedBox(height: 10.h),
      itemBuilder: (context, index) {
        return _buildJournalCard(list[index], masterProvider);
      },
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState(
      {required IconData icon, required String title, required String subtitle}) {
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
          Icon(icon, color: AppTheme.outlineVariant, size: 44.w),
          SizedBox(height: 10.h),
          Text(
            title,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: GoogleFonts.hankenGrotesk(
                fontSize: 12.sp, color: AppTheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─── Schedule Card ─────────────────────────────────────────────────────────
  Widget _buildScheduleCard(
    GroupedDailySchedule scheduleGroup,
    MasterDataProvider master,
    JournalProvider journalProvider,
  ) {
    final schedule = scheduleGroup.primarySchedule;
    final cls = master.classes.firstWhere(
      (c) => c.id == schedule.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == schedule.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );
    
    final matchedHours = master.hours
        .where((h) => scheduleGroup.teachingHours.contains(h.teachingHour))
        .toList()
      ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

    final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '00:00';
    final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '00:00';
    final hoursStr = scheduleGroup.teachingHours.join(', ');

    return InkWell(
      onTap: () => context.push('/guru/schedule/${schedule.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
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
                      // Hour chip
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Jam',
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 9.sp,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '#$hoursStr',
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 16.sp,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w800),
                            ),
                            Text(
                              hrStart,
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 9.sp,
                                  color: AppTheme.primaryColor),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 14.w),
                      // Class & Subject
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              cls.name,
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onBackground),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              subject.name,
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13.sp,
                                  color: AppTheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                const Icon(Icons.people_outline,
                                    size: 12, color: AppTheme.outline),
                                SizedBox(width: 3.w),
                                Text(
                                  '${cls.studentCount} Siswa',
                                  style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.sp, color: AppTheme.outline),
                                ),
                                SizedBox(width: 8.w),
                                const Icon(Icons.access_time_outlined,
                                    size: 12, color: AppTheme.outline),
                                SizedBox(width: 3.w),
                                Text(
                                  '$hrStart–$hrEnd',
                                  style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.sp, color: AppTheme.outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.outline, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Journal Card ──────────────────────────────────────────────────────────
  Widget _buildJournalCard(JournalModel journal, MasterDataProvider master) {
    final cls = master.classes.firstWhere(
      (c) => c.id == journal.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == journal.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final statusColor = AppHelper.getStatusColor(journal.status);

    return InkWell(
      onTap: () => context.push('/guru/journal/${journal.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Status accent bar
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${cls.name} · ${subject.name}',
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.onBackground),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          // Pill status badge
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppHelper.getStatusLabel(journal.status),
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        journal.material,
                        style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 11, color: AppTheme.outline),
                          SizedBox(width: 4.w),
                          Text(
                            AppHelper.formatDateShort(journal.date),
                            style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp, color: AppTheme.outline),
                          ),
                          const Spacer(),
                          Text(
                            'S:${journal.sickCount} I:${journal.permissionCount} A:${journal.alphaCount}',
                            style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp,
                                color: AppTheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
