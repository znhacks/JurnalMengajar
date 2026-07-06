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
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
        orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
      );

      if (teacher.id.isNotEmpty) {
        await scheduleProvider.loadTeacherSchedules(teacher.id, _selectedDay);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    final currentUser = authProvider.currentUser;
    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.email.toLowerCase() == (currentUser?.email ?? '').toLowerCase(),
      orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Mengajar'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Calendar widget (weekly/monthly toggle, default weekly for jadwal screen to save space)
            TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 180)),
              lastDay: DateTime.now().add(const Duration(days: 180)),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.week,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
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
                _focusedDay = focusedDay;
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleTextStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              calendarStyle: const CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF0D9488),
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 12.h),

            // Schedules list for selected day
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                color: const Color(0xFF0D9488),
                child: scheduleProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : scheduleProvider.teacherSchedulesForSelectedDate.isEmpty
                        ? _buildEmptyState()
                        : Builder(
                            builder: (context) {
                              final groupedSchedules = groupDailySchedules(scheduleProvider.teacherSchedulesForSelectedDate);
                              return ListView.separated(
                                padding: EdgeInsets.all(16.w),
                                itemCount: groupedSchedules.length,
                                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                                itemBuilder: (context, index) {
                                  final scheduleGroup = groupedSchedules[index];
                                  return _buildScheduleItem(scheduleGroup, masterProvider);
                                },
                              );
                            }
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
              Icon(Icons.calendar_today_outlined, size: 60.w, color: Colors.grey[350]),
              SizedBox(height: 16.h),
              Text(
                'Tidak Ada Jadwal',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey[700]),
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

  Widget _buildScheduleItem(GroupedDailySchedule scheduleGroup, MasterDataProvider master) {
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
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                Text(
                  '$hrStart - $hrEnd',
                  style: TextStyle(fontSize: 11.sp, color: const Color(0xFF0D9488), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            SizedBox(width: 16.w),
            // Divider
            Container(
              height: 50.h,
              width: 1,
              color: Colors.grey[200],
            ),
            SizedBox(width: 16.w),
            // Right block (Class & Mapel details)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cls.name,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subject.name,
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
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
