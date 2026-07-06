import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/state_widgets.dart';
import '../../core/utils/schedule_grouper.dart';

class JadwalMingguanScreen extends StatefulWidget {
  const JadwalMingguanScreen({super.key});

  @override
  State<JadwalMingguanScreen> createState() => _JadwalMingguanScreenState();
}

class _JadwalMingguanScreenState extends State<JadwalMingguanScreen> {
  String? _selectedPeriodId;
  String? _selectedClassId;
  String? _selectedTeacherId;
  int? _selectedWeekday; // 1 = Senin, 2 = Selasa, ...

  final List<Map<String, dynamic>> _daysOfWeek = [
    {'label': 'Semua Hari', 'value': null},
    {'label': 'Senin', 'value': 1},
    {'label': 'Selasa', 'value': 2},
    {'label': 'Rabu', 'value': 3},
    {'label': 'Kamis', 'value': 4},
    {'label': 'Jumat', 'value': 5},
    {'label': 'Sabtu', 'value': 6},
    {'label': 'Minggu', 'value': 7},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFilters();
    });
  }

  void _initFilters() {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    setState(() {
      _selectedPeriodId = masterProvider.activePeriod?.id ?? (masterProvider.periods.isNotEmpty ? masterProvider.periods.first.id : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    // Apply filters to schedules list
    final filteredSchedules = scheduleProvider.schedules.where((s) {
      bool matchPeriod = _selectedPeriodId == null || s.periodId == _selectedPeriodId;
      bool matchClass = _selectedClassId == null || s.classId == _selectedClassId;
      bool matchTeacher = _selectedTeacherId == null || s.teacherId == _selectedTeacherId;
      bool matchDay = _selectedWeekday == null || s.date.weekday == _selectedWeekday;
      return matchPeriod && matchClass && matchTeacher && matchDay;
    }).toList();

    // Sort by weekday, then teaching hour
    filteredSchedules.sort((a, b) {
      final dayCompare = a.date.weekday.compareTo(b.date.weekday);
      if (dayCompare != 0) return dayCompare;
      return a.teachingHour.compareTo(b.teachingHour);
    });

    final isLoading = masterProvider.isLoading || scheduleProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Jadwal Mingguan'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/weekly-schedules'),
      body: SafeArea(
        child: Column(
          children: [
            // Filter card at the top
            Card(
              margin: EdgeInsets.all(16.w),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Filter Jadwal Mingguan',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 12.h),

                    // Filter row 1 (Period & Class)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _selectedPeriodId,
                            decoration: const InputDecoration(labelText: 'Periode', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Semua Periode', overflow: TextOverflow.ellipsis)),
                              ...masterProvider.periods.map((p) => DropdownMenuItem<String?>(
                                value: p.id,
                                child: Text(p.name, overflow: TextOverflow.ellipsis),
                              )),
                            ],
                            onChanged: (val) => setState(() => _selectedPeriodId = val),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _selectedClassId,
                            decoration: const InputDecoration(labelText: 'Kelas', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Semua Kelas', overflow: TextOverflow.ellipsis)),
                              ...masterProvider.classes.map((c) => DropdownMenuItem<String?>(
                                value: c.id,
                                child: Text(c.name, overflow: TextOverflow.ellipsis),
                              )),
                            ],
                            onChanged: (val) => setState(() => _selectedClassId = val),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),

                    // Filter row 2 (Teacher & Day)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _selectedTeacherId,
                            decoration: const InputDecoration(labelText: 'Guru', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Semua Guru', overflow: TextOverflow.ellipsis)),
                              ...masterProvider.teachers.map((t) => DropdownMenuItem<String?>(
                                value: t.id,
                                child: Text(t.name, overflow: TextOverflow.ellipsis),
                              )),
                            ],
                            onChanged: (val) => setState(() => _selectedTeacherId = val),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            isExpanded: true,
                            initialValue: _selectedWeekday,
                            decoration: const InputDecoration(labelText: 'Hari', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            items: _daysOfWeek.map((d) {
                              return DropdownMenuItem<int?>(
                                value: d['value'] as int?,
                                child: Text(d['label'] as String, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedWeekday = val),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Filtered results list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Builder(
                      builder: (context) {
                        final groupedSchedules = groupDailySchedules(filteredSchedules);
                        if (groupedSchedules.isEmpty) {
                          return const AppEmptyWidget(
                            title: 'Jadwal Tidak Ditemukan',
                            subtitle: 'Tidak ada jadwal mengajar yang cocok dengan filter di atas.',
                            icon: Icons.search_off_rounded,
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          itemCount: groupedSchedules.length,
                          separatorBuilder: (context, index) => SizedBox(height: 10.h),
                          itemBuilder: (context, index) {
                            final scheduleGroup = groupedSchedules[index];
                            final sched = scheduleGroup.primarySchedule;

                            final teacher = masterProvider.teachers.firstWhere(
                              (t) => t.id == sched.teacherId,
                              orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
                            );

                            final cls = masterProvider.classes.firstWhere(
                              (c) => c.id == sched.classId,
                              orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
                            );

                            final subject = masterProvider.subjects.firstWhere(
                              (s) => s.id == sched.subjectId,
                              orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
                            );

                            final matchedHours = masterProvider.hours
                                .where((h) => scheduleGroup.teachingHours.contains(h.teachingHour))
                                .toList()
                              ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

                            final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '00:00';
                            final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '00:00';
                            final hoursStr = scheduleGroup.teachingHours.join(', ');

                            // Resolve weekday label
                            String dayLabel = 'Hari';
                            switch (sched.date.weekday) {
                              case 1: dayLabel = 'Senin'; break;
                              case 2: dayLabel = 'Selasa'; break;
                              case 3: dayLabel = 'Rabu'; break;
                              case 4: dayLabel = 'Kamis'; break;
                              case 5: dayLabel = 'Jumat'; break;
                              case 6: dayLabel = 'Sabtu'; break;
                              case 7: dayLabel = 'Minggu'; break;
                            }

                            return Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  // Left side Day / Time Badge
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          dayLabel,
                                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          'Jam Ke-$hoursStr',
                                          style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                                        ),
                                        Text(
                                          '$hrStart-$hrEnd',
                                          style: TextStyle(fontSize: 9.sp, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  
                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cls.name,
                                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          subject.name,
                                          style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          'Guru: ${teacher.name}',
                                          style: TextStyle(fontSize: 12.sp, color: const Color(0xFF0D9488), fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      }
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
