import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/utils/helper.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../models/schedule_model.dart';
import '../../models/journal_model.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/school_switcher_modal.dart';
import '../../core/theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  final String? selectedTeacherId;
  const AdminDashboardScreen({super.key, this.selectedTeacherId});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? _selectedTeacherId;
  DateTime? _lastBackPressTime;

  String? _lastLoadedSchoolId;
  String? _lastLoadedUserId;

  @override
  void initState() {
    super.initState();
    _selectedTeacherId = widget.selectedTeacherId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentSchoolId = authProvider.activeSchoolId;
      if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
        _lastLoadedSchoolId = currentSchoolId;
        _lastLoadedUserId = authProvider.currentUser?.id;
        _refreshData();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final currentSchoolId = authProvider.activeSchoolId;
    final currentUserId = authProvider.currentUser?.id;

    final hasSchoolChanged = _lastLoadedSchoolId != currentSchoolId;
    final hasUserChanged = _lastLoadedUserId != currentUserId;

    if (hasSchoolChanged || hasUserChanged) {
      _lastLoadedSchoolId = currentSchoolId;
      _lastLoadedUserId = currentUserId;
      if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _refreshData();
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant AdminDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTeacherId != oldWidget.selectedTeacherId) {
      setState(() {
        _selectedTeacherId = widget.selectedTeacherId;
      });
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = authProvider.activeSchoolId;
    if (schoolId == null || schoolId.isEmpty) {
      debugPrint('[RUNTIME_DEBUG:ADMIN_DASHBOARD] activeSchoolId is not ready yet, postponing _refreshData.');
      return;
    }

    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    final scheduleProvider = Provider.of<ScheduleProvider>(
      context,
      listen: false,
    );
    final journalProvider = Provider.of<JournalProvider>(
      context,
      listen: false,
    );

    debugPrint(
      '----------------------------------------------------------------',
    );
    debugPrint('[RUNTIME_DEBUG:ADMIN_DASHBOARD] _refreshData called.');
    debugPrint(
      '[RUNTIME_DEBUG:ADMIN_DASHBOARD] Auth State: user=${authProvider.currentUser?.email}, role=${authProvider.activeRole}, schoolId=$schoolId, schoolName="${authProvider.activeSchoolName}"',
    );

    final holidayProvider = Provider.of<HolidayProvider>(
      context,
      listen: false,
    );
    final warningProvider = Provider.of<WarningLetterProvider>(
      context,
      listen: false,
    );

    await Future.wait([
      masterProvider.loadAllData(authProvider.activeSchoolId),
      scheduleProvider.loadAllSchedules(authProvider.activeSchoolId),
      journalProvider.loadAllJournals(authProvider.activeSchoolId),
      holidayProvider.loadHolidays(schoolId),
      warningProvider.loadAllWarningLetters(authProvider.activeSchoolId),
    ]);

    debugPrint('[RUNTIME_DEBUG:ADMIN_DASHBOARD] Data Refresh Finished.');
    debugPrint(
      '[RUNTIME_DEBUG:ADMIN_DASHBOARD] masterProvider.teachers: ${masterProvider.teachers.length}',
    );
    debugPrint(
      '[RUNTIME_DEBUG:ADMIN_DASHBOARD] scheduleProvider.schedules: ${scheduleProvider.schedules.length}',
    );
    debugPrint(
      '----------------------------------------------------------------',
    );

    // Run Warning Letters Check & Issue in background (asynchronous, does not block dashboard rendering)
    if (mounted) {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final maxDays = settingsProvider.settings?.maxJournalInputDays ?? 3;

      warningProvider.checkAndIssueWarnings(
        schedules: scheduleProvider.schedules,
        journals: journalProvider.journals,
        maxDays: maxDays,
        masterProvider: masterProvider,
      ).then((_) {
        if (mounted) {
          warningProvider.loadAllWarningLetters(authProvider.activeSchoolId);
        }
      }).catchError((err) {
        debugPrint('[ADMIN_DASHBOARD] Background warning check error: $err');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!authProvider.initialized || authProvider.activeSchoolId == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();
    context.watch<HolidayProvider>();
    final schoolSchedules = scheduleProvider.schedules;
    final schoolJournals = journalProvider.journals;

    debugPrint(
      '[RUNTIME_DEBUG:ADMIN_DASHBOARD] build() triggered. SelectedTeacherId: $_selectedTeacherId, TotalSchedules: ${schoolSchedules.length}, TotalTeachers: ${masterProvider.teachers.length}',
    );

    final filteredJournals = _selectedTeacherId == null
        ? schoolJournals
        : schoolJournals.where((j) {
            final sched = scheduleProvider.schedules.firstWhere(
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
            );
            return sched.teacherId == _selectedTeacherId ||
                j.teacherId == _selectedTeacherId;
          }).toList();

    final totalJournals = filteredJournals.length;
    final totalPending = filteredJournals
        .where((j) => j.status == 'pending')
        .length;

    // Calculate start and end of week in UTC using component year/month/day directly to avoid local timezone shifts
    final startOfWeek = DateTime.utc(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    ).subtract(Duration(days: _focusedDay.weekday - 1));
    final endOfWeek = DateTime.utc(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
      23,
      59,
      59,
    ).add(const Duration(days: 6));

    final hasHighlightBefore = schoolSchedules.any((s) {
      if (!s.isActive) return false;
      if (_selectedTeacherId != null && s.teacherId != _selectedTeacherId) {
        return false;
      }
      final sDate = DateTime.utc(s.date.year, s.date.month, s.date.day);
      return sDate.isBefore(startOfWeek);
    });

    final hasHighlightAfter = schoolSchedules.any((s) {
      if (!s.isActive) return false;
      if (_selectedTeacherId != null && s.teacherId != _selectedTeacherId) {
        return false;
      }
      final sDate = DateTime.utc(s.date.year, s.date.month, s.date.day);
      return sDate.isAfter(endOfWeek);
    });

    // Calculate unsubmitted schedules for selected day using UTC calendar date comparison to avoid timezone shifts
    final schedulesForDay = schoolSchedules.where((s) {
      return s.date.year == _selectedDay.year &&
          s.date.month == _selectedDay.month &&
          s.date.day == _selectedDay.day;
    }).toList();

    final filteredSchedulesForDay = _selectedTeacherId == null
        ? schedulesForDay
        : schedulesForDay
              .where((s) => s.teacherId == _selectedTeacherId)
              .toList();

    final groupedSchedulesForDay = groupDailySchedules(filteredSchedulesForDay);
    final unsubmittedCount = groupedSchedulesForDay.where((group) {
      final hasCompletedJournal = journalProvider.journals.any(
        (j) => group.scheduleIds.contains(j.scheduleId) && j.status != 'rejected',
      );
      return !hasCompletedJournal;
    }).length;

    final selectedTeacher = _selectedTeacherId == null
        ? null
        : masterProvider.teachers.firstWhere(
            (t) => t.id == _selectedTeacherId,
            orElse: () => TeacherModel(
              id: '',
              name: 'Guru--',
              position: '',
              address: '',
              phoneNumber: '',
              email: '',
            ),
          );

    final isLoading =
        masterProvider.isLoading ||
        scheduleProvider.isLoading ||
        journalProvider.isLoading;

    final primaryColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color.fromARGB(255, 37, 99, 235);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tekan sekali lagi untuk keluar dari aplikasi',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              margin: EdgeInsets.all(16.w),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          title: Builder(
            builder: (context) {
              final isAdminOnly = authProvider.isExclusiveAdmin;
              final titleWidget = Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Column(
                  children: [
                    Text(
                      'Dashboard Admin',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          authProvider.activeSchoolName,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        if (!isAdminOnly) ...[
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 14.sp,
                            color: const Color(0xFF2563EB),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );

              if (isAdminOnly) {
                return titleWidget;
              }

              return InkWell(
                onTap: () => SchoolSwitcherModal.show(context),
                borderRadius: BorderRadius.circular(8.r),
                child: titleWidget,
              );
            },
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 14.w),
              child: RoleBadge(
                role: authProvider.activeRole,
                fontSize: 10.sp,
                onTap: authProvider.isExclusiveAdmin
                    ? null
                    : () => SchoolSwitcherModal.show(context),
              ),
            ),
          ],
        ),
        drawer: const AdminDrawer(currentRoute: '/admin/dashboard'),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshData,
                color: const Color(0xFF2563EB),
                child: SafeArea(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Calendar Card (Top Section)
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 50),
                            child: _buildCalendarCard(
                              schoolSchedules,
                              schoolJournals,
                              hasHighlightBefore,
                              hasHighlightAfter,
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // 2. Teacher Selector Filter
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 100),
                            child: _buildTeacherSelectorCompact(
                              masterProvider.teachers,
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // 3. Stat Cards Row (4 Grid Cards)
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 150),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'Total Jadwal',
                                    '${groupedSchedulesForDay.length}',
                                    Icons.calendar_month_rounded,
                                    accentColor: const Color(0xFF2563EB),
                                    bgColor: const Color(0xFFEFF6FF),
                                    borderColor: const Color(0xFFDBEAFE),
                                    onTap: () =>
                                        context.push('/admin/schedules'),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _buildStatCard(
                                    'Total Jurnal',
                                    '$totalJournals',
                                    Icons.assignment_rounded,
                                    accentColor: const Color(0xFF0284C7),
                                    bgColor: const Color(0xFFF0F9FF),
                                    borderColor: const Color(0xFFBAE6FD),
                                    onTap: () =>
                                        context.push('/admin/journals'),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _buildStatCard(
                                    'Menunggu',
                                    '$totalPending',
                                    Icons.rate_review_rounded,
                                    accentColor: const Color(0xFFD97706),
                                    bgColor: const Color(0xFFFEF3C7),
                                    borderColor: const Color(0xFFFDE68A),
                                    onTap: () =>
                                        context.push('/admin/journals?tab=2'),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: _buildStatCard(
                                    'Belum Input',
                                    '$unsubmittedCount',
                                    Icons.pending_actions_rounded,
                                    accentColor: const Color(0xFFE11D48),
                                    bgColor: const Color(0xFFFFE4E6),
                                    borderColor: const Color(0xFFFECDD3),
                                    onTap: () =>
                                        context.push('/admin/journals?tab=1'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16.h),

                          // 4. Shortcut ke Halaman Statistik & Kedisiplinan Guru
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 175),
                            child: InkWell(
                              onTap: () =>
                                  context.push('/admin/teacher-statistics'),
                              borderRadius: BorderRadius.circular(14.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [
                                            const Color(0xFF1E293B),
                                            const Color(0xFF0F172A),
                                          ]
                                        : [
                                            const Color(0xFFEFF6FF),
                                            const Color(0xFFDBEAFE),
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14.r),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF334155)
                                        : const Color(0xFFBFDBFE),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.2 : 0.04,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(9.r),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(
                                          alpha: 0.15,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.analytics_rounded,
                                        color: primaryColor,
                                        size: 20.r,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Statistik & Kedisiplinan Guru',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 13.5.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            'Lihat guru yang paling sering tepat waktu dan paling sering terlambat mengisi jurnal.',
                                            style: TextStyle(
                                              fontSize: 11.sp,
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
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(
                                          9.r,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Buka',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 13.r,
                                            color: Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),

                          // 5. Schedule List Section
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 200),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  _selectedTeacherId == null
                                      ? 'Jadwal — ${AppHelper.formatDateShort(_selectedDay)}'
                                      : '${selectedTeacher?.name} — ${AppHelper.formatDateShort(_selectedDay)}',
                                ),
                                SizedBox(height: 8.h),
                                _buildScheduleSection(
                                  filteredSchedulesForDay,
                                  masterProvider,
                                  journalProvider,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Section Title ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 15.sp,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  // ─── Stat Card ─────────────────────────────────────────────────────────────
  Widget _buildStatCard(
    String title,
    String count,
    IconData icon, {
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletOrDesktop = screenWidth >= 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTabletOrDesktop ? 10.w : 6.w,
            vertical: isTabletOrDesktop ? 14.h : 12.h,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark ? accentColor.withValues(alpha: 0.3) : borderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Container
              Container(
                padding: EdgeInsets.all(isTabletOrDesktop ? 9.w : 7.w),
                decoration: BoxDecoration(
                  color: isDark ? accentColor.withValues(alpha: 0.2) : bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: isTabletOrDesktop ? 20.w : 16.w,
                ),
              ),
              SizedBox(height: isTabletOrDesktop ? 10.h : 8.h),
              // Count Number
              Text(
                count,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: isTabletOrDesktop ? 20.sp : 18.sp,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              // Title text
              Text(
                title,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: isTabletOrDesktop ? 12.sp : 10.5.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Calendar Card ─────────────────────────────────────────────────────────

  bool _hasTeacherScheduleOnDay(List<ScheduleModel> schedules, DateTime day) {
    final activeSchoolId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).activeSchoolId;
    final cleanActiveSchoolId =
        AppHelper.parseSingleCleanSchoolId(activeSchoolId) ??
        activeSchoolId?.trim();
    if (_selectedTeacherId == null) {
      return schedules.any((s) {
        if (!s.isActive) return false;
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
        return s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day;
      });
    }
    return schedules.any((s) {
      if (!s.isActive || s.teacherId != _selectedTeacherId) return false;
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
      return s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day;
    });
  }

  bool _areAllSchedulesFilledOnDay(
    List<ScheduleModel> schedules,
    List<JournalModel> journals,
    DateTime day,
  ) {
    final activeSchoolId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).activeSchoolId;
    final cleanActiveSchoolId =
        AppHelper.parseSingleCleanSchoolId(activeSchoolId) ??
        activeSchoolId?.trim();

    final daySchedules = schedules.where((s) {
      if (!s.isActive) return false;
      if (_selectedTeacherId != null && s.teacherId != _selectedTeacherId) {
        return false;
      }
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
      return s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day;
    }).toList();

    if (daySchedules.isEmpty) return false;

    final grouped = groupDailySchedules(daySchedules);
    if (grouped.isEmpty) return false;

    return grouped.every((group) {
      final s = group.primarySchedule;
      return journals.any((j) {
        final sameDate = j.date.year == day.year &&
            j.date.month == day.month &&
            j.date.day == day.day;
        final sameSchedule = j.scheduleId == s.id ||
            group.scheduleIds.contains(j.scheduleId) ||
            (j.classId == s.classId &&
                j.subjectId == s.subjectId &&
                j.teacherId == s.teacherId);
        return sameDate &&
            sameSchedule &&
            j.status != 'rejected' &&
            (j.status == 'pending' ||
                j.status == 'verified' ||
                j.isTeacherAbsence);
      });
    });
  }

  Widget _buildScheduledDayCell(
    DateTime day,
    bool isSelected,
    bool isToday,
    bool isOutside,
    List<ScheduleModel> schedules,
    List<JournalModel> journals,
  ) {
    final hasSchedule = _hasTeacherScheduleOnDay(schedules, day);
    final isAllFilled =
        hasSchedule && _areAllSchedulesFilledOnDay(schedules, journals, day);

    final holidayProvider = Provider.of<HolidayProvider>(
      context,
      listen: false,
    );
    final holiday = holidayProvider.getHolidayForDate(day);
    final isHoliday = holiday != null ||
        (_selectedTeacherId != null
            ? journals.any((j) =>
                j.teacherId == _selectedTeacherId &&
                j.date.year == day.year &&
                j.date.month == day.month &&
                j.date.day == day.day &&
                j.isTeacherAbsence &&
                j.status != 'rejected')
            : false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSunday = day.weekday == DateTime.sunday;

    Color bgColor = Colors.transparent;
    Color textColor = isOutside
        ? (isDark ? const Color(0xFF64748B) : AppTheme.outline)
        : (isSunday
              ? const Color(0xFFEF4444)
              : Theme.of(context).colorScheme.onSurface);
    FontWeight fontWeight = FontWeight.w500;
    BoxBorder? border;

    if (isSelected) {
      // Indikator kalender yang terpilih tetap berwarna biru kecuali ketika libur / cuti berwarna merah
      if (isHoliday) {
        bgColor = const Color(0xFFDC2626);
        textColor = Colors.white;
        fontWeight = FontWeight.w700;
        border = Border.all(
          color: const Color(0xFFEF4444),
          width: 2.0,
        );
      } else {
        bgColor = AppTheme.primaryColor;
        textColor = Colors.white;
        fontWeight = FontWeight.w700;
        border = Border.all(
          color: const Color(0xFF60A5FA),
          width: 2.0,
        );
      }
    } else if (isHoliday) {
      // Libur / cuti: berwarna merah
      bgColor = const Color(0xFFDC2626).withValues(alpha: isDark ? 0.22 : 0.15);
      textColor = const Color(0xFFEF4444);
      fontWeight = FontWeight.w700;
      border = Border.all(
        color: const Color(0xFFEF4444),
        width: 1.5,
      );
    } else if (hasSchedule) {
      if (isAllFilled) {
        // Selesai semua jadwal diisi: berwarna biru
        bgColor = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.22 : 0.15);
        textColor = isOutside
            ? (isDark ? const Color(0xFF64748B) : AppTheme.outline)
            : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8));
        fontWeight = FontWeight.w700;
        border = Border.all(
          color: const Color(0xFF3B82F6),
          width: 1.5,
        );
      } else {
        // Memiliki jadwal tetapi belum semua mengisi jurnal: berwarna hijau
        bgColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.15);
        textColor = isOutside
            ? (isDark ? const Color(0xFF64748B) : AppTheme.outline)
            : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857));
        fontWeight = FontWeight.w700;
        border = Border.all(
          color: const Color(0xFF10B981),
          width: 1.5,
        );
      }
    } else if (isToday) {
      bgColor = AppTheme.primaryColor.withValues(alpha: isDark ? 0.25 : 0.15);
      textColor = isDark ? const Color(0xFF93C5FD) : AppTheme.primaryColor;
      fontWeight = FontWeight.w700;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 12.sp,
          fontWeight: fontWeight,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCalendarCard(
    List<ScheduleModel> schedules,
    List<JournalModel> journals,
    bool hasHighlightBefore,
    bool hasHighlightAfter,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppTheme.outlineVariant,
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 4.w),
      child: TableCalendar(
        locale: 'id_ID',
        headerStyle: HeaderStyle(
          headerPadding: EdgeInsets.symmetric(vertical: 4.h),
          titleCentered: true,
          formatButtonVisible: false,
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryColor,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryColor,
          ),
          titleTextStyle: GoogleFonts.hankenGrotesk(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        daysOfWeekHeight: 22.h,
        rowHeight: 38.h,
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: CalendarFormat.week,
        startingDayOfWeek: StartingDayOfWeek.monday,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        onHeaderTapped: (_) => _showFullCalendarDialog(context, schedules, journals),
        calendarBuilders: CalendarBuilders(
          dowBuilder: (context, day) {
            final dayName = DateFormat.E('id_ID').format(day);
            final isSunday = day.weekday == DateTime.sunday;
            return Container(
              alignment: Alignment.center,
              child: Text(
                dayName,
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: isSunday
                      ? const Color(0xFFEF4444)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          },
          defaultBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(day, false, false, false, schedules, journals);
          },
          outsideBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(day, false, false, true, schedules, journals);
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(day, false, true, false, schedules, journals);
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(day, true, false, false, schedules, journals);
          },
        ),
      ),
    );
  }

  void _showFullCalendarDialog(
    BuildContext context,
    List<ScheduleModel> schedules,
    List<JournalModel> journals,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        DateTime focused = _focusedDay;
        DateTime selected = _selectedDay;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 24.h,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pilih Tanggal',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    Divider(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                    TableCalendar(
                      locale: 'id_ID',
                      daysOfWeekHeight: 30.h,
                      rowHeight: 44.h,
                      firstDay: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: focused,
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: GoogleFonts.hankenGrotesk(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                        leftChevronIcon: Icon(
                          Icons.chevron_left_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        rightChevronIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      selectedDayPredicate: (day) => isSameDay(selected, day),
                      onDaySelected: (selDay, focDay) {
                        setDialogState(() {
                          selected = selDay;
                          focused = focDay;
                        });
                        setState(() {
                          _selectedDay = selDay;
                          _focusedDay = focDay;
                        });
                        Navigator.pop(context);
                      },
                      onPageChanged: (focDay) {
                        setDialogState(() {
                          focused = focDay;
                        });
                        setState(() {
                          _focusedDay = focDay;
                        });
                      },
                      calendarBuilders: CalendarBuilders(
                        dowBuilder: (context, day) {
                          final dayName = DateFormat.E('id_ID').format(day);
                          final isSunday = day.weekday == DateTime.sunday;
                          return Container(
                            alignment: Alignment.center,
                            child: Text(
                              dayName,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: isSunday
                                    ? const Color(0xFFEF4444)
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                        defaultBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            false,
                            false,
                            false,
                            schedules,
                            journals,
                          );
                        },
                        outsideBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            false,
                            false,
                            true,
                            schedules,
                            journals,
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            false,
                            true,
                            false,
                            schedules,
                            journals,
                          );
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            true,
                            false,
                            false,
                            schedules,
                            journals,
                          );
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        todayDecoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: GoogleFonts.hankenGrotesk(
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                          fontWeight: FontWeight.w800,
                        ),
                        weekendTextStyle: GoogleFonts.hankenGrotesk(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        defaultTextStyle: GoogleFonts.hankenGrotesk(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        outsideTextStyle: GoogleFonts.hankenGrotesk(
                          color: isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTeacherSelectorCompact(List<TeacherModel> teachers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedTeacherId),
      initialValue: _selectedTeacherId,
      isExpanded: true,
      hint: Text(
        'Filter guru...',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 12.sp,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 9.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: const BorderSide(
            color: Color(0xFF2563EB),
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
      ),
      style: GoogleFonts.hankenGrotesk(
        fontSize: 13.sp,
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      dropdownColor: Theme.of(context).colorScheme.surface,
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text(
            'Semua Guru',
            style: GoogleFonts.hankenGrotesk(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...teachers.map(
          (teacher) => DropdownMenuItem<String>(
            value: teacher.id,
            child: Text(
              teacher.name,
              style: GoogleFonts.hankenGrotesk(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _selectedTeacherId = value),
    );
  }

  // ─── Schedule Section ──────────────────────────────────────────────────────
  Widget _buildScheduleSection(
    List<dynamic> schedulesForDay,
    MasterDataProvider masterProvider,
    JournalProvider journalProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final holidayProvider = Provider.of<HolidayProvider>(
      context,
      listen: false,
    );
    final holiday = holidayProvider.getHolidayForDate(_selectedDay);

    if (schedulesForDay.isEmpty) {
      if (holiday != null) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF7F1D1D).withValues(alpha: 0.25)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF991B1B)
                  : const Color(0xFFFCA5A5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_busy_rounded,
                  color: Colors.white,
                  size: 20.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HARI LIBUR: ${holiday.title.toUpperCase()}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFFCA5A5)
                            : const Color(0xFF991B1B),
                      ),
                    ),
                    if (holiday.description != null &&
                        holiday.description!.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        holiday.description!,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5.sp,
                          color: isDark
                              ? const Color(0xFFFECACA)
                              : const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              color: const Color(0xFF94A3B8),
              size: 36.w,
            ),
            SizedBox(height: 8.h),
            Text(
              'Tidak ada jadwal untuk hari ini',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final groupedSchedules = groupDailySchedules(
      schedulesForDay.cast<ScheduleModel>(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (holiday != null) ...[
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF7F1D1D).withValues(alpha: 0.25)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF991B1B)
                    : const Color(0xFFFCA5A5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_busy_rounded,
                    color: Colors.white,
                    size: 16.r,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'HARI LIBUR: ${holiday.title.toUpperCase()}',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedSchedules.length,
      separatorBuilder: (context, _) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final scheduleGroup = groupedSchedules[index];
        final sched = scheduleGroup.primarySchedule;

        final cls = masterProvider.classes.firstWhere(
          (c) => c.id == sched.classId,
          orElse: () => ClassModel(
            id: '',
            name: 'Kelas--',
            periodId: '',
            studentCount: 0,
          ),
        );
        final subj = masterProvider.subjects.firstWhere(
          (s) => s.id == sched.subjectId,
          orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
        );
        final teacher = masterProvider.teachers.firstWhere(
          (t) => t.id == sched.teacherId,
          orElse: () => TeacherModel(
            id: '',
            name: 'Guru--',
            position: '',
            address: '',
            phoneNumber: '',
            email: '',
          ),
        );

        final matchingJournal = journalProvider.journals.cast<JournalModel?>().firstWhere(
          (j) => scheduleGroup.scheduleIds.contains(j?.scheduleId),
          orElse: () => null,
        );
        final isRejected = matchingJournal != null && matchingJournal.status == 'rejected';
        final isCompleted = matchingJournal != null && !isRejected;
        final hoursStr = AppHelper.formatTeachingHours(
          scheduleGroup.teachingHours,
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (matchingJournal != null) {
                context.push('/admin/journal/${matchingJournal.id}');
              } else {
                context.push('/admin/schedule/${sched.id}');
              }
            },
            borderRadius: BorderRadius.circular(14.r),
            child: Ink(
              decoration: BoxDecoration(
                color: isDark
                    ? Theme.of(context).colorScheme.surface
                    : Colors.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                child: Row(
                  children: [
                    // Clean Teacher Avatar Frame
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18.r,
                        backgroundColor: isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                            : const Color(0xFFEEF2FF),
                        backgroundImage:
                            teacher.photoUrl != null &&
                                teacher.photoUrl!.startsWith('http')
                            ? NetworkImage(teacher.photoUrl!)
                            : null,
                        child:
                            teacher.photoUrl == null ||
                                !teacher.photoUrl!.startsWith('http')
                            ? Icon(
                                Icons.person_rounded,
                                color: isDark
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF4F46E5),
                                size: 18.r,
                              )
                            : null,
                      ),
                    ),
                    SizedBox(width: 11.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${cls.name} • ${subj.name} (Jam $hoursStr)',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Guru: ${teacher.name}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.5.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Modern Soft Status Icon from Ref B
                    isCompleted
                        ? Container(
                            padding: EdgeInsets.all(2.w),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16.w,
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.all(5.w),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(
                                      0xFF7F1D1D,
                                    ).withValues(alpha: 0.35)
                                  : const Color(0xFFFFE4E6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.access_time_filled_rounded,
                              color: const Color(0xFFE11D48),
                              size: 15.w,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  ],
);
  }
}

