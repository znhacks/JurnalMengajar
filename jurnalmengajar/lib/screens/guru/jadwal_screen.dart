import 'package:cr_calendar/cr_calendar.dart';
// ignore: implementation_imports
import 'package:cr_calendar/src/cr_date_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../models/class_model.dart';
import '../../models/holiday_model.dart';
import '../../models/journal_model.dart';
import '../../models/schedule_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';

class GuruJadwalScreen extends StatefulWidget {
  const GuruJadwalScreen({super.key});

  @override
  State<GuruJadwalScreen> createState() => _GuruJadwalScreenState();
}

class _GuruJadwalScreenState extends State<GuruJadwalScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  String? _lastLoadedSchoolId;
  String? _lastLoadedUserId;

  late CrCalendarController _calendarController;
  final List<CalendarEventModel> _calendarEvents = [];

  // Theme colors for event bars:
  // 1. Belum diisi (unfilled, date <= today) -> Merah Pastel
  static const Color _colorPastelRed = Color(0xFFF87171); // Soft pastel red (Tailwind Red 400)
  // 2. Sudah diisi (filled) -> Hijau
  static const Color _colorFilledGreen = Color(0xFF10B981); // Emerald green
  // 3. Holiday -> Red
  static const Color _colorHolidayRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
    _calendarController = CrCalendarController(
      events: _calendarEvents,
      onSwipe: (year, month) {
        if (!mounted) return;
        final newMonth = DateTime(year, month, 1);
        if (newMonth.year != _focusedMonth.year || newMonth.month != _focusedMonth.month) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
          final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
          final teacher = masterProvider.teachers.firstWhere(
            (t) => t.email.toLowerCase() == (authProvider.currentUser?.email ?? '').toLowerCase(),
            orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
          );
          setState(() {
            _focusedMonth = newMonth;
            _selectedDay = newMonth;
          });
          if (teacher.id.isNotEmpty) {
            scheduleProvider.loadTeacherSchedules(teacher.id, newMonth);
          }
        }
      },
    );
    _calendarController.selectedDate = _selectedDay;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentSchoolId = authProvider.activeSchoolId;
      if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
        _lastLoadedSchoolId = currentSchoolId;
        _lastLoadedUserId = authProvider.currentUser?.id;
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
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
            _loadData();
          }
        });
      }
    }
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = authProvider.activeSchoolId;
    if (schoolId == null || schoolId.isEmpty) return;
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
        final targetSchoolId = schoolId;
        scheduleProvider.setSchoolId(schoolId);
        journalProvider.setSchoolId(schoolId);
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasTeacherAbsenceOnDay(List<JournalModel> journals, DateTime day) {
    return journals.any((j) {
      return j.date.year == day.year &&
          j.date.month == day.month &&
          j.date.day == day.day &&
          j.isTeacherAbsence &&
          j.status != 'rejected';
    });
  }

  void _syncEventsList({
    required List<ScheduleModel> schedules,
    required List<JournalModel> journals,
    required List<HolidayModel> holidays,
    required MasterDataProvider master,
    required bool isDark,
  }) {
    _calendarEvents.clear();

    // 1. Add Holidays as event bars
    for (final h in holidays) {
      _calendarEvents.add(
        CalendarEventModel(
          name: 'Libur: ${h.title}',
          begin: DateTime(h.startDate.year, h.startDate.month, h.startDate.day),
          end: DateTime(h.endDate.year, h.endDate.month, h.endDate.day),
          eventColor: _colorHolidayRed,
        ),
      );
    }

    // 2. Add Teaching Schedules (grouped by day, showing count instead of lesson names)
    final activeSchoolId = Provider.of<AuthProvider>(context, listen: false).activeSchoolId;
    final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(activeSchoolId) ?? activeSchoolId?.trim();

    final validSchedules = schedules.where((s) {
      if (!s.isActive) return false;
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
        if (sSchoolId != null && sSchoolId.isNotEmpty && sSchoolId != cleanActiveSchoolId) {
          return false;
        }
      }
      return true;
    }).toList();

    // Group schedules by date
    final Map<DateTime, List<ScheduleModel>> schedulesByDay = {};
    for (final s in validSchedules) {
      final dateKey = DateTime(s.date.year, s.date.month, s.date.day);
      schedulesByDay.putIfAbsent(dateKey, () => []).add(s);
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (final entry in schedulesByDay.entries) {
      final groupDate = entry.key;

      // Skip schedule event if this day is already covered by a holiday
      final isHoliday = holidays.any((h) {
        final s = DateTime(h.startDate.year, h.startDate.month, h.startDate.day);
        final e = DateTime(h.endDate.year, h.endDate.month, h.endDate.day);
        return (groupDate.isAfter(s) || groupDate.isAtSameMomentAs(s)) &&
            (groupDate.isBefore(e) || groupDate.isAtSameMomentAs(e));
      });
      if (isHoliday) continue;

      final daySchedules = entry.value;
      final dayGroups = groupDailySchedules(daySchedules);
      if (dayGroups.isEmpty) continue;

      final isFuture = groupDate.isAfter(todayOnly);

      final bool allFilled = dayGroups.every((g) {
        final primarySched = g.primarySchedule;
        return journals.any((j) {
          final sameDate = j.date.year == g.date.year &&
              j.date.month == g.date.month &&
              j.date.day == g.date.day;
          final sameSchedule = j.scheduleId == primarySched.id ||
              g.scheduleIds.contains(j.scheduleId) ||
              (j.classId == primarySched.classId && j.subjectId == primarySched.subjectId);
          return sameDate && sameSchedule && j.status != 'rejected';
        });
      });

      // Color rules requested by user:
      // - Belum bisa diisi (future): Abu-abu transparan
      // - Sudah diisi: Hijau
      // - Belum diisi: Merah pastel
      final Color barColor;
      if (isFuture) {
        barColor = isDark
            ? const Color(0xFF64748B).withValues(alpha: 0.38)
            : const Color(0xFF94A3B8).withValues(alpha: 0.45);
      } else if (allFilled) {
        barColor = _colorFilledGreen;
      } else {
        barColor = _colorPastelRed;
      }

      // "untuk pelajarannya tidak tampil jadi hanya menampilkan x jadwalnya"
      final label = '${dayGroups.length} Jadwal';

      _calendarEvents.add(
        CalendarEventModel(
          name: label,
          begin: groupDate,
          end: groupDate,
          eventColor: barColor,
        ),
      );
    }
  }

  Widget _buildDayItemCell({
    required DayItemProperties properties,
    required List<ScheduleModel> schedules,
    required List<JournalModel> journals,
    required TeacherModel teacher,
    required ScheduleProvider scheduleProvider,
    required JournalProvider journalProvider,
    required MasterDataProvider masterProvider,
    required HolidayProvider holidayProvider,
  }) {
    final day = properties.date;
    final holiday = holidayProvider.getHolidayForDate(day);
    final isHoliday = holiday != null || _hasTeacherAbsenceOnDay(journals, day);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isSunday = day.weekday == DateTime.sunday;
    final isSelected = properties.isSelected || _isSameDay(_selectedDay, day);

    // Text styling for date without any circular border / container
    Color textColor;
    FontWeight fontWeight;

    if (!properties.isInMonth) {
      textColor = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);
      fontWeight = FontWeight.w500;
    } else if (isHoliday || isSunday) {
      textColor = const Color(0xFFEF4444);
      fontWeight = FontWeight.w700;
    } else if (properties.isCurrentDay) {
      textColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      fontWeight = FontWeight.w800;
    } else if (isSelected) {
      textColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);
      fontWeight = FontWeight.w800;
    } else {
      textColor = isDark ? Colors.white : const Color(0xFF1E293B);
      fontWeight = FontWeight.w600;
    }

    final cellBorderColor = isDark
        ? const Color(0xFF334155).withValues(alpha: 0.35)
        : const Color(0xFFE2E8F0);

    // Selected day cell background tint (no circle)
    final cellBgColor = isSelected
        ? (isDark
            ? const Color(0xFF2563EB).withValues(alpha: 0.12)
            : const Color(0xFF2563EB).withValues(alpha: 0.06))
        : Colors.transparent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _onDayTapped(
          context,
          day,
          teacher,
          scheduleProvider,
          journalProvider,
          masterProvider,
          holidayProvider,
        );
      },
      child: Container(
        alignment: Alignment.topCenter,
        decoration: BoxDecoration(
          color: cellBgColor,
          border: Border.all(color: cellBorderColor, width: 0.5),
        ),
        padding: EdgeInsets.only(top: 3.h),
        child: Text(
          '${properties.dayNumber}',
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11.5.sp,
            fontWeight: fontWeight,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildWeekDayHeader(WeekDay day) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSunday = day == WeekDay.sunday;
    String name;
    switch (day) {
      case WeekDay.monday:
        name = 'Sen';
        break;
      case WeekDay.tuesday:
        name = 'Sel';
        break;
      case WeekDay.wednesday:
        name = 'Rab';
        break;
      case WeekDay.thursday:
        name = 'Kam';
        break;
      case WeekDay.friday:
        name = 'Jum';
        break;
      case WeekDay.saturday:
        name = 'Sab';
        break;
      case WeekDay.sunday:
        name = 'Min';
        break;
    }

    return Container(
      height: 28.h,
      alignment: Alignment.center,
      child: Text(
        name,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          color: isSunday
              ? const Color(0xFFEF4444)
              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
      ),
    );
  }

  Widget _buildEventBar(EventProperties drawer, bool isDark) {
    // Check if event is transparent gray
    final isTransparentGray = drawer.backgroundColor.a < 0.8;
    final textColor = isTransparentGray
        ? (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))
        : Colors.white;

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 16.h,
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.r),
            color: drawer.backgroundColor,
            boxShadow: isTransparentGray
                ? null
                : [
                    BoxShadow(
                      color: drawer.backgroundColor.withValues(alpha: 0.25),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: Text(
            drawer.name,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  void _onDayTapped(
    BuildContext context,
    DateTime day,
    TeacherModel teacher,
    ScheduleProvider scheduleProvider,
    JournalProvider journalProvider,
    MasterDataProvider masterProvider,
    HolidayProvider holidayProvider,
  ) {
    setState(() {
      _selectedDay = day;
      _calendarController.selectedDate = day;
    });

    if (teacher.id.isNotEmpty) {
      final activeSchoolId = Provider.of<AuthProvider>(context, listen: false).activeSchoolId;
      scheduleProvider.setSchoolId(activeSchoolId);
      scheduleProvider.loadTeacherSchedules(teacher.id, day);
    }

    _showDayEventsBottomSheet(
      context,
      day,
      scheduleProvider,
      journalProvider,
      masterProvider,
      holidayProvider,
      teacher,
    );
  }

  void _showDayEventsBottomSheet(
    BuildContext context,
    DateTime day,
    ScheduleProvider scheduleProvider,
    JournalProvider journalProvider,
    MasterDataProvider masterProvider,
    HolidayProvider holidayProvider,
    TeacherModel teacher,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSchoolId = Provider.of<AuthProvider>(context, listen: false).activeSchoolId;
    final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(activeSchoolId) ?? activeSchoolId?.trim();

    final daySchedules = scheduleProvider.cachedTeacherSchedules.where((s) {
      if (!s.isActive) return false;
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
        if (sSchoolId != null && sSchoolId.isNotEmpty && sSchoolId != cleanActiveSchoolId) {
          return false;
        }
      }
      return s.date.year == day.year &&
          s.date.month == day.month &&
          s.date.day == day.day;
    }).toList();

    final groupedSchedules = groupDailySchedules(daySchedules);
    final holiday = holidayProvider.getHolidayForDate(day);
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(day);
    final shortDate = DateFormat('dd/MM/yy').format(day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),

                  // Header Row with Date and Close Button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 16.sp,
                            color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedDate,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$shortDate • ${groupedSchedules.length} Jam Pelajaran',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(bottomSheetContext),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Event List or Empty State
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      children: [
                        // Holiday banner if holiday
                        if (holiday != null) ...[
                          Container(
                            padding: EdgeInsets.all(12.w),
                            margin: EdgeInsets.only(bottom: 12.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.22 : 0.12),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: const Color(0xFFEF4444)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.event_busy_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'HARI LIBUR: ${holiday.title.toUpperCase()}',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFEF4444),
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        holiday.description != null && holiday.description!.isNotEmpty
                                            ? holiday.description!
                                            : 'KBM ditiadakan. Kegiatan mengajar tidak perlu diisi.',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 11.sp,
                                          color: isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Schedule Cards
                        if (groupedSchedules.isEmpty && holiday == null)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 36.h),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_available_outlined,
                                  size: 48.w,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Tidak Ada Jam Pelajaran',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 14.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tidak ada jadwal mengajar pada tanggal ini.',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12.sp,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          for (int i = 0; i < groupedSchedules.length; i++)
                            _buildBottomSheetScheduleCard(
                              bottomSheetContext: bottomSheetContext,
                              scheduleGroup: groupedSchedules[i],
                              day: day,
                              master: masterProvider,
                              journalProvider: journalProvider,
                              isDark: isDark,
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheetScheduleCard({
    required BuildContext bottomSheetContext,
    required GroupedDailySchedule scheduleGroup,
    required DateTime day,
    required MasterDataProvider master,
    required JournalProvider journalProvider,
    required bool isDark,
  }) {
    final schedule = scheduleGroup.primarySchedule;
    final cls = master.classes.firstWhere(
      (c) => c.id == schedule.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas --', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == schedule.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mata Pelajaran', isActive: false),
    );

    final matchedHours = master.hours
        .where((h) => scheduleGroup.teachingHours.contains(h.teachingHour))
        .toList()
      ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

    final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '';
    final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '';
    final hoursStr = AppHelper.formatTeachingHours(scheduleGroup.teachingHours);
    final timeRange = hrStart.isNotEmpty ? (hrEnd.isNotEmpty ? '$hrStart - $hrEnd WIB' : '$hrStart WIB') : '';

    JournalModel? matchingJournal;
    for (final j in journalProvider.teacherJournals) {
      final sameDate = j.date.year == day.year &&
          j.date.month == day.month &&
          j.date.day == day.day;
      if (sameDate &&
          (j.scheduleId == schedule.id ||
              scheduleGroup.scheduleIds.contains(j.scheduleId) ||
              (j.classId == schedule.classId && j.subjectId == schedule.subjectId))) {
        matchingJournal = j;
        break;
      }
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final targetDate = DateTime(day.year, day.month, day.day);
    final isFuture = targetDate.isAfter(todayOnly);
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final bool isFilled = matchingJournal != null && matchingJournal.status != 'rejected';

    // Strip color matching the event bar color rules:
    final Color cardColor;
    if (isFuture) {
      cardColor = const Color(0xFF94A3B8);
    } else if (isFilled) {
      cardColor = _colorFilledGreen;
    } else {
      cardColor = _colorPastelRed;
    }

    String statusText = 'Belum Diisi';
    Color statusBg = isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFF1F5F9);
    Color statusTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    if (matchingJournal != null) {
      if (matchingJournal.isTeacherAbsence) {
        if (matchingJournal.status == 'verified') {
          statusText = matchingJournal.isTeacherSick ? 'Sakit (Disetujui)' : 'Izin (Disetujui)';
          statusBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12);
          statusTextColor = const Color(0xFF10B981);
        } else if (matchingJournal.status == 'rejected') {
          statusText = 'Surat Ditolak';
          statusBg = Colors.red.withValues(alpha: isDark ? 0.22 : 0.12);
          statusTextColor = Colors.red;
        } else {
          statusText = matchingJournal.isTeacherSick ? 'Sakit (Menunggu)' : 'Izin (Menunggu)';
          statusBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12);
          statusTextColor = const Color(0xFFF59E0B);
        }
      } else if (matchingJournal.status == 'verified') {
        statusText = 'Disetujui';
        statusBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12);
        statusTextColor = const Color(0xFF10B981);
      } else if (matchingJournal.status == 'pending') {
        statusText = 'Menunggu ACC';
        statusBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12);
        statusTextColor = const Color(0xFFF59E0B);
      } else if (matchingJournal.status == 'rejected') {
        statusText = 'Perlu Revisi';
        statusBg = Colors.red.withValues(alpha: isDark ? 0.22 : 0.12);
        statusTextColor = Colors.red;
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left color strip matching event bar
            Container(
              width: 6.w,
              color: cardColor,
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row: Subject Name + Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            subject.name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            statusText,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),

                    // Class and Teaching Hour
                    Text(
                      'Kelas ${cls.name} • Jam ke-$hoursStr${timeRange.isNotEmpty ? ' ($timeRange)' : ''}',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),

                    // Material / Hint
                    Text(
                      matchingJournal != null
                          ? 'Jurnal: ${matchingJournal.material}'
                          : (isFuture
                              ? 'Belum bisa mengisi jurnal sampai hari tersebut tiba.'
                              : 'Jurnal belum diisi. Ketuk untuk menginput jurnal.'),
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.5.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 10.h),

                    // Action Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: () async {
                          Navigator.pop(bottomSheetContext);
                          if (matchingJournal != null) {
                            if (matchingJournal.status == 'rejected') {
                              await context.push(
                                '/guru/journal-form?scheduleId=${schedule.id}&journalId=${matchingJournal.id}&date=$dateStr',
                              );
                            } else {
                              await context.push('/guru/journal/${matchingJournal.id}');
                            }
                          } else {
                            if (isFuture) {
                              AppHelper.showSnackBar(
                                context,
                                'Belum bisa mengisi jurnal mengajar, tunggu sampai hari tersebut tiba.',
                                isError: false,
                              );
                              return;
                            }
                            await context.push(
                              '/guru/journal-form?scheduleId=${schedule.id}&date=$dateStr',
                            );
                          }
                          if (mounted) _loadData();
                        },
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: matchingJournal == null
                                ? (isFuture
                                    ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                    : const Color(0xFF2563EB))
                                : (matchingJournal.status == 'rejected'
                                    ? Colors.red.withValues(alpha: isDark ? 0.25 : 0.15)
                                    : const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.15)),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                matchingJournal == null
                                    ? Icons.edit_note_rounded
                                    : (matchingJournal.status == 'rejected'
                                        ? Icons.edit_note_rounded
                                        : Icons.visibility_rounded),
                                size: 14.sp,
                                color: matchingJournal == null
                                    ? (isFuture
                                        ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                        : Colors.white)
                                    : (matchingJournal.status == 'rejected'
                                        ? Colors.red
                                        : const Color(0xFF2563EB)),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                matchingJournal == null
                                    ? 'Isi Jurnal'
                                    : (matchingJournal.status == 'rejected'
                                        ? 'Revisi Jurnal'
                                        : 'Lihat Jurnal'),
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11.5.sp,
                                  fontWeight: FontWeight.w700,
                                  color: matchingJournal == null
                                      ? (isFuture
                                          ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                          : Colors.white)
                                      : (matchingJournal.status == 'rejected'
                                          ? Colors.red
                                          : const Color(0xFF2563EB)),
                                ),
                              ),
                            ],
                          ),
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
  }

  // Jumps to today and reloads today's data
  void _jumpToToday(TeacherModel teacher, ScheduleProvider scheduleProvider) {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDay = now;
    });
    _calendarController.selectedDate = now;
    if (teacher.id.isNotEmpty) {
      scheduleProvider.loadTeacherSchedules(teacher.id, now);
    }
  }

  // Interactive Month & Year Picker Dialog
  Future<void> _showMonthYearPickerDialog(
    BuildContext context,
    TeacherModel teacher,
    ScheduleProvider scheduleProvider,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int tempYear = _focusedMonth.year;
    int tempMonth = _focusedMonth.month;

    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];

    await showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 380,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(18.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Header Row
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          color: const Color(0xFF2563EB),
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Pilih Bulan & Tahun',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Year Selector Row
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: () {
                              setDialogState(() {
                                tempYear--;
                              });
                            },
                          ),
                          Text(
                            '$tempYear',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: () {
                              setDialogState(() {
                                tempYear++;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // 12 Months Grid (4 columns x 3 rows)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8.h,
                        crossAxisSpacing: 8.w,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final mNum = index + 1;
                        final isSelectedMonth = mNum == tempMonth;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              tempMonth = mNum;
                            });
                          },
                          borderRadius: BorderRadius.circular(8.r),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelectedMonth
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: isSelectedMonth
                                    ? const Color(0xFF2563EB)
                                    : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                width: isSelectedMonth ? 1.5 : 1.0,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              monthNames[index],
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12.sp,
                                fontWeight: isSelectedMonth ? FontWeight.w800 : FontWeight.w600,
                                color: isSelectedMonth
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 18.h),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: Size(0, 38.h),
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                          ),
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: Text(
                            'Batal',
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            minimumSize: Size(0, 38.h),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                          ),
                          onPressed: () {
                            Navigator.pop(dialogCtx);
                            final targetDate = DateTime(tempYear, tempMonth, 1);
                            setState(() {
                              _focusedMonth = targetDate;
                              _selectedDay = targetDate;
                            });
                            _calendarController.selectedDate = targetDate;
                            if (teacher.id.isNotEmpty) {
                              scheduleProvider.loadTeacherSchedules(teacher.id, targetDate);
                            }
                          },
                          child: Text(
                            'Terapkan',
                            style: GoogleFonts.hankenGrotesk(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final holidayProvider = context.watch<HolidayProvider>();

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

    // Sync event items into CrCalendar with status colors:
    // Belum diisi -> Merah pastel
    // Sudah diisi -> Hijau
    // Belum bisa diisi (future) -> Abu-abu transparan
    _syncEventsList(
      schedules: scheduleProvider.cachedTeacherSchedules,
      journals: journalProvider.teacherJournals,
      holidays: holidayProvider.holidays,
      master: masterProvider,
      isDark: isDark,
    );

    final monthTitle = DateFormat('MMMM yyyy', 'id_ID').format(_focusedMonth);

    // Count schedules for the currently selected day
    final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(authProvider.activeSchoolId) ??
        authProvider.activeSchoolId?.trim();
    final selectedDaySchedules = scheduleProvider.cachedTeacherSchedules.where((s) {
      if (!s.isActive) return false;
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
        if (sSchoolId != null && sSchoolId.isNotEmpty && sSchoolId != cleanActiveSchoolId) {
          return false;
        }
      }
      return s.date.year == _selectedDay.year &&
          s.date.month == _selectedDay.month &&
          s.date.day == _selectedDay.day;
    }).toList();
    final selectedDayGroups = groupDailySchedules(selectedDaySchedules);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Menu',
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
        title: Text(
          'Jadwal Mengajar',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          // Hari Ini button - jumps to today
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Hari Ini',
            onPressed: () => _jumpToToday(teacher, scheduleProvider),
          ),
          // Pilih Bulan & Tahun button - opens interactive dialog
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Pilih Bulan & Tahun',
            onPressed: () => _showMonthYearPickerDialog(context, teacher, scheduleProvider),
          ),
          SizedBox(width: 4.w),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Calendar Month Navigation Control Row
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Bulan Sebelumnya',
                        onPressed: () {
                          final prevMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                          setState(() {
                            _focusedMonth = prevMonth;
                            _selectedDay = prevMonth;
                          });
                          _calendarController.selectedDate = prevMonth;
                          if (teacher.id.isNotEmpty) {
                            scheduleProvider.loadTeacherSchedules(teacher.id, prevMonth);
                          }
                        },
                      ),
                      InkWell(
                        onTap: () => _showMonthYearPickerDialog(context, teacher, scheduleProvider),
                        borderRadius: BorderRadius.circular(8.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                size: 16.sp,
                                color: const Color(0xFF2563EB),
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                monthTitle,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Bulan Berikutnya',
                        onPressed: () {
                          final nextMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                          setState(() {
                            _focusedMonth = nextMonth;
                            _selectedDay = nextMonth;
                          });
                          _calendarController.selectedDate = nextMonth;
                          if (teacher.id.isNotEmpty) {
                            scheduleProvider.loadTeacherSchedules(teacher.id, nextMonth);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // CrCalendar Month View with Horizontal Event Bars
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 720,
                    maxHeight: 360.h,
                  ),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: DatePickerSettings(
                      landscapeDaysResizeMode: LandscapeDaysResizeMode.adaptive,
                      child: CrCalendar(
                        key: ValueKey<String>('cr_cal_${_focusedMonth.year}_${_focusedMonth.month}'),
                        firstDayOfWeek: WeekDay.monday,
                        // Positioned neatly below centered date number (top 3.h, font 11.5.sp)
                        eventsTopPadding: 21.h,
                        initialDate: _focusedMonth,
                        maxEventLines: 1,
                        controller: _calendarController,
                        forceSixWeek: true,
                        dayItemBuilder: (properties) => _buildDayItemCell(
                          properties: properties,
                          schedules: scheduleProvider.cachedTeacherSchedules,
                          journals: journalProvider.teacherJournals,
                          teacher: teacher,
                          scheduleProvider: scheduleProvider,
                          journalProvider: journalProvider,
                          masterProvider: masterProvider,
                          holidayProvider: holidayProvider,
                        ),
                        weekDaysBuilder: (day) => _buildWeekDayHeader(day),
                        eventBuilder: (drawer) => _buildEventBar(drawer, isDark),
                        onDayClicked: (events, day) => _onDayTapped(
                          context,
                          day,
                          teacher,
                          scheduleProvider,
                          journalProvider,
                          masterProvider,
                          holidayProvider,
                        ),
                        minDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
                        maxDate: DateTime.now().add(const Duration(days: 365 * 2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Selected Day Quick Info Bar
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: InkWell(
                  onTap: () => _showDayEventsBottomSheet(
                    context,
                    _selectedDay,
                    scheduleProvider,
                    journalProvider,
                    masterProvider,
                    holidayProvider,
                    teacher,
                  ),
                  child: Container(
                    margin: EdgeInsets.fromLTRB(14.w, 4.h, 14.w, 10.h),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(7.w),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.view_agenda_outlined,
                        size: 16.sp,
                        color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryColor,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDay),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            selectedDayGroups.isEmpty
                                ? 'Tidak ada jam pelajaran'
                                : '${selectedDayGroups.length} Sesi Mengajar Terjadwal',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: selectedDayGroups.isEmpty
                                  ? Theme.of(context).colorScheme.onSurfaceVariant
                                  : const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Detail',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryColor,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 15.sp,
                            color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryColor,
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
      ],
    ),
  ),
);
  }
}
