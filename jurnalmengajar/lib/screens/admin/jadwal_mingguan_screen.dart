import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/state_widgets.dart';
import '../../core/utils/schedule_grouper.dart';

import '../../core/utils/helper.dart';

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
    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    setState(() {
      _selectedPeriodId =
          masterProvider.activePeriod?.id ??
          (masterProvider.periods.isNotEmpty
              ? masterProvider.periods.first.id
              : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    // Apply filters to schedules list
    final filteredSchedules = scheduleProvider.schedules.where((s) {
      bool matchPeriod =
          _selectedPeriodId == null || s.periodId == _selectedPeriodId;
      bool matchClass =
          _selectedClassId == null || s.classId == _selectedClassId;
      bool matchTeacher =
          _selectedTeacherId == null || s.teacherId == _selectedTeacherId;
      bool matchDay =
          _selectedWeekday == null || s.date.weekday == _selectedWeekday;
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
      appBar: AppBar(title: const Text('Laporan Jadwal Mingguan')),
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
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    // Filter row 1 (Period & Class)
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _selectedPeriodId,
                            decoration: const InputDecoration(
                              labelText: 'Periode',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'Semua Periode',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...masterProvider.periods.map(
                                (p) => DropdownMenuItem<String?>(
                                  value: p.id,
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedPeriodId = val),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _selectedClassId,
                            decoration: const InputDecoration(
                              labelText: 'Kelas',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'Semua Kelas',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...masterProvider.classes.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedClassId = val),
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
                            decoration: const InputDecoration(
                              labelText: 'Guru',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'Pilih Guru',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...masterProvider.teachers.map(
                                (t) => DropdownMenuItem<String?>(
                                  value: t.id,
                                  child: Text(
                                    t.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedTeacherId = val),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            isExpanded: true,
                            initialValue: _selectedWeekday,
                            decoration: const InputDecoration(
                              labelText: 'Hari',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            items: _daysOfWeek.map((d) {
                              return DropdownMenuItem<int?>(
                                value: d['value'] as int?,
                                child: Text(
                                  d['label'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedWeekday = val),
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
                        // 1. Group the flat schedules into weekly master schedules
                        final masterGroups = groupMasterSchedules(filteredSchedules);

                        // 2. Distribute into weekdays (1 to 7)
                        final Map<int, List<GroupedMasterSchedule>> weekdayGroups = {};
                        for (final g in masterGroups) {
                          for (final day in g.weekdays) {
                            weekdayGroups.putIfAbsent(day, () => []).add(g);
                          }
                        }

                        // Get sorted weekdays that have schedules
                        final activeDays = weekdayGroups.keys.toList()..sort();

                        if (activeDays.isEmpty) {
                          return const AppEmptyWidget(
                            title: 'Jadwal Tidak Ditemukan',
                            subtitle: 'Tidak ada jadwal mengajar yang cocok dengan filter di atas.',
                            icon: Icons.search_off_rounded,
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          itemCount: activeDays.length,
                          separatorBuilder: (context, index) => SizedBox(height: 18.h),
                          itemBuilder: (context, index) {
                            final day = activeDays[index];
                            final daySchedules = weekdayGroups[day]!;
                            
                            // Sort day schedules by their first teaching hour
                            daySchedules.sort((a, b) {
                              final hourA = a.teachingHours.isNotEmpty ? a.teachingHours.first : 0;
                              final hourB = b.teachingHours.isNotEmpty ? b.teachingHours.first : 0;
                              return hourA.compareTo(hourB);
                            });

                            String dayName = 'Hari';
                            Color dayColor = const Color(0xFF2563EB);
                            switch (day) {
                              case 1: dayName = 'SENIN'; dayColor = const Color(0xFF2563EB); break;
                              case 2: dayName = 'SELASA'; dayColor = const Color(0xFF3B82F6); break;
                              case 3: dayName = 'RABU'; dayColor = const Color(0xFF8B5CF6); break;
                              case 4: dayName = 'KAMIS'; dayColor = const Color(0xFFF59E0B); break;
                              case 5: dayName = 'JUMAT'; dayColor = const Color(0xFF10B981); break;
                              case 6: dayName = 'SABTU'; dayColor = const Color(0xFFEC4899); break;
                              case 7: dayName = 'MINGGU'; dayColor = const Color(0xFFEF4444); break;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Day Header Badge
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                  decoration: BoxDecoration(
                                    color: dayColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: dayColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today, size: 14.sp, color: dayColor),
                                      SizedBox(width: 6.w),
                                      Text(
                                        dayName,
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.bold,
                                          color: dayColor,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Text(
                                        '(${daySchedules.length} Jadwal)',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                
                                // Schedules under this day
                                ...daySchedules.map((item) {
                                  final teacher = masterProvider.teachers.firstWhere(
                                    (t) => t.id == item.teacherId,
                                    orElse: () => TeacherModel(
                                      id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''
                                    ),
                                  );

                                  final cls = masterProvider.classes.firstWhere(
                                    (c) => c.id == item.classId,
                                    orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
                                  );

                                  final subject = masterProvider.subjects.firstWhere(
                                    (s) => s.id == item.subjectId,
                                    orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
                                  );

                                  final matchedHours = masterProvider.hours
                                      .where((h) => item.teachingHours.contains(h.teachingHour))
                                      .toList()
                                    ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

                                  final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '00:00';
                                  final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '00:00';
                                  final hoursStr = item.teachingHours.join(', ');

                                  final startStr = AppHelper.formatDateShort(item.startDate);
                                  final endStr = AppHelper.formatDateShort(item.endDate);

                                  return InkWell(
                                    onTap: () {
                                      context.go('/admin/dashboard?teacherId=${item.teacherId}');
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: 8.h),
                                      padding: EdgeInsets.all(12.w),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.01),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IntrinsicHeight(
                                        child: Row(
                                          children: [
                                            // Time & Hour Indicator
                                            SizedBox(
                                              width: 84.w,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Jam $hoursStr',
                                                    style: TextStyle(
                                                      fontSize: 13.sp,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    '$hrStart - $hrEnd',
                                                    style: TextStyle(
                                                      fontSize: 11.sp,
                                                      color: Colors.grey[600],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            VerticalDivider(
                                              color: const Color(0xFFE2E8F0),
                                              thickness: 1.2,
                                              width: 16.w,
                                            ),
                                            
                                            // Details
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          cls.name,
                                                          style: TextStyle(
                                                            fontSize: 14.sp,
                                                            fontWeight: FontWeight.bold,
                                                            color: const Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                      ),
                                                      // Status Active Badge
                                                      Container(
                                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                                        decoration: BoxDecoration(
                                                          color: item.isActive 
                                                              ? const Color(0xFFECFDF5) 
                                                              : const Color(0xFFFEF2F2),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          item.isActive ? 'Aktif' : 'Nonaktif',
                                                          style: TextStyle(
                                                            fontSize: 8.sp,
                                                            fontWeight: FontWeight.bold,
                                                            color: item.isActive 
                                                              ? const Color(0xFF059669) 
                                                              : const Color(0xFFDC2626),
                                                        ),
                                                      ),
                                                    ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    subject.name,
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      color: Colors.grey[700],
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2.h),
                                                  Text(
                                                    'Guru: ${teacher.name}',
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      color: const Color(0xFF2563EB),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  // Effective Date range badge
                                                  Row(
                                                    children: [
                                                      Icon(Icons.date_range, size: 10.sp, color: Colors.grey[500]),
                                                      SizedBox(width: 4.w),
                                                      Text(
                                                        'Efektif: $startStr s/d $endStr',
                                                        style: TextStyle(
                                                          fontSize: 10.sp,
                                                          color: Colors.grey[500],
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
