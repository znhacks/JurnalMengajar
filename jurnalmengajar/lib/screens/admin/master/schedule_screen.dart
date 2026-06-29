import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../models/schedule_model.dart';
import '../../../models/teacher_model.dart';
import '../../../models/class_model.dart';
import '../../../models/subject_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';

class MasterScheduleScreen extends StatefulWidget {
  const MasterScheduleScreen({super.key});

  @override
  State<MasterScheduleScreen> createState() => _MasterScheduleScreenState();
}

class _MasterScheduleScreenState extends State<MasterScheduleScreen> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
    await Provider.of<ScheduleProvider>(context, listen: false).loadAllSchedules();
  }

  void _showFormDialog({ScheduleModel? schedule}) {
    final noteController = TextEditingController(text: schedule?.note ?? '');
    DateTime startDate = schedule?.date ?? DateTime.now();
    DateTime endDate = schedule?.date ?? DateTime.now();
    List<int> selectedWeekdays = [startDate.weekday];
    bool isActive = schedule?.isActive ?? true;

    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    
    // Default Dropdown Values
    String? selectedPeriodId = schedule?.periodId ?? masterProvider.activePeriod?.id ?? (masterProvider.periods.isNotEmpty ? masterProvider.periods.first.id : null);
    String? selectedTeacherId = schedule?.teacherId ?? (masterProvider.teachers.isNotEmpty ? masterProvider.teachers.first.id : null);
    String? selectedClassId = schedule?.classId ?? (masterProvider.classes.isNotEmpty ? masterProvider.classes.first.id : null);
    String? selectedSubjectId = schedule?.subjectId ?? (masterProvider.subjects.isNotEmpty ? masterProvider.subjects.first.id : null);
    int selectedHour = schedule?.teachingHour ?? (masterProvider.hours.isNotEmpty ? masterProvider.hours.first.teachingHour : 1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> selectStartDate() async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: startDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setDialogState(() {
                startDate = picked;
                if (endDate.isBefore(startDate)) {
                  endDate = startDate;
                }
                selectedWeekdays = [startDate.weekday];
              });
            }
          }

          Future<void> selectEndDate() async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: endDate.isBefore(startDate) ? startDate : endDate,
              firstDate: startDate,
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              setDialogState(() {
                endDate = picked;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    schedule == null ? 'Tambah Jadwal Baru' : 'Edit Jadwal',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),

                  // Date Selection
                  if (schedule == null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: selectStartDate,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text('Mulai: ${AppHelper.formatDateShort(startDate)}'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey[300]!),
                              foregroundColor: const Color(0xFF0F172A),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: selectEndDate,
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text('Selesai: ${AppHelper.formatDateShort(endDate)}'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey[300]!),
                              foregroundColor: const Color(0xFF0F172A),
                              padding: EdgeInsets.symmetric(vertical: 10.h),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),

                    // Weekdays selection
                    Text(
                      'Pilih Hari Aktif:',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 6.h,
                      children: {
                        1: 'Senin',
                        2: 'Selasa',
                        3: 'Rabu',
                        4: 'Kamis',
                        5: 'Jumat',
                        6: 'Sabtu',
                        7: 'Minggu',
                      }.entries.map((entry) {
                        final isSelected = selectedWeekdays.contains(entry.key);
                        return FilterChip(
                          label: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0D9488),
                          backgroundColor: const Color(0xFFF1F5F9),
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedWeekdays.add(entry.key);
                              } else {
                                if (selectedWeekdays.length > 1) {
                                  selectedWeekdays.remove(entry.key);
                                } else {
                                  AppHelper.showSnackBar(context, 'Pilih minimal satu hari', isError: true);
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 12.h),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: selectStartDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Tanggal: ${AppHelper.formatDateShort(startDate)}'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        foregroundColor: const Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],

                  // Period Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedPeriodId,
                    decoration: const InputDecoration(labelText: 'Periode'),
                    items: masterProvider.periods.map((p) {
                      return DropdownMenuItem<String>(value: p.id, child: Text(p.name));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedPeriodId = val),
                  ),
                  SizedBox(height: 12.h),

                  // Teacher Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedTeacherId,
                    decoration: const InputDecoration(labelText: 'Guru Pengampu'),
                    items: masterProvider.teachers.map((t) {
                      return DropdownMenuItem<String>(value: t.id, child: Text(t.name));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedTeacherId = val),
                  ),
                  SizedBox(height: 12.h),

                  // Class Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedClassId,
                    decoration: const InputDecoration(labelText: 'Kelas'),
                    items: masterProvider.classes.map((c) {
                      return DropdownMenuItem<String>(value: c.id, child: Text(c.name));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedClassId = val),
                  ),
                  SizedBox(height: 12.h),

                  // Subject Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedSubjectId,
                    decoration: const InputDecoration(labelText: 'Mata Pelajaran'),
                    items: masterProvider.subjects.map((s) {
                      return DropdownMenuItem<String>(value: s.id, child: Text(s.name));
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedSubjectId = val),
                  ),
                  SizedBox(height: 16.h),

                  // Hour Selection Options (Interactive)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jam Pelajaran',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (masterProvider.hours.isEmpty)
                        Text(
                          'Belum ada master jam pelajaran',
                          style: TextStyle(color: Colors.red[600], fontSize: 13.sp),
                        )
                      else ...[
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: masterProvider.hours.map((h) {
                            final isSelected = selectedHour == h.teachingHour;
                            return ChoiceChip(
                              label: Text(
                                'Jam ${h.teachingHour}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF0D9488),
                              backgroundColor: const Color(0xFFF1F5F9),
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                if (selected) {
                                  setDialogState(() {
                                    selectedHour = h.teachingHour;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 8.h),
                        // Display selected hour range details
                        Builder(
                          builder: (context) {
                            final selectedHourObj = masterProvider.hours.firstWhere(
                              (h) => h.teachingHour == selectedHour,
                              orElse: () => masterProvider.hours.first,
                            );
                            return Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                color: const Color(0x0D0D9488),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0x330D9488)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time, color: Color(0xFF0D9488), size: 18),
                                  SizedBox(width: 8.w),
                                  Text(
                                    'Waktu: Jam ke-${selectedHourObj.teachingHour} (${selectedHourObj.startTime} - ${selectedHourObj.endTime})',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF0D9488),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 16.h),

                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Catatan Jadwal', hintText: 'Opsional'),
                  ),
                  SizedBox(height: 12.h),

                  SwitchListTile(
                    title: const Text('Jadwal Aktif'),
                    value: isActive,
                    activeThumbColor: const Color(0xFF0D9488),
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                  SizedBox(height: 24.h),

                  ElevatedButton(
                    onPressed: () async {
                      if (selectedPeriodId == null || selectedTeacherId == null || selectedClassId == null || selectedSubjectId == null) {
                        AppHelper.showSnackBar(context, 'Harap isi semua pilihan master', isError: true);
                        return;
                      }

                      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
                      bool success;

                      if (schedule == null) {
                        // Generate batch schedules
                        final List<ScheduleModel> schedulesToCreate = [];
                        DateTime current = startDate;
                        while (!current.isAfter(endDate)) {
                          if (selectedWeekdays.contains(current.weekday)) {
                            schedulesToCreate.add(
                              ScheduleModel(
                                id: '',
                                periodId: selectedPeriodId!,
                                date: current,
                                teachingHour: selectedHour,
                                classId: selectedClassId!,
                                subjectId: selectedSubjectId!,
                                teacherId: selectedTeacherId!,
                                note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                isActive: isActive,
                              ),
                            );
                          }
                          current = current.add(const Duration(days: 1));
                        }

                        if (schedulesToCreate.isEmpty) {
                          AppHelper.showSnackBar(
                            context,
                            'Tidak ada jadwal yang cocok dengan hari aktif pada rentang tanggal tersebut',
                            isError: true,
                          );
                          return;
                        }

                        success = await scheduleProvider.createMultipleSchedules(schedulesToCreate);
                      } else {
                        final updatedSched = ScheduleModel(
                          id: schedule.id,
                          periodId: selectedPeriodId!,
                          date: startDate,
                          teachingHour: selectedHour,
                          classId: selectedClassId!,
                          subjectId: selectedSubjectId!,
                          teacherId: selectedTeacherId!,
                          note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                          isActive: isActive,
                        );
                        success = await scheduleProvider.updateSchedule(updatedSched);
                      }

                      if (success && mounted) {
                        AppHelper.showSnackBar(context, 'Jadwal berhasil disimpan!');
                        Navigator.pop(context);
                      } else if (mounted) {
                        AppHelper.showSnackBar(context, scheduleProvider.errorMessage ?? 'Gagal menyimpan jadwal.', isError: true);
                      }
                    },
                    child: const Text('Simpan'),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDelete(String id) async {
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final success = await scheduleProvider.deleteSchedule(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Jadwal berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(context, scheduleProvider.errorMessage ?? 'Gagal menghapus jadwal.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final schedules = scheduleProvider.schedules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Jadwal'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/schedules'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0D9488),
        child: (masterProvider.isLoading || scheduleProvider.isLoading)
            ? const Center(child: CircularProgressIndicator())
            : schedules.isEmpty
                ? const AppEmptyWidget(
                    title: 'Jadwal Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah jadwal mengajar baru.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: schedules.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final sched = schedules[index];

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

                      return Dismissible(
                        key: Key(sched.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20.w),
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _handleDelete(sched.id),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Jadwal'),
                              content: const Text('Apakah Anda yakin ingin menghapus jadwal mengajar ini?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${cls.name} • Jam Ke-${sched.teachingHour}',
                                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 20),
                                        onPressed: () => _showFormDialog(schedule: sched),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Hapus Jadwal'),
                                              content: const Text('Apakah Anda yakin ingin menghapus jadwal mengajar ini?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            _handleDelete(sched.id);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Mata Pelajaran: ${subject.name}',
                                style: TextStyle(fontSize: 13.sp, color: Colors.grey[750], fontWeight: FontWeight.w500),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Guru: ${teacher.name}',
                                style: TextStyle(fontSize: 13.sp, color: const Color(0xFF0D9488), fontWeight: FontWeight.w600),
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppHelper.formatDateShort(sched.date),
                                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                                  ),
                                  Text(
                                    'Status: ${sched.isActive ? 'Aktif' : 'Nonaktif'}',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.bold,
                                      color: sched.isActive ? const Color(0xFF10B981) : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
