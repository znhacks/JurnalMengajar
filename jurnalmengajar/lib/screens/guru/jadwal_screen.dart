import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../models/journal_model.dart';
import '../../models/teacher_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';
import '../../models/schedule_model.dart';
import '../../core/utils/schedule_grouper.dart';

class GuruJadwalScreen extends StatefulWidget {
  const GuruJadwalScreen({super.key});

  @override
  State<GuruJadwalScreen> createState() => _GuruJadwalScreenState();
}

class _GuruJadwalScreenState extends State<GuruJadwalScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? _lastLoadedSchoolId;
  String? _lastLoadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final currentSchoolId = authProvider.activeSchoolId;
    final currentUserId = authProvider.currentUser?.id;

    if ((_lastLoadedSchoolId != null && _lastLoadedSchoolId != currentSchoolId) ||
        (_lastLoadedUserId != null && _lastLoadedUserId != currentUserId)) {
      _lastLoadedSchoolId = currentSchoolId;
      _lastLoadedUserId = currentUserId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    } else {
      _lastLoadedSchoolId = currentSchoolId;
      _lastLoadedUserId = currentUserId;
    }
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
    final holidayProvider = Provider.of<HolidayProvider>(
      context,
      listen: false,
    );

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      final schoolId = authProvider.activeSchoolId;
      await masterProvider.loadAllData(schoolId);

      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
        orElse: () => TeacherModel(
          id: '',
          name: '',
          position: '',
          address: '',
          phoneNumber: '',
          email: '',
        ),
      );

      if (teacher.id.isNotEmpty) {
        final targetSchoolId = schoolId ?? 'a1111111-1111-1111-1111-111111111111';
        await Future.wait([
          scheduleProvider.loadTeacherSchedules(teacher.id, _selectedDay),
          journalProvider.loadTeacherJournals(teacher.id),
          holidayProvider.loadHolidays(targetSchoolId),
        ]);
      } else {
        scheduleProvider.clearTeacherSchedulesCache();
        journalProvider.clearTeacherJournalsCache();
      }
    }
  }

  bool _hasTeacherScheduleOnDay(List<ScheduleModel> schedules, DateTime day) {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final validClassIds = masterProvider.classes.map((c) => c.id).toSet();
    final validSubjectIds = masterProvider.subjects.map((sb) => sb.id).toSet();
    return schedules.any(
      (s) =>
          s.isActive &&
          s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day &&
          validClassIds.contains(s.classId) &&
          validSubjectIds.contains(s.subjectId),
    );
  }

  Widget _buildScheduledDayCell(
    DateTime day,
    bool isSelected,
    bool isToday,
    bool isOutside,
    List<ScheduleModel> schedules,
  ) {
    final hasSchedule = _hasTeacherScheduleOnDay(schedules, day);
    final holidayProvider = Provider.of<HolidayProvider>(context, listen: false);
    final holiday = holidayProvider.getHolidayForDate(day);
    final isHoliday = holiday != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSunday = day.weekday == DateTime.sunday;

    Color bgColor = Colors.transparent;
    Color textColor = isOutside
        ? (isDark ? const Color(0xFF64748B) : AppTheme.outline)
        : (isSunday ? const Color(0xFFEF4444) : Theme.of(context).colorScheme.onSurface);
    FontWeight fontWeight = FontWeight.w500;

    if (isSelected) {
      bgColor = isHoliday ? const Color(0xFFDC2626) : AppTheme.primaryColor;
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
    } else if (isHoliday) {
      bgColor = const Color(0xFFDC2626).withValues(alpha: isDark ? 0.2 : 0.15);
      textColor = const Color(0xFFEF4444);
      fontWeight = FontWeight.w700;
    } else if (hasSchedule) {
      bgColor = const Color(0xFFFFEB3B).withValues(alpha: isDark ? 0.2 : 0.35);
      textColor = isOutside
          ? (isDark ? const Color(0xFF64748B) : AppTheme.outline)
          : (isDark ? const Color(0xFFFDE047) : const Color(0xFFB45309));
      fontWeight = FontWeight.w700;
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
        border: hasSchedule && !isSelected
            ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
            : null,
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
    ScheduleProvider scheduleProvider,
    TeacherModel teacher,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : AppTheme.outlineVariant,
        ),
      ),
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: TableCalendar(
        locale: 'id_ID',
        headerStyle: HeaderStyle(
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
        daysOfWeekHeight: 30.h,
        rowHeight: 46.h,
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
          if (teacher.id.isNotEmpty) {
            scheduleProvider.loadTeacherSchedules(teacher.id, selectedDay);
          }
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        onHeaderTapped: (_) => _showFullCalendarDialog(context, scheduleProvider, teacher),
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
              scheduleProvider.cachedTeacherSchedules,
            );
          },
          outsideBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(
              day,
              false,
              false,
              true,
              scheduleProvider.cachedTeacherSchedules,
            );
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(
              day,
              false,
              true,
              false,
              scheduleProvider.cachedTeacherSchedules,
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildScheduledDayCell(
              day,
              true,
              false,
              false,
              scheduleProvider.cachedTeacherSchedules,
            );
          },
        ),
      ),
    );
  }

  void _showFullCalendarDialog(
    BuildContext context,
    ScheduleProvider scheduleProvider,
    TeacherModel teacher,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        DateTime focused = _focusedDay;
        DateTime selected = _selectedDay;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
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
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const Divider(),
                    TableCalendar(
                      locale: 'id_ID',
                      daysOfWeekHeight: 30.h,
                      rowHeight: 44.h,
                      firstDay: DateTime.now().subtract(const Duration(days: 365)),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: focused,
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
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
                        if (teacher.id.isNotEmpty) {
                          scheduleProvider.loadTeacherSchedules(teacher.id, selDay);
                        }
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
                            scheduleProvider.cachedTeacherSchedules,
                          );
                        },
                        outsideBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            false,
                            false,
                            true,
                            scheduleProvider.cachedTeacherSchedules,
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            false,
                            true,
                            false,
                            scheduleProvider.cachedTeacherSchedules,
                          );
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return _buildScheduledDayCell(
                            day,
                            true,
                            false,
                            false,
                            scheduleProvider.cachedTeacherSchedules,
                          );
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: GoogleFonts.hankenGrotesk(
                          color: Theme.of(context).colorScheme.surface,
                          fontWeight: FontWeight.w700,
                        ),
                        todayDecoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: GoogleFonts.hankenGrotesk(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                        weekendTextStyle: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFF825100),
                        ),
                        defaultTextStyle: GoogleFonts.hankenGrotesk(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        outsideTextStyle: GoogleFonts.hankenGrotesk(
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final currentUser = authProvider.currentUser;
    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.email.toLowerCase() == (currentUser?.email ?? '').toLowerCase(),
      orElse: () => TeacherModel(
        id: '',
        name: '',
        position: '',
        address: '',
        phoneNumber: '',
        email: '',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () {
              final rootScaffold = ctx.findRootAncestorStateOfType<ScaffoldState>();
              if (rootScaffold != null && rootScaffold.hasDrawer) {
                rootScaffold.openDrawer();
              } else {
                Scaffold.maybeOf(ctx)?.openDrawer();
              }
            },
          ),
        ),
        title: const Text('Jadwal Mengajar'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCalendarCard(scheduleProvider, teacher),
            SizedBox(height: 8.h),

            // Holiday Banner on Schedule Screen
            Builder(
              builder: (context) {
                final holidayProvider = context.watch<HolidayProvider>();
                final holiday = holidayProvider.getHolidayForDate(_selectedDay);
                if (holiday == null) return const SizedBox.shrink();

                return Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
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
                          color: Theme.of(context).colorScheme.surface,
                          size: 20,
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
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              holiday.description != null && holiday.description!.isNotEmpty
                                  ? holiday.description!
                                  : 'KBM ditiadakan. Kegiatan mengajar tidak perlu diisi.',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Schedules list for selected day
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF2563EB),
                child: Builder(
                  builder: (context) {
                    if (scheduleProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final validClassIds = masterProvider.classes.map((c) => c.id).toSet();
                    final validSubjectIds = masterProvider.subjects.map((sb) => sb.id).toSet();
                    final filteredSchedules = scheduleProvider.teacherSchedulesForSelectedDate.where((s) {
                      return validClassIds.contains(s.classId) && validSubjectIds.contains(s.subjectId);
                    }).toList();

                    if (filteredSchedules.isEmpty) {
                      return _buildEmptyState();
                    }

                    final groupedSchedules = groupDailySchedules(filteredSchedules);

                    // Find index of the first schedule item without a completed/pending journal
                    int activeHighlightIndex = -1;
                    for (int i = 0; i < groupedSchedules.length; i++) {
                      final group = groupedSchedules[i];
                      final s = group.primarySchedule;
                      final hasJournal = journalProvider.teacherJournals.any((j) {
                        final sameDate = j.date.year == _selectedDay.year &&
                            j.date.month == _selectedDay.month &&
                            j.date.day == _selectedDay.day;
                        final sameSchedule = j.scheduleId == s.id ||
                            group.scheduleIds.contains(j.scheduleId) ||
                            (j.classId == s.classId && j.subjectId == s.subjectId);
                        return sameDate &&
                            sameSchedule &&
                            (j.status == 'pending' || j.status == 'verified');
                      });
                      if (!hasJournal) {
                        activeHighlightIndex = i;
                        break;
                      }
                    }
                    if (activeHighlightIndex == -1 && groupedSchedules.isNotEmpty) {
                      activeHighlightIndex = groupedSchedules.length - 1;
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      itemCount: groupedSchedules.length,
                      itemBuilder: (context, index) {
                        final scheduleGroup = groupedSchedules[index];
                        final isLast = index == groupedSchedules.length - 1;
                        final isHighlighted = index == activeHighlightIndex;
                        return _buildTimelineScheduleItem(
                          scheduleGroup,
                          masterProvider,
                          journalProvider,
                          index,
                          isLast,
                          isHighlighted,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 60.w,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              SizedBox(height: 16.h),
              Text(
                'Tidak Ada Jadwal',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Hari ini tidak ada kegiatan mengajar yang terjadwal.',
                style: TextStyle(fontSize: 13.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineScheduleItem(
    GroupedDailySchedule scheduleGroup,
    MasterDataProvider master,
    JournalProvider journalProvider,
    int index,
    bool isLast,
    bool isHighlighted,
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

    final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '';
    final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '';
    final hoursStr = AppHelper.formatTeachingHours(scheduleGroup.teachingHours);
    final timeRange = hrStart.isNotEmpty ? (hrEnd.isNotEmpty ? '$hrStart - $hrEnd WIB' : '$hrStart WIB') : '';

    // Find matching journal for this schedule group on the selected day
    JournalModel? matchingJournal;
    for (final j in journalProvider.teacherJournals) {
      final sameDate = j.date.year == _selectedDay.year &&
                      j.date.month == _selectedDay.month &&
                      j.date.day == _selectedDay.day;
      if (sameDate && (j.scheduleId == schedule.id || scheduleGroup.scheduleIds.contains(j.scheduleId) || (j.classId == schedule.classId && j.subjectId == schedule.subjectId))) {
        matchingJournal = j;
        break;
      }
    }

    final String? journalStatus = matchingJournal?.status;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color cardBg = isDark
        ? (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface)
        : Colors.white;

    final Color textColor = Theme.of(context).colorScheme.onSurface;
    final Color subtextColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final Color borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    Color nodeColor;
    IconData? nodeIcon;
    String statusBadgeText = 'Belum Diisi';
    Color statusBadgeBg = isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9);
    Color statusBadgeTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (journalStatus == 'verified') {
      nodeColor = const Color(0xFF10B981); // Green for ACC
      nodeIcon = Icons.check;
      statusBadgeText = 'Disetujui';
      statusBadgeBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12);
      statusBadgeTextColor = const Color(0xFF10B981);
    } else if (journalStatus == 'pending') {
      nodeColor = const Color(0xFFF59E0B); // Amber for Pending
      nodeIcon = Icons.access_time_rounded;
      statusBadgeText = 'Menunggu ACC';
      statusBadgeBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12);
      statusBadgeTextColor = const Color(0xFFF59E0B);
    } else if (journalStatus == 'rejected') {
      nodeColor = const Color(0xFFEF4444); // Red for Rejected
      nodeIcon = Icons.priority_high_rounded;
      statusBadgeText = 'Ditolak';
      statusBadgeBg = Colors.red.withValues(alpha: isDark ? 0.2 : 0.12);
      statusBadgeTextColor = Colors.red;
    } else {
      nodeColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      nodeIcon = null;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Timeline Column (Node Circle + Connecting Line)
          SizedBox(
            width: 28.w,
            child: Column(
              children: [
                SizedBox(height: 14.h),
                // Node circle
                Container(
                  width: 16.w,
                  height: 16.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nodeColor,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: nodeColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: nodeIcon != null
                      ? Icon(nodeIcon, size: 9.r, color: Colors.white)
                      : null,
                ),
                // Connecting line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8.w),

          // Right Content Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: InkWell(
                onTap: () {
                  if (matchingJournal != null) {
                    if (matchingJournal.status == 'rejected') {
                      context.push('/guru/journal-form?scheduleId=${schedule.id}&journalId=${matchingJournal.id}&date=${DateFormat('yyyy-MM-dd').format(_selectedDay)}');
                    } else {
                      context.push('/guru/journal/${matchingJournal.id}');
                    }
                  } else {
                    context.push('/guru/journal-form?scheduleId=${schedule.id}&date=${DateFormat('yyyy-MM-dd').format(_selectedDay)}');
                  }
                },
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: borderColor,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Subject & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              subject.name,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                            decoration: BoxDecoration(
                              color: statusBadgeBg,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              statusBadgeText,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w700,
                                color: statusBadgeTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Kelas ${cls.name} • Jam ke-$hoursStr${timeRange.isNotEmpty ? ' ($timeRange)' : ''}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.sp,
                          color: subtextColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        matchingJournal != null
                            ? 'Jurnal: ${matchingJournal.material}'
                            : 'Jurnal belum diisi. Ketuk untuk menginput jurnal.',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5.sp,
                          color: subtextColor,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
