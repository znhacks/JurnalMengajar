import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/schedule_model.dart';
import '../../models/period_model.dart';
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

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
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
        await scheduleProvider.loadTeacherSchedules(teacher.id, _selectedDay);
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
    ScheduleProvider scheduleProvider,
    TeacherModel teacher,
  ) {
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

    final hasHighlightBefore = scheduleProvider.cachedTeacherSchedules.any((s) {
      if (!s.isActive) return false;
      final sDate = DateTime.utc(s.date.year, s.date.month, s.date.day);
      return sDate.isBefore(startOfWeek);
    });

    final hasHighlightAfter = scheduleProvider.cachedTeacherSchedules.any((s) {
      if (!s.isActive) return false;
      final sDate = DateTime.utc(s.date.year, s.date.month, s.date.day);
      return sDate.isAfter(endOfWeek);
    });

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
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
                      if (teacher.id.isNotEmpty) {
                        scheduleProvider.loadTeacherSchedules(teacher.id, picked);
                      }
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

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
      appBar: AppBar(title: const Text('Jadwal Mengajar')),
      body: SafeArea(
        child: Column(
          children: [
            _buildCalendarCard(scheduleProvider, teacher),
            SizedBox(height: 12.h),

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
                          return ListView.separated(
                            padding: EdgeInsets.all(16.w),
                            itemCount: groupedSchedules.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: 12.h),
                            itemBuilder: (context, index) {
                              final scheduleGroup = groupedSchedules[index];
                              return _buildScheduleItem(
                                scheduleGroup,
                                masterProvider,
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

  Widget _buildScheduleItem(
    GroupedDailySchedule scheduleGroup,
    MasterDataProvider master,
  ) {
    final schedule = scheduleGroup.primarySchedule;
    final cls = master.classes.firstWhere(
      (c) => c.id == schedule.classId,
      orElse: () =>
          ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );

    final subject = master.subjects.firstWhere(
      (s) => s.id == schedule.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final matchedHours =
        master.hours
            .where((h) => scheduleGroup.teachingHours.contains(h.teachingHour))
            .toList()
          ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

    final hrStart = matchedHours.isNotEmpty
        ? matchedHours.first.startTime
        : '00:00';
    final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '00:00';
    final hoursStr = scheduleGroup.teachingHours.join(', ');

    final period = master.periods.firstWhere(
      (p) => p.id == schedule.periodId,
      orElse: () => PeriodModel(id: '', name: 'Periode--', isActive: false),
    );

    return InkWell(
      onTap: () => context.push('/guru/schedule/${schedule.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            // Left block (Hour Info)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jam Ke',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                ),
                Text(
                  hoursStr,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '$hrStart - $hrEnd',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: const Color(0xFF2563EB),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(width: 16.w),
            // Divider
            Container(height: 50.h, width: 1, color: Colors.grey[200]),
            SizedBox(width: 16.w),
            // Right block (Class & Mapel details)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cls.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subject.name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Periode: ${period.name}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
