import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
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

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      if (masterProvider.teachers.isEmpty) {
        await masterProvider.loadAllData();
      }
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
        await Future.wait([
          scheduleProvider.loadTeacherSchedules(teacher.id, _selectedDay),
          journalProvider.loadTeacherJournals(teacher.id),
        ]);
      }
    }
  }

  bool _hasTeacherScheduleOnDay(List<ScheduleModel> schedules, DateTime day) {
    return schedules.any(
      (s) =>
          s.isActive &&
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
      bgColor = const Color(0xFF2563EB); // Solid Blue accent
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
    ScheduleProvider scheduleProvider,
    TeacherModel teacher,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                  onPressed: () => _showFullCalendarDialog(context, scheduleProvider, teacher),
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
              if (teacher.id.isNotEmpty) {
                scheduleProvider.loadTeacherSchedules(teacher.id, selectedDay);
              }
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
          // ── Legend ────────────────────────────────────────────────────────
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
                  'Ada jadwal mengajar',
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
                            color: const Color(0xFF0F172A),
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
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: ElevatedButton.icon(
              onPressed: () {
                context.push('/guru/journal-form?date=${DateFormat('yyyy-MM-dd').format(_selectedDay)}');
              },
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: Text(
                'Tambah Task',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildCalendarCard(scheduleProvider, teacher),
            SizedBox(height: 8.h),

            // Schedules list for selected day
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF2563EB),
                child: scheduleProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : scheduleProvider.teacherSchedulesForSelectedDate.isEmpty
                    ? _buildEmptyState()
                    : Builder(
                        builder: (context) {
                          final groupedSchedules = groupDailySchedules(
                            scheduleProvider.teacherSchedulesForSelectedDate,
                          );

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
                color: Colors.grey[350],
              ),
              SizedBox(height: 16.h),
              Text(
                'Tidak Ada Jadwal',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Hari ini tidak ada kegiatan mengajar yang terjadwal.',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
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

    final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '00:00';
    final hoursStr = AppHelper.formatTeachingHours(scheduleGroup.teachingHours);
    final timeDisplay = matchedHours.isNotEmpty ? '$hrStart WIB' : 'Jam #$hoursStr';

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
    final bool isFilled = journalStatus != null;

    // Color themes for soft non-highlighted items
    final List<Map<String, dynamic>> softThemes = [
      {
        'bg': const Color(0xFFEEF2FF), // Soft Blue/Indigo
        'text': const Color(0xFF1E293B),
        'subtext': const Color(0xFF64748B),
        'node': const Color(0xFF6366F1),
      },
      {
        'bg': const Color(0xFFFEFCE8), // Soft Yellow
        'text': const Color(0xFF1E293B),
        'subtext': const Color(0xFF78350F),
        'node': const Color(0xFFF59E0B),
      },
      {
        'bg': const Color(0xFFECFDF5), // Soft Mint
        'text': const Color(0xFF1E293B),
        'subtext': const Color(0xFF047857),
        'node': const Color(0xFF10B981),
      },
      {
        'bg': const Color(0xFFFFF1F2), // Soft Coral
        'text': const Color(0xFF1E293B),
        'subtext': const Color(0xFFBE123C),
        'node': const Color(0xFFF43F5E),
      },
    ];

    final theme = softThemes[index % softThemes.length];

    // Colors when highlighted
    final Color cardBg = isHighlighted
        ? const Color(0xFFF43F5E) // Vibrant Red/Pink for highlighted card
        : (isFilled ? const Color(0xFFF8FAFC) : (theme['bg'] as Color));

    final Color textColor = isHighlighted
        ? Colors.white
        : (theme['text'] as Color);

    final Color subtextColor = isHighlighted
        ? Colors.white.withValues(alpha: 0.9)
        : (theme['subtext'] as Color);

    Color nodeColor;
    IconData? nodeIcon;
    if (isHighlighted) {
      nodeColor = const Color(0xFFF43F5E);
    } else if (journalStatus == 'verified') {
      nodeColor = const Color(0xFF10B981); // Green for ACC
      nodeIcon = Icons.check;
    } else if (journalStatus == 'pending') {
      nodeColor = const Color(0xFFF59E0B); // Amber for Pending (Clock icon)
      nodeIcon = Icons.access_time_rounded;
    } else if (journalStatus == 'rejected') {
      nodeColor = const Color(0xFFEF4444); // Red for Rejected
      nodeIcon = Icons.priority_high_rounded;
    } else {
      nodeColor = Colors.white; // Default unfilled
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
                  width: isHighlighted ? 20.w : 16.w,
                  height: isHighlighted ? 20.w : 16.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: nodeColor,
                    border: Border.all(
                      color: isHighlighted
                          ? Colors.white
                          : (journalStatus != null ? nodeColor : (theme['node'] as Color)),
                      width: isHighlighted ? 3.5 : 2.5,
                    ),
                    boxShadow: isHighlighted
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF43F5E).withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: isHighlighted
                      ? Center(
                          child: Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : (nodeIcon != null
                          ? Icon(nodeIcon, size: 10.r, color: Colors.white)
                          : null),
                ),
                // Connecting line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      margin: EdgeInsets.symmetric(vertical: 4.h),
                      color: const Color(0xFFFDA4AF).withValues(alpha: 0.6),
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
                borderRadius: BorderRadius.circular(20.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: isHighlighted
                            ? const Color(0xFFF43F5E).withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.03),
                        blurRadius: isHighlighted ? 12 : 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: isHighlighted
                        ? null
                        : Border.all(
                            color: isFilled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Subject & Time
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
                          Text(
                            timeDisplay,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: subtextColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        'Kelas ${cls.name} • Jam ke-$hoursStr\n${matchingJournal != null ? 'Jurnal: ${matchingJournal.material}' : 'Jurnal belum diisi. Ketuk untuk menginput jurnal.'}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.sp,
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
