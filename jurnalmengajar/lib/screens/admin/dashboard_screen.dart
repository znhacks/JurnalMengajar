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
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../models/schedule_model.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../widgets/animated_widgets.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          'Dashboard Admin',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
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
                            scheduleProvider.schedules,
                            hasHighlightBefore,
                            hasHighlightAfter,
                          ),
                        ),
                        SizedBox(height: 14.h),

                        // 2. Teacher Selector Filter
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 100),
                          child: _buildTeacherSelectorCompact(masterProvider.teachers),
                        ),
                        SizedBox(height: 14.h),

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
                                  subtitle: 'Hari ini',
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
                                  subtitle: 'Ketuk Detail',
                                  onTap: () => context.push('/admin/journals'),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _buildStatCard(
                                  'Approval',
                                  '$totalPending',
                                  Icons.rate_review_rounded,
                                  accentColor: const Color(0xFFD97706),
                                  bgColor: const Color(0xFFFEF3C7),
                                  borderColor: const Color(0xFFFDE68A),
                                  subtitle: 'Ketuk Detail',
                                  onTap: () => context.push('/admin/journals?tab=2'),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _buildStatCard(
                                  'Blm Input',
                                  '$unsubmittedCount',
                                  Icons.pending_actions_rounded,
                                  accentColor: const Color(0xFFE11D48),
                                  bgColor: const Color(0xFFFFE4E6),
                                  borderColor: const Color(0xFFFECDD3),
                                  subtitle: 'Hari ini',
                                  onTap: () => context.push('/admin/journals?tab=1'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // 4. Schedule List Section
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
                              SizedBox(height: 10.h),
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
    );
  }

  // ─── Section Title ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 15.sp,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1E293B),
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
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
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
                padding: EdgeInsets.all(7.w),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 16.w),
              ),
              SizedBox(height: 8.h),
              // Count Number
              Text(
                count,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              // Title text
              Text(
                title,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10.5.sp,
                  color: const Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3.h),
              // Subtitle / Indicator
              Text(
                subtitle ?? (onTap != null ? 'Ketuk Detail' : ' '),
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 8.sp,
                  color: onTap != null ? accentColor : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
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
    Color textColor = isOutside ? const Color(0xFFCBD5E1) : const Color(0xFF334155);
    FontWeight fontWeight = FontWeight.w600;

    if (isSelected) {
      bgColor = const Color(0xFF2563EB); // Solid Blue accent from Ref B
      textColor = Colors.white;
      fontWeight = FontWeight.w800;
    } else if (hasSchedule) {
      bgColor = const Color(0xFFEFF6FF);
      textColor = const Color(0xFF1D4ED8);
      fontWeight = FontWeight.w700;
    } else if (isToday) {
      bgColor = const Color(0xFFF1F5F9);
      textColor = const Color(0xFF2563EB);
      fontWeight = FontWeight.w800;
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
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
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _focusedDay = _focusedDay.subtract(
                        const Duration(days: 7),
                      );
                    });
                  },
                ),
                TextButton.icon(
                  onPressed: () => _showFullCalendarDialog(context, schedules),
                  icon: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF2563EB),
                    size: 18,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay),
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF64748B),
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _focusedDay = _focusedDay.add(const Duration(days: 7));
                    });
                  },
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
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              selectedTextStyle: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
              todayDecoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              todayTextStyle: GoogleFonts.hankenGrotesk(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w800,
              ),
              weekendTextStyle: GoogleFonts.hankenGrotesk(
                color: const Color(0xFF64748B),
              ),
              defaultTextStyle: GoogleFonts.hankenGrotesk(
                color: const Color(0xFF334155),
              ),
              outsideTextStyle: GoogleFonts.hankenGrotesk(
                color: const Color(0xFFCBD5E1),
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
                    width: 10.w,
                    height: 10.w,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Jadwal guru terpilih',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showFullCalendarDialog(
    BuildContext context,
    List<ScheduleModel> schedules,
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
                            color: const Color(0xFF0F172A),
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
                    const Divider(color: Color(0xFFE2E8F0)),
                    TableCalendar(
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
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                        selectedTextStyle: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        todayDecoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        todayTextStyle: GoogleFonts.hankenGrotesk(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w800,
                        ),
                        weekendTextStyle: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFF64748B),
                        ),
                        defaultTextStyle: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFF334155),
                        ),
                        outsideTextStyle: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFFCBD5E1),
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
    return Row(
      children: [
        Icon(
          Icons.person_search_rounded,
          color: const Color(0xFF2563EB),
          size: 20.w,
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
                color: const Color(0xFF64748B),
              ),
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(
                  color: Color(0xFF2563EB),
                  width: 1.5,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13.sp,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(
                  'Semua Guru',
                  style: GoogleFonts.hankenGrotesk(
                    color: const Color(0xFF475569),
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
                      color: const Color(0xFF0F172A),
                    ),
                  ),
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
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              color: const Color(0xFF94A3B8),
              size: 38.w,
            ),
            SizedBox(height: 8.h),
            Text(
              'Tidak ada jadwal untuk hari ini',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                color: const Color(0xFF64748B),
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
        final hoursStr = AppHelper.formatTeachingHours(scheduleGroup.teachingHours);

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
            borderRadius: BorderRadius.circular(18.r),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(14.w),
                child: Row(
                  children: [
                    // Clean Teacher Avatar Frame
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22.r,
                        backgroundColor: const Color(0xFFEEF2FF),
                        backgroundImage: teacher.photoUrl != null &&
                                teacher.photoUrl!.startsWith('http')
                            ? NetworkImage(teacher.photoUrl!)
                            : null,
                        child: teacher.photoUrl == null ||
                                !teacher.photoUrl!.startsWith('http')
                            ? Icon(
                                Icons.person_rounded,
                                color: const Color(0xFF4F46E5),
                                size: 22.r,
                              )
                            : null,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${cls.name} • ${subj.name} (Jam $hoursStr)',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            'Guru: ${teacher.name}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Modern Soft Status Icon from Ref B
                    hasJournal
                        ? Container(
                            padding: EdgeInsets.all(2.w),
                            decoration: const BoxDecoration(
                              color: Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18.w,
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.all(6.w),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFE4E6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.access_time_filled_rounded,
                              color: const Color(0xFFE11D48),
                              size: 16.w,
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
