import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../providers/schedule_provider.dart';
import '../../../providers/journal_provider.dart';
import '../../../models/schedule_model.dart';
import '../../../models/teacher_model.dart';
import '../../../models/class_model.dart';
import '../../../models/subject_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';
import '../../../core/utils/schedule_grouper.dart';

class MasterScheduleScreen extends StatefulWidget {
  const MasterScheduleScreen({super.key});

  @override
  State<MasterScheduleScreen> createState() => _MasterScheduleScreenState();
}

class _MasterScheduleScreenState extends State<MasterScheduleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);

    await Future.wait([
      masterProvider.loadAllData(),
      scheduleProvider.loadAllSchedules(),
      journalProvider.loadAllJournals(),
    ]);
  }

  String getWeekdayName(int weekday) {
    switch (weekday) {
      case 1: return 'Senin';
      case 2: return 'Selasa';
      case 3: return 'Rabu';
      case 4: return 'Kamis';
      case 5: return 'Jumat';
      case 6: return 'Sabtu';
      case 7: return 'Minggu';
      default: return '';
    }
  }

  void _showFormDialog({GroupedMasterSchedule? groupedSchedule}) {
    final noteController = TextEditingController(text: groupedSchedule?.note ?? '');
    DateTime startDate = groupedSchedule?.startDate ?? DateTime.now();
    DateTime endDate = groupedSchedule?.endDate ?? DateTime.now();
    List<int> selectedWeekdays = groupedSchedule != null ? List<int>.from(groupedSchedule.weekdays) : [startDate.weekday];
    bool isActive = groupedSchedule?.isActive ?? true;

    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    
    // Default Dropdown Values
    String? selectedPeriodId = groupedSchedule?.periodId ?? masterProvider.activePeriod?.id ?? (masterProvider.periods.isNotEmpty ? masterProvider.periods.first.id : null);
    String? selectedTeacherId = groupedSchedule?.teacherId ?? (masterProvider.teachers.isNotEmpty ? masterProvider.teachers.first.id : null);
    String? selectedClassId = groupedSchedule?.classId ?? (masterProvider.classes.isNotEmpty ? masterProvider.classes.first.id : null);
    String? selectedSubjectId = groupedSchedule?.subjectId ?? (masterProvider.subjects.isNotEmpty ? masterProvider.subjects.first.id : null);
    
    List<int> selectedHours = groupedSchedule != null 
        ? List<int>.from(groupedSchedule.teachingHours) 
        : [masterProvider.hours.isNotEmpty ? masterProvider.hours.first.teachingHour : 1];

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
                    groupedSchedule == null ? 'Tambah Jadwal Baru' : 'Edit Jadwal',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),

                  // Date Selection
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
                        selectedColor: const Color(0xFF2563EB),
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
                            final isSelected = selectedHours.contains(h.teachingHour);
                            return FilterChip(
                              label: Text(
                                'Jam ${h.teachingHour}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: const Color(0xFF2563EB),
                              backgroundColor: const Color(0xFFF1F5F9),
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedHours.add(h.teachingHour);
                                  } else {
                                    if (selectedHours.length > 1) {
                                      selectedHours.remove(h.teachingHour);
                                    } else {
                                      AppHelper.showSnackBar(context, 'Pilih minimal satu jam pelajaran', isError: true);
                                    }
                                  }
                                  selectedHours.sort();
                                });
                              },
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 8.h),
                        // Display selected hour range details
                        Builder(
                          builder: (context) {
                            if (selectedHours.isEmpty) return const SizedBox();
                            final matchedHours = masterProvider.hours
                                .where((h) => selectedHours.contains(h.teachingHour))
                                .toList()
                              ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));
                            if (matchedHours.isEmpty) return const SizedBox();
                            final minHour = matchedHours.first;
                            final maxHour = matchedHours.last;
                            final hoursStr = selectedHours.join(', ');
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
                                  const Icon(Icons.access_time, color: Color(0xFF2563EB), size: 18),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Waktu: Jam ke-$hoursStr (${minHour.startTime} - ${maxHour.endTime})',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF2563EB),
                                      ),
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
                    activeThumbColor: const Color(0xFF2563EB),
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                  SizedBox(height: 24.h),

                  ElevatedButton(
                    onPressed: () async {
                      if (selectedPeriodId == null || selectedTeacherId == null || selectedClassId == null || selectedSubjectId == null) {
                        FocusScope.of(context).unfocus();
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Form Belum Lengkap'),
                            content: const Text('Harap isi semua pilihan master (Periode, Guru, Kelas, Mata Pelajaran).'),
                            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Oke'))],
                          ),
                        );
                        return;
                      }

                      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
                      final dialogContext = context;
                      bool success = false;

                      if (groupedSchedule == null) {
                        // Generate batch schedules (Create Mode)
                        final List<ScheduleModel> schedulesToCreate = [];
                        DateTime current = startDate;
                        while (!current.isAfter(endDate)) {
                          if (selectedWeekdays.contains(current.weekday)) {
                            for (final hour in selectedHours) {
                              schedulesToCreate.add(
                                ScheduleModel(
                                  id: '',
                                  periodId: selectedPeriodId!,
                                  date: current,
                                  teachingHour: hour,
                                  classId: selectedClassId!,
                                  subjectId: selectedSubjectId!,
                                  teacherId: selectedTeacherId!,
                                  note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                  isActive: isActive,
                                ),
                              );
                            }
                          }
                          current = current.add(const Duration(days: 1));
                        }

                        if (schedulesToCreate.isEmpty) {
                          FocusScope.of(context).unfocus();
                          await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Tidak Ada Jadwal'),
                              content: const Text('Tidak ada jadwal yang cocok dengan hari aktif pada rentang tanggal tersebut.'),
                              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Oke'))],
                            ),
                          );
                          return;
                        }

                        success = await scheduleProvider.createMultipleSchedules(schedulesToCreate);
                      } else {
                        // Edit Mode
                        final journalProvider = Provider.of<JournalProvider>(context, listen: false);
                        final hasJournal = journalProvider.journals.any((j) => groupedSchedule.scheduleIds.contains(j.scheduleId));
                        
                        final sameDates = startDate.year == groupedSchedule.startDate.year &&
                            startDate.month == groupedSchedule.startDate.month &&
                            startDate.day == groupedSchedule.startDate.day &&
                            endDate.year == groupedSchedule.endDate.year &&
                            endDate.month == groupedSchedule.endDate.month &&
                            endDate.day == groupedSchedule.endDate.day;
                        final sameWeekdays = selectedWeekdays.length == groupedSchedule.weekdays.length && selectedWeekdays.every(groupedSchedule.weekdays.contains);
                        final sameHours = selectedHours.length == groupedSchedule.teachingHours.length && selectedHours.every(groupedSchedule.teachingHours.contains);

                        if (hasJournal && !(sameDates && sameWeekdays && sameHours)) {
                          FocusScope.of(context).unfocus();
                          final confirmChange = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                              title: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A), size: 28),
                                  SizedBox(width: 8),
                                  Text('Konfirmasi Ubah Hari/Jam'),
                                ],
                              ),
                              content: const Text(
                                'Mengubah tanggal, hari, atau jam akan menghapus seluruh jurnal mengajar yang sudah diisi pada jadwal ini secara permanen.\n\n'
                                'Apakah Anda yakin ingin melanjutkan?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Lanjutkan',
                                    style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirmChange != true) return;
                        }

                        if (hasJournal && sameDates && sameWeekdays && sameHours) {
                          bool allSuccess = true;
                          for (final id in groupedSchedule.scheduleIds) {
                            final original = scheduleProvider.schedules.firstWhere((s) => s.id == id);
                            final updatedSched = ScheduleModel(
                              id: id,
                              periodId: selectedPeriodId!,
                              date: original.date,
                              teachingHour: original.teachingHour,
                              classId: selectedClassId!,
                              subjectId: selectedSubjectId!,
                              teacherId: selectedTeacherId!,
                              note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                              isActive: isActive,
                            );
                            final res = await scheduleProvider.updateSchedule(updatedSched);
                            if (!res) allSuccess = false;
                          }
                          success = allSuccess;
                        } else {
                          // Safe edit: delete old and recreate
                          final bool deleteSuccess = await scheduleProvider.deleteMultipleSchedules(groupedSchedule.scheduleIds);
                          if (!dialogContext.mounted) return;
                          if (!deleteSuccess) {
                            FocusScope.of(context).unfocus();
                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Gagal Memperbarui'),
                                content: const Text('Gagal memperbarui jadwal (Gagal menghapus jadwal lama).'),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Oke'))],
                              ),
                            );
                            return;
                          }
                          
                          final List<ScheduleModel> schedulesToCreate = [];
                          DateTime current = startDate;
                          while (!current.isAfter(endDate)) {
                            if (selectedWeekdays.contains(current.weekday)) {
                              for (final hour in selectedHours) {
                                schedulesToCreate.add(
                                  ScheduleModel(
                                    id: '',
                                    periodId: selectedPeriodId!,
                                    date: current,
                                    teachingHour: hour,
                                    classId: selectedClassId!,
                                    subjectId: selectedSubjectId!,
                                    teacherId: selectedTeacherId!,
                                    note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                                    isActive: isActive,
                                  ),
                                );
                              }
                            }
                            current = current.add(const Duration(days: 1));
                          }
                          
                          if (schedulesToCreate.isEmpty) {
                            FocusScope.of(context).unfocus();
                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Tidak Ada Jadwal'),
                                content: const Text('Tidak ada jadwal yang cocok dengan hari aktif pada rentang tanggal tersebut.'),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Oke'))],
                              ),
                            );
                            return;
                          }
                          success = await scheduleProvider.createMultipleSchedules(schedulesToCreate);
                        }
                      }

                      if (!context.mounted || !dialogContext.mounted) return;

                      if (success) {
                        Navigator.pop(dialogContext);
                        AppHelper.showSnackBar(context, 'Jadwal berhasil disimpan!');
                      } else {
                        // Dismiss keyboard first
                        FocusScope.of(context).unfocus();
                        final errMsg = scheduleProvider.errorMessage ?? 'Gagal menyimpan jadwal.';
                        await showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            icon: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 40),
                            title: const Text('Tidak Dapat Menyimpan', textAlign: TextAlign.center),
                            content: Text(errMsg, textAlign: TextAlign.center),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Mengerti'),
                              ),
                            ],
                          ),
                        );
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

  Future<void> _handleDelete(List<String> ids) async {
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final hasJournal = journalProvider.journals.any((j) => ids.contains(j.scheduleId));
    
    if (hasJournal) {
      final confirmForce = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFBA1A1A), size: 28),
              SizedBox(width: 8),
              Text('Hapus Jadwal & Jurnal'),
            ],
          ),
          content: const Text(
            'Jadwal ini memiliki jurnal mengajar yang sudah diisi. '
            'Menghapus jadwal ini juga akan menghapus seluruh jurnal mengajar terkait secara permanen.\n\n'
            'Apakah Anda yakin ingin menghapus?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Hapus Permanen',
                style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      if (confirmForce != true) return;
    }

    final success = await scheduleProvider.deleteMultipleSchedules(ids);
    if (!mounted) return;
    if (success) {
      AppHelper.showSnackBar(context, 'Jadwal berhasil dihapus');
    } else {
      AppHelper.showSnackBar(context, scheduleProvider.errorMessage ?? 'Gagal menghapus jadwal.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final schedules = scheduleProvider.schedules;
    final groupedSchedules = groupMasterSchedules(schedules);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Mengajar'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/schedules'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2563EB),
        child: (masterProvider.isLoading || scheduleProvider.isLoading)
            ? const Center(child: CircularProgressIndicator())
            : groupedSchedules.isEmpty
                ? const AppEmptyWidget(
                    title: 'Jadwal Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah jadwal mengajar baru.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: groupedSchedules.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final sched = groupedSchedules[index];

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
                        key: Key(sched.scheduleIds.first),
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
                        onDismissed: (_) => _handleDelete(sched.scheduleIds),
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
                                      '${cls.name} • Jam Ke-${sched.teachingHours.join(', ')}',
                                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 20),
                                        onPressed: () => _showFormDialog(groupedSchedule: sched),
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
                                            _handleDelete(sched.scheduleIds);
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
                                style: TextStyle(fontSize: 13.sp, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                              ),
                              if (sched.note != null && sched.note!.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  'Catatan: ${sched.note}',
                                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                ),
                              ],
                              const Divider(height: 16),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 4.h,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${AppHelper.formatDateShort(sched.startDate)} s/d ${AppHelper.formatDateShort(sched.endDate)}',
                                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                                  ),
                                  Text(
                                    'Hari: ${sched.weekdays.map(getWeekdayName).join(', ')}',
                                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: (sched.isActive ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      sched.isActive ? 'Aktif' : 'Nonaktif',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.bold,
                                        color: sched.isActive ? const Color(0xFF10B981) : Colors.red,
                                      ),
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
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
