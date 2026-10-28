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
import '../../models/schedule_model.dart';
import '../../models/journal_model.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/school_switcher_modal.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/state_widgets.dart';

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
      debugPrint(
        '[RUNTIME_DEBUG:ADMIN_DASHBOARD] activeSchoolId is not ready yet, postponing _refreshData.',
      );
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

      warningProvider
          .checkAndIssueWarnings(
            schedules: scheduleProvider.schedules,
            journals: journalProvider.journals,
            maxDays: maxDays,
            masterProvider: masterProvider,
          )
          .then((_) {
            if (mounted) {
              warningProvider.loadAllWarningLetters(
                authProvider.activeSchoolId,
              );
            }
          })
          .catchError((err) {
            debugPrint(
              '[ADMIN_DASHBOARD] Background warning check error: $err',
            );
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!authProvider.initialized || authProvider.activeSchoolId == null) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final holidayProvider = context.watch<HolidayProvider>();
    final schoolSchedules = scheduleProvider.schedules;
    final schoolJournals = journalProvider.journals;

    final cleanActiveSchoolId =
        AppHelper.parseSingleCleanSchoolId(authProvider.activeSchoolId) ??
        authProvider.activeSchoolId?.trim();

    final calendarLookup = _AdminCalendarLookup.build(
      schedules: schoolSchedules,
      journals: schoolJournals,
      selectedTeacherId: _selectedTeacherId,
      cleanActiveSchoolId: cleanActiveSchoolId,
      holidayProvider: holidayProvider,
    );

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

    final journalsForDay = filteredJournals.where((j) {
      return j.date.year == _selectedDay.year &&
          j.date.month == _selectedDay.month &&
          j.date.day == _selectedDay.day;
    }).toList();

    final totalJournals = journalsForDay.length;
    final totalPending = journalsForDay
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
        (j) =>
            group.scheduleIds.contains(j.scheduleId) && j.status != 'rejected',
      );
      return !hasCompletedJournal;
    }).length;

    final isLoading =
        masterProvider.isLoading ||
        scheduleProvider.isLoading ||
        journalProvider.isLoading;
    final loadError =
        masterProvider.errorMessage ??
        scheduleProvider.errorMessage ??
        journalProvider.errorMessage;

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
      child: AppScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          centerTitle: true,
          scrolledUnderElevation: 0,
          title: Builder(
            builder: (context) {
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
                        if (!authProvider.isAdminAsli ||
                            authProvider.hasMultipleSchools) ...[
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

              final canSwitch =
                  !authProvider.isAdminAsli || authProvider.hasMultipleSchools;
              if (!canSwitch) return titleWidget;

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
              child: Builder(
                builder: (context) {
                  final canSwitch =
                      !authProvider.isAdminAsli ||
                      authProvider.hasMultipleSchools;
                  return RoleBadge(
                    role: authProvider.activeRole,
                    fontSize: 10.sp,
                    onTap: canSwitch
                        ? () => SchoolSwitcherModal.show(context)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
        drawer: const AdminDrawer(currentRoute: '/admin/dashboard'),
        body: isLoading && schoolSchedules.isEmpty && schoolJournals.isEmpty
            ? const AppLoadingWidget(message: 'Memuat dashboard...')
            : loadError != null &&
                  schoolSchedules.isEmpty &&
                  schoolJournals.isEmpty
            ? AppErrorWidget(message: loadError, onRetry: _refreshData)
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
                          _buildCalendarCard(
                            calendarLookup,
                            hasHighlightBefore,
                            hasHighlightAfter,
                          ),
                          SizedBox(height: 14.h),

                          // 2. Stat Cards Row (4 Grid Cards)
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Jadwal',
                                  '${groupedSchedulesForDay.length}',
                                  Icons.calendar_month_rounded,
                                  accentColor: const Color(0xFF2563EB),
                                  bgColor: const Color(0xFFEFF6FF),
                                  borderColor: const Color(0xFFDBEAFE),
                                  onTap: () => context.push(
                                    '/admin/schedules?${_statQuery()}',
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _buildStatCard(
                                  'Belum Diisi',
                                  '$unsubmittedCount',
                                  Icons.pending_actions_rounded,
                                  accentColor: const Color(0xFFE11D48),
                                  bgColor: const Color(0xFFFFE4E6),
                                  borderColor: const Color(0xFFFECDD3),
                                  onTap: () => context.push(
                                    '/admin/journals?${_statQuery(tab: 1)}',
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _buildStatCard(
                                  'Pending',
                                  '$totalPending',
                                  Icons.rate_review_rounded,
                                  accentColor: const Color(0xFFD97706),
                                  bgColor: const Color(0xFFFEF3C7),
                                  borderColor: const Color(0xFFFDE68A),
                                  onTap: () => context.push('/admin/journals?tab=2'),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _buildStatCard(
                                  'Jurnal',
                                  '$totalJournals',
                                  Icons.assignment_rounded,
                                  accentColor: const Color(0xFF0284C7),
                                  bgColor: const Color(0xFFF0F9FF),
                                  borderColor: const Color(0xFFBAE6FD),
                                  onTap: () => context.push(
                                    '/admin/journals?${_statQuery()}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 16.h),

                          // Baris tautan cepat ke Laporan & Statistik
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      context.push('/admin/teacher-statistics'),
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 10.h,
                                    ),
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
                                          padding: EdgeInsets.all(7.w),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Icon(
                                            Icons.analytics_rounded,
                                            size: 18.r,
                                            color: const Color(0xFF2563EB),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            'Statistik Guru',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 12.5.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: InkWell(
                                  onTap: () =>
                                      context.push('/admin/class-attendance-recap'),
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 10.h,
                                    ),
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
                                          padding: EdgeInsets.all(7.w),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8.r),
                                          ),
                                          child: Icon(
                                            Icons.fact_check_rounded,
                                            size: 18.r,
                                            color: const Color(0xFF0D9488),
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            'Kehadiran',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 12.5.sp,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 18.h),

                          // 4. Banner Hari Libur / Minggu / Cuti Guru (Jika Tanggal Terpilih Libur atau Izin)
                          Builder(
                            builder: (context) {
                              final holidayProvider = Provider.of<HolidayProvider>(
                                context,
                                listen: false,
                              );
                              final holiday = holidayProvider.getHolidayForDate(_selectedDay);
                              final isSunday = _selectedDay.weekday == DateTime.sunday;
                              final absenceJournal = _selectedTeacherId != null
                                  ? schoolJournals.cast<JournalModel?>().firstWhere(
                                      (j) =>
                                          j != null &&
                                          j.teacherId == _selectedTeacherId &&
                                          j.date.year == _selectedDay.year &&
                                          j.date.month == _selectedDay.month &&
                                          j.date.day == _selectedDay.day &&
                                          j.isTeacherAbsence &&
                                          j.status != 'rejected',
                                      orElse: () => null,
                                    )
                                  : null;

                              if (holiday != null) {
                                return Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: 14.h),
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.08),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6.w),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.event_busy_rounded,
                                          size: 14.r,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Hari Libur: ${holiday.title}',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? const Color(0xFFFCA5A5)
                                                    : const Color(0xFFB91C1C),
                                              ),
                                            ),
                                            if (holiday.description != null &&
                                                holiday.description!.isNotEmpty &&
                                                holiday.description != holiday.title)
                                              Text(
                                                holiday.description!,
                                                style: TextStyle(
                                                  fontSize: 11.5.sp,
                                                  color: isDark
                                                      ? const Color(0xFFFCA5A5)
                                                      : const Color(0xFFB91C1C),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (absenceJournal != null) {
                                return Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: 14.h),
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.08),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(6.w),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.person_off_rounded,
                                          size: 14.r,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Izin / Cuti',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? const Color(0xFFFCA5A5)
                                                    : const Color(0xFFB91C1C),
                                              ),
                                            ),
                                            if (absenceJournal.note != null &&
                                                absenceJournal.note!.isNotEmpty)
                                              Text(
                                                absenceJournal.note!,
                                                style: TextStyle(
                                                  fontSize: 11.5.sp,
                                                  color: isDark
                                                      ? const Color(0xFFFCA5A5)
                                                      : const Color(0xFFB91C1C),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else if (isSunday) {
                                return Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: 14.h),
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.15 : 0.06),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.weekend_rounded,
                                        size: 18.r,
                                        color: const Color(0xFFEF4444),
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        'Hari Minggu',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFFFCA5A5)
                                              : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          // 5. Agenda & Jadwal Kelas Hari Ini
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Agenda Mengajar',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                    child: Text(
                                      '${groupedSchedulesForDay.length} Kelas',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (groupedSchedulesForDay.isNotEmpty)
                                TextButton(
                                  onPressed: () => context.push(
                                    '/admin/schedules?${_statQuery()}',
                                  ),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Lihat Jadwal',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                      SizedBox(width: 2.w),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 16.r,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 10.h),

                          if (groupedSchedulesForDay.isEmpty)
                            _buildEmptyAgenda(context, isDark, schoolJournals)
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: groupedSchedulesForDay.length,
                              separatorBuilder: (_, index) => SizedBox(height: 10.h),
                              itemBuilder: (context, index) {
                                final group = groupedSchedulesForDay[index];
                                return _buildAgendaCard(
                                  context: context,
                                  group: group,
                                  masterProvider: masterProvider,
                                  journalProvider: journalProvider,
                                  isDark: isDark,
                                );
                              },
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

  Widget _buildEmptyAgenda(
    BuildContext context,
    bool isDark,
    List<JournalModel> journals,
  ) {
    final holidayProvider = Provider.of<HolidayProvider>(context, listen: false);
    final holiday = holidayProvider.getHolidayForDate(_selectedDay);
    final isSunday = _selectedDay.weekday == DateTime.sunday;
    final absenceJournal = _selectedTeacherId != null
        ? journals.cast<JournalModel?>().firstWhere(
            (j) =>
                j != null &&
                j.teacherId == _selectedTeacherId &&
                j.date.year == _selectedDay.year &&
                j.date.month == _selectedDay.month &&
                j.date.day == _selectedDay.day &&
                j.isTeacherAbsence &&
                j.status != 'rejected',
            orElse: () => null,
          )
        : null;

    final String title;
    final String subtitle;
    final IconData icon;

    if (holiday != null) {
      title = 'Hari Libur: ${holiday.title}';
      subtitle = holiday.description != null &&
              holiday.description!.isNotEmpty &&
              holiday.description != holiday.title
          ? holiday.description!
          : 'Sekolah libur, tidak ada kegiatan belajar mengajar.';
      icon = Icons.event_busy_rounded;
    } else if (absenceJournal != null) {
      title = 'Guru Sedang Izin / Cuti';
      subtitle = absenceJournal.note != null && absenceJournal.note!.isNotEmpty
          ? absenceJournal.note!
          : 'Guru berhalangan hadir pada tanggal ini.';
      icon = Icons.person_off_rounded;
    } else if (isSunday) {
      title = 'Hari Minggu (Akhir Pekan)';
      subtitle = 'Tidak ada jadwal kegiatan kelas hari ini.';
      icon = Icons.weekend_rounded;
    } else {
      title = 'Tidak ada jadwal mengajar pada tanggal ini.';
      subtitle = 'Pilih tanggal lain di kalender atau buat jadwal baru.';
      icon = Icons.event_available_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF334155).withValues(alpha: 0.5)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28.r,
              color: (holiday != null || isSunday)
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF94A3B8),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            title,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaCard({
    required BuildContext context,
    required GroupedDailySchedule group,
    required MasterDataProvider masterProvider,
    required JournalProvider journalProvider,
    required bool isDark,
  }) {
    final teacher = masterProvider.teachers
        .where((t) => t.id == group.teacherId)
        .firstOrNull;
    final classModel = masterProvider.classes
        .where((c) => c.id == group.classId)
        .firstOrNull;
    final subject = masterProvider.subjects
        .where((s) => s.id == group.subjectId)
        .firstOrNull;

    final teacherName = teacher?.name ?? 'Guru Tidak Dikenal';
    final className = classModel?.name ?? 'Kelas -';
    final subjectName = subject?.name ?? 'Mata Pelajaran -';

    // Cari jurnal terkait
    final journal = journalProvider.journals.where((j) {
      final sameDate = j.date.year == _selectedDay.year &&
          j.date.month == _selectedDay.month &&
          j.date.day == _selectedDay.day;
      return sameDate &&
          (group.scheduleIds.contains(j.scheduleId) ||
              (j.classId == group.classId &&
                  j.subjectId == group.subjectId &&
                  j.teacherId == group.teacherId));
    }).firstOrNull;

    final bool isVerified = journal != null && journal.status == 'verified';
    final bool isPending = journal != null && journal.status == 'pending';
    final bool isRejected = journal != null && journal.status == 'rejected';
    final bool isAbsence = journal != null && journal.isTeacherAbsence;

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (isVerified) {
      statusColor = const Color(0xFF16A34A);
      statusLabel = 'Diterima';
      statusIcon = Icons.check_circle_rounded;
    } else if (isPending) {
      statusColor = const Color(0xFFD97706);
      statusLabel = 'Pending';
      statusIcon = Icons.pending_rounded;
    } else if (isAbsence) {
      statusColor = const Color(0xFFE11D48);
      statusLabel = 'Izin';
      statusIcon = Icons.event_busy_rounded;
    } else if (isRejected) {
      statusColor = const Color(0xFFE11D48);
      statusLabel = 'Ditolak';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFF64748B);
      statusLabel = 'Belum Diisi';
      statusIcon = Icons.schedule_rounded;
    }

    final hoursText = group.teachingHours.isEmpty
        ? 'Jam -'
        : group.teachingHours.length == 1
            ? 'Jam Ke-${group.teachingHours.first}'
            : 'Jam ${group.teachingHours.first} - ${group.teachingHours.last}';

    return InkWell(
      onTap: () {
        if (journal != null) {
          context.push('/admin/journals?${_statQuery()}');
        } else {
          context.push('/admin/schedules?${_statQuery()}');
        }
      },
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    hoursText,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF334155).withValues(alpha: 0.5)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    className,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12.r, color: statusColor),
                      SizedBox(width: 4.w),
                      Text(
                        statusLabel,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              subjectName,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 14.r,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    teacherName,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statQuery({int? tab}) {
    final params = <String, String>{
      'date': DateFormat('yyyy-MM-dd').format(_selectedDay),
      if (tab != null) 'tab': '$tab',
    };
    final teacherId = _selectedTeacherId;
    if (teacherId != null && teacherId.isNotEmpty) {
      params['teacher'] = teacherId;
    }
    return Uri(queryParameters: params).query;
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

  Widget _buildScheduledDayCell(
    DateTime day,
    bool isSelected,
    bool isToday,
    bool isOutside,
    _AdminCalendarLookup lookup,
  ) {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final hasSchedule = lookup.hasSchedule(key);
    final isAllFilled = hasSchedule && lookup.isAllFilled(key);
    final isHoliday = lookup.isHoliday(key, day);
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
        border = Border.all(color: const Color(0xFFEF4444), width: 2.0);
      } else {
        bgColor = AppTheme.primaryColor;
        textColor = Colors.white;
        fontWeight = FontWeight.w700;
        border = Border.all(color: const Color(0xFF60A5FA), width: 2.0);
      }
    } else if (isHoliday) {
      // Libur / cuti: berwarna merah
      bgColor = const Color(0xFFDC2626).withValues(alpha: isDark ? 0.22 : 0.15);
      textColor = const Color(0xFFEF4444);
      fontWeight = FontWeight.w700;
      border = Border.all(color: const Color(0xFFEF4444), width: 1.5);
    } else if (hasSchedule) {
      if (isAllFilled) {
        // Selesai semua jadwal diisi: berwarna biru
        bgColor = const Color(
          0xFF3B82F6,
        ).withValues(alpha: isDark ? 0.22 : 0.15);
        textColor = isOutside
            ? (isDark ? const Color(0xFF64748B) : AppTheme.outline)
            : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB));
        fontWeight = FontWeight.w700;
        border = Border.all(color: const Color(0xFF3B82F6), width: 1.5);
      } else {
        // Memiliki jadwal tetapi belum semua mengisi jurnal: berwarna amber
        bgColor = const Color(
          0xFFD97706,
        ).withValues(alpha: isDark ? 0.22 : 0.15);
        textColor = isOutside
            ? (isDark ? const Color(0xFF64748B) : AppTheme.outline)
            : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309));
        fontWeight = FontWeight.w700;
        border = Border.all(color: const Color(0xFFD97706), width: 1.5);
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
    _AdminCalendarLookup lookup,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TableCalendar(
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
        onHeaderTapped: (_) => _showFullCalendarDialog(context, lookup),
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
            return _buildScheduledDayCell(
              day,
              false,
              false,
              false,
              lookup,
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(
              day,
              false,
              false,
              true,
              lookup,
            );
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(
              day,
              false,
              true,
              false,
              lookup,
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(
              day,
              true,
              false,
              false,
              lookup,
            );
          },
        ),
      ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
            child: Divider(
              height: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(10.w, 3.h, 10.w, 4.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCalendarLegendDot(const Color(0xFF3B82F6), 'Lengkap', isDark),
                SizedBox(width: 14.w),
                _buildCalendarLegendDot(const Color(0xFFD97706), 'Belum Lengkap', isDark),
                SizedBox(width: 14.w),
                _buildCalendarLegendDot(const Color(0xFFEF4444), 'Libur / Cuti', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullCalendarDialog(
    BuildContext context,
    _AdminCalendarLookup lookup,
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
                            lookup,
                          );
                        },
                        outsideBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            false,
                            false,
                            true,
                            lookup,
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            false,
                            true,
                            false,
                            lookup,
                          );
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            true,
                            false,
                            false,
                            lookup,
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
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCalendarLegendDot(
                          const Color(0xFF3B82F6),
                          'Lengkap',
                          isDark,
                        ),
                        SizedBox(width: 14.w),
                        _buildCalendarLegendDot(
                          const Color(0xFFD97706),
                          'Belum Lengkap',
                          isDark,
                        ),
                        SizedBox(width: 14.w),
                        _buildCalendarLegendDot(
                          const Color(0xFFEF4444),
                          'Libur / Cuti',
                          isDark,
                        ),
                      ],
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

  Widget _buildCalendarLegendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.r,
          height: 7.r,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 5.w),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 10.5.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Helper structure for caching and O(1) day-cell status lookup in Admin Calendar
class _AdminCalendarLookup {
  final Set<String> scheduledDateKeys;
  final Set<String> allFilledDateKeys;
  final Set<String> absenceDateKeys;
  final HolidayProvider holidayProvider;

  const _AdminCalendarLookup({
    required this.scheduledDateKeys,
    required this.allFilledDateKeys,
    required this.absenceDateKeys,
    required this.holidayProvider,
  });

  bool hasSchedule(String dateKey) => scheduledDateKeys.contains(dateKey);
  bool isAllFilled(String dateKey) => allFilledDateKeys.contains(dateKey);
  bool isHoliday(String dateKey, DateTime day) =>
      absenceDateKeys.contains(dateKey) ||
      holidayProvider.getHolidayForDate(day) != null;

  factory _AdminCalendarLookup.build({
    required List<ScheduleModel> schedules,
    required List<JournalModel> journals,
    required String? selectedTeacherId,
    required String? cleanActiveSchoolId,
    required HolidayProvider holidayProvider,
  }) {
    final Map<String, List<ScheduleModel>> schedulesByDate = {};
    for (final s in schedules) {
      if (!s.isActive) continue;
      if (selectedTeacherId != null && s.teacherId != selectedTeacherId) continue;
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final sSchoolId =
            AppHelper.parseSingleCleanSchoolId(s.schoolId) ??
            s.schoolId?.trim();
        if (sSchoolId != null &&
            sSchoolId.isNotEmpty &&
            sSchoolId != cleanActiveSchoolId) {
          continue;
        }
      }
      final key =
          '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      (schedulesByDate[key] ??= []).add(s);
    }

    final Map<String, List<JournalModel>> journalsByDate = {};
    final Set<String> absenceDateKeys = {};
    for (final j in journals) {
      final key =
          '${j.date.year}-${j.date.month.toString().padLeft(2, '0')}-${j.date.day.toString().padLeft(2, '0')}';
      (journalsByDate[key] ??= []).add(j);
      if (selectedTeacherId != null &&
          j.teacherId == selectedTeacherId &&
          j.isTeacherAbsence &&
          j.status != 'rejected') {
        absenceDateKeys.add(key);
      }
    }

    final Set<String> scheduledDateKeys = schedulesByDate.keys.toSet();
    final Set<String> allFilledDateKeys = {};

    for (final entry in schedulesByDate.entries) {
      final key = entry.key;
      final daySchedules = entry.value;
      if (daySchedules.isEmpty) continue;

      final grouped = groupDailySchedules(daySchedules);
      if (grouped.isEmpty) continue;

      final dayJournals = journalsByDate[key] ?? const [];
      final isAllFilled = grouped.every((group) {
        final s = group.primarySchedule;
        return dayJournals.any((j) {
          final sameSchedule =
              j.scheduleId == s.id ||
              group.scheduleIds.contains(j.scheduleId) ||
              (j.classId == s.classId &&
                  j.subjectId == s.subjectId &&
                  j.teacherId == s.teacherId);
          return sameSchedule &&
              j.status != 'rejected' &&
              (j.status == 'pending' ||
                  j.status == 'verified' ||
                  j.isTeacherAbsence);
        });
      });

      if (isAllFilled) {
        allFilledDateKeys.add(key);
      }
    }

    return _AdminCalendarLookup(
      scheduledDateKeys: scheduledDateKeys,
      allFilledDateKeys: allFilledDateKeys,
      absenceDateKeys: absenceDateKeys,
      holidayProvider: holidayProvider,
    );
  }
}
