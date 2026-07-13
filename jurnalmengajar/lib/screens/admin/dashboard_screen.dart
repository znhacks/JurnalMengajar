import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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
import '../../providers/settings_provider.dart';
import '../../providers/warning_letter_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedTeacherId = widget.selectedTeacherId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
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

    await Future.wait([
      masterProvider.loadAllData(),
      scheduleProvider.loadAllSchedules(),
      journalProvider.loadAllJournals(),
    ]);

    // Run Warning Letters Check & Issue if late
    if (mounted) {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      await settingsProvider.loadSettings();
      if (!mounted) return;
      final maxDays = settingsProvider.settings?.maxJournalInputDays ?? 3;

      final warningProvider = Provider.of<WarningLetterProvider>(
        context,
        listen: false,
      );
      await warningProvider.checkAndIssueWarnings(
        schedules: scheduleProvider.schedules,
        journals: journalProvider.journals,
        maxDays: maxDays,
        masterProvider: masterProvider,
      );
      await warningProvider.loadAllWarningLetters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final filteredJournals = _selectedTeacherId == null
        ? journalProvider.journals
        : journalProvider.journals.where((j) {
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
            return sched.teacherId == _selectedTeacherId;
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

    final weekSchedules = scheduleProvider.schedules.where((s) {
      if (_selectedTeacherId != null && s.teacherId != _selectedTeacherId) {
        return false;
      }
      final sDate = DateTime.utc(s.date.year, s.date.month, s.date.day);
      return !sDate.isBefore(startOfWeek) && !sDate.isAfter(endOfWeek);
    }).toList();
    final totalSchedulesInWeek = groupDailySchedules(weekSchedules).length;

    final hasHighlightBefore = scheduleProvider.schedules.any((s) {
      if (!s.isActive) return false;
      if (_selectedTeacherId != null && s.teacherId != _selectedTeacherId) return false;
      final sDate = DateTime.utc(s.date.year, s.date.month, s.date.day);
      return sDate.isBefore(startOfWeek);
    });

    final hasHighlightAfter = scheduleProvider.schedules.any((s) {
      if (!s.isActive) return false;
      if (_selectedTeacherId != null && s.teacherId != _selectedTeacherId) return false;
      final sDate = DateTime.utc(s.date.year, s.date.month, s.date.day);
      return sDate.isAfter(endOfWeek);
    });

    // Calculate unsubmitted schedules for selected day using UTC calendar date comparison to avoid timezone shifts
    final schedulesForDay = scheduleProvider.schedules.where((s) {
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
      final hasJournal = journalProvider.journals.any(
        (j) => group.scheduleIds.contains(j.scheduleId),
      );
      return !hasJournal;
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/dashboard'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: AppTheme.primaryColor,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'Total Jadwal',
                                '$totalSchedulesInWeek',
                                Icons.calendar_month_outlined,
                                const Color(0xFF565E74),
                                subtitle: 'Minggu ini',
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: _buildStatCard(
                                'Total Jurnal',
                                '$totalJournals',
                                Icons.assignment_outlined,
                                AppTheme.primaryColor,
                                onTap: () => context.push('/admin/journals'),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: _buildStatCard(
                                'Approval',
                                '$totalPending',
                                Icons.rate_review_outlined,
                                const Color(0xFF825100),
                                onTap: () => context.push('/admin/journals?tab=1'),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: _buildStatCard(
                                'Blm Input',
                                '$unsubmittedCount',
                                Icons.pending_actions_outlined,
                                const Color(0xFFBA1A1A),
                                subtitle: 'Hari ini',
                                onTap: () => context.push('/admin/journals?tab=1'),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),

                        // ── Teacher Selector + Calendar ─────────────────────────────
                        _buildTeacherSelectorCompact(masterProvider.teachers),
                        SizedBox(height: 12.h),

                        // ── Calendar Card ──────────────────────────────────────────
                        _buildCalendarCard(
                          scheduleProvider.schedules,
                          hasHighlightBefore,
                          hasHighlightAfter,
                        ),
                        SizedBox(height: 12.h),

                        // ── Jadwal hari ini ────────────────────────────────────────
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
        fontWeight: FontWeight.w700,
        color: AppTheme.onBackground,
      ),
    );
  }

  // ─── Stat Card ─────────────────────────────────────────────────────────────
  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
    Color color, {
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onTap != null
                  ? color.withValues(alpha: 0.4)
                  : AppTheme.outlineVariant,
              width: onTap != null ? 1.2 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 12.w),
                  ),
                  if (subtitle != null)
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          subtitle,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 7.sp,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  count,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onBackground,
                  ),
                ),
              ),
              SizedBox(height: 2.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 9.sp,
                    color: AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null) ...[SizedBox(height: 2.h), Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 8.sp, color: color),
                ],
              )],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Calendar Card ─────────────────────────────────────────────────────────

  bool _hasTeacherScheduleOnDay(List<ScheduleModel> schedules, DateTime day) {
    if (_selectedTeacherId == null) {
      return schedules.any(
        (s) =>
            s.isActive &&
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day,
      );
    }
    return schedules.any(
      (s) =>
          s.isActive &&
          s.teacherId == _selectedTeacherId &&
          s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day,
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

    Color bgColor = Colors.transparent;
    Color textColor = isOutside ? AppTheme.outline : AppTheme.onBackground;
    FontWeight fontWeight = FontWeight.w500;

    if (isSelected) {
      bgColor = AppTheme.primaryColor;
      textColor = Colors.white;
      fontWeight = FontWeight.w700;
    } else if (hasSchedule) {
      bgColor = const Color(0xFFFFEB3B).withValues(alpha: 0.35);
      textColor = isOutside ? AppTheme.outline : AppTheme.onBackground;
      fontWeight = FontWeight.w700;
    } else if (isToday) {
      bgColor = AppTheme.primaryColor.withValues(alpha: 0.15);
      textColor = AppTheme.primaryColor;
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
          fontSize: 13.sp,
          fontWeight: fontWeight,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCalendarCard(
    List<ScheduleModel> schedules,
    bool hasHighlightBefore,
    bool hasHighlightAfter,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          _focusedDay = _focusedDay.subtract(
                            const Duration(days: 7),
                          );
                        });
                      },
                    ),
                    if (hasHighlightBefore)
                      Positioned(
                        left: 8.w,
                        top: 8.h,
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _focusedDay,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppTheme.primaryColor,
                              onPrimary: Colors.white,
                              onSurface: AppTheme.onBackground,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _focusedDay = picked;
                        _selectedDay = picked;
                      });
                    }
                  },
                  icon: const Icon(
                    Icons.calendar_month,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay),
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onBackground,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      onPressed: () {
                        setState(() {
                          _focusedDay = _focusedDay.add(const Duration(days: 7));
                        });
                      },
                    ),
                    if (hasHighlightAfter)
                      Positioned(
                        right: 8.w,
                        top: 8.h,
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          TableCalendar(
            headerVisible: false,
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
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) {
                return _buildScheduledDayCell(
                  day,
                  false,
                  false,
                  false,
                  schedules,
                );
              },
              outsideBuilder: (context, day, focusedDay) {
                return _buildScheduledDayCell(
                  day,
                  false,
                  false,
                  true,
                  schedules,
                );
              },
              todayBuilder: (context, day, focusedDay) {
                return _buildScheduledDayCell(
                  day,
                  false,
                  true,
                  false,
                  schedules,
                );
              },
              selectedBuilder: (context, day, focusedDay) {
                return _buildScheduledDayCell(
                  day,
                  true,
                  false,
                  false,
                  schedules,
                );
              },
            ),

            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: GoogleFonts.hankenGrotesk(
                color: Colors.white,
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
                color: AppTheme.onBackground,
              ),
              outsideTextStyle: GoogleFonts.hankenGrotesk(
                color: AppTheme.outline,
              ),
            ),
          ),
          if (_selectedTeacherId != null)
            Padding(
              padding: EdgeInsets.only(
                left: 16.w,
                right: 16.w,
                bottom: 12.h,
                top: 4.h,
              ),
              child: Row(
                children: [
                  Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEB3B).withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Jadwal guru terpilih',
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

  Widget _buildTeacherSelectorCompact(List<TeacherModel> teachers) {
    return Row(
      children: [
        Icon(
          Icons.person_search_outlined,
          color: AppTheme.primaryColor,
          size: 18.w,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey(_selectedTeacherId),
            initialValue: _selectedTeacherId,
            isExpanded: true,
            hint: Text(
              'Filter guru...',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.sp,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13.sp,
              color: AppTheme.onBackground,
              fontWeight: FontWeight.w600,
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  'Semua Guru',
                  style: GoogleFonts.hankenGrotesk(
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...teachers.map(
                (teacher) => DropdownMenuItem<String>(
                  value: teacher.id,
                  child: Text(teacher.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedTeacherId = value),
          ),
        ),
      ],
    );
  }

  // ─── Schedule Section ──────────────────────────────────────────────────────
  Widget _buildScheduleSection(
    List<dynamic> schedulesForDay,
    MasterDataProvider masterProvider,
    JournalProvider journalProvider,
  ) {
    if (schedulesForDay.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              color: AppTheme.outlineVariant,
              size: 36.w,
            ),
            SizedBox(height: 8.h),
            Text(
              'Tidak ada jadwal untuk hari ini',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final groupedSchedules = groupDailySchedules(
      schedulesForDay.cast<ScheduleModel>(),
    );

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

        final hasJournal = journalProvider.journals.any(
          (j) => scheduleGroup.scheduleIds.contains(j.scheduleId),
        );
        final statusColor = hasJournal
            ? AppTheme.primaryColor
            : const Color(0xFFBA1A1A);
        final hoursStr = scheduleGroup.teachingHours.join(', ');

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (hasJournal) {
                try {
                  final journal = journalProvider.journals.firstWhere(
                    (j) => scheduleGroup.scheduleIds.contains(j.scheduleId),
                  );
                  context.push('/admin/journal/${journal.id}');
                } catch (_) {
                  context.push('/admin/schedule/${sched.id}');
                }
              } else {
                context.push('/admin/schedule/${sched.id}');
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
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
                              backgroundColor: statusColor.withValues(
                                alpha: 0.1,
                              ),
                              child: Icon(
                                hasJournal
                                    ? Icons.check_circle_outline
                                    : Icons.pending_actions,
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
                                      color: AppTheme.onBackground,
                                    ),
                                  ),
                                  SizedBox(height: 3.h),
                                  Text(
                                    'Guru: ${teacher.name}',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      color: AppTheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
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
            ),
          ),
        );
      },
    );
  }
}
