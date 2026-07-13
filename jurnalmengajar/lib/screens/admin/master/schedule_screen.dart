import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
    bool isRoutine = groupedSchedule != null
        ? (groupedSchedule.startDate.year != groupedSchedule.endDate.year ||
           groupedSchedule.startDate.month != groupedSchedule.endDate.month ||
           groupedSchedule.startDate.day != groupedSchedule.endDate.day)
        : false;
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

                  // Period Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Periode',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 6.h),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPeriodId,
                        hint: const Text('Pilih Periode'),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                          fillColor: const Color(0xFFF1F5F9),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: masterProvider.periods.map((p) {
                          return DropdownMenuItem<String>(value: p.id, child: Text(p.name));
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedPeriodId = val),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Date and Class side-by-side
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tanggal',
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 6.h),
                            InkWell(
                              onTap: selectStartDate,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      AppHelper.formatDateShort(startDate),
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(
                                      Icons.calendar_month_outlined,
                                      size: 16.sp,
                                      color: Colors.grey[500],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kelas',
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 6.h),
                            DropdownButtonFormField<String>(
                              initialValue: selectedClassId,
                              hint: const Text('Pilih Kelas'),
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                                fillColor: const Color(0xFFF1F5F9),
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10.r),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: masterProvider.classes.map((c) {
                                return DropdownMenuItem<String>(value: c.id, child: Text(c.name));
                              }).toList(),
                              onChanged: (val) => setDialogState(() => selectedClassId = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Teaching Hour (Jam Ke)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jam Ke',
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
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  if (isSelected) {
                                    if (selectedHours.length > 1) {
                                      selectedHours.remove(h.teachingHour);
                                    } else {
                                      AppHelper.showSnackBar(context, 'Pilih minimal satu jam pelajaran', isError: true);
                                    }
                                  } else {
                                    selectedHours.add(h.teachingHour);
                                  }
                                  selectedHours.sort();
                                });
                              },
                              child: Container(
                                width: 40.w,
                                height: 40.h,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  '${h.teachingHour}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Subject selection (Pelajaran)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pelajaran',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 6.h),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubjectId,
                        hint: const Text('Pilih Pelajaran'),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                          fillColor: const Color(0xFFF1F5F9),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: masterProvider.subjects.map((s) {
                          return DropdownMenuItem<String>(value: s.id, child: Text(s.name));
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedSubjectId = val),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Teacher selection (Guru)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guru',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 6.h),
                      DropdownButtonFormField<String>(
                        initialValue: selectedTeacherId,
                        hint: const Text('Pilih Guru'),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                          fillColor: const Color(0xFFF1F5F9),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.r),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: masterProvider.teachers.map((t) {
                          return DropdownMenuItem<String>(value: t.id, child: Text(t.name));
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedTeacherId = val),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Catatan Jadwal (TextField)
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Catatan Jadwal',
                      hintText: 'Opsional',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
                      fillColor: const Color(0xFFF1F5F9),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),

                  // Active Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: isActive,
                        activeColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            isActive = val ?? true;
                          });
                        },
                      ),
                      Text(
                        'Aktif',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),

                  // Buat Jadwal Rutin Switch Card
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: const Color(0xFFDBEAFE),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: const BoxDecoration(
                            color: Color(0xFFDBEAFE),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sync_alt,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Buat Jadwal Rutin',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E40AF),
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Otomatis membuat jadwal mingguan untuk 6 bulan ke depan (1 Semester)',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isRoutine,
                          activeTrackColor: const Color(0xFF2563EB),
                          activeThumbColor: Colors.white,
                          onChanged: (val) {
                            setDialogState(() {
                              isRoutine = val;
                            });
                          },
                        ),
                      ],
                    ),
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

                      final DateTime calculatedEndDate = isRoutine
                          ? DateTime(startDate.year, startDate.month + 6, startDate.day)
                          : startDate;
                      final List<int> selectedWeekdays = [startDate.weekday];

                      if (groupedSchedule == null) {
                        // Generate batch schedules (Create Mode)
                        final List<ScheduleModel> schedulesToCreate = [];
                        DateTime current = startDate;
                        while (!current.isAfter(calculatedEndDate)) {
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

                        success = await scheduleProvider.createMultipleSchedules(schedulesToCreate, masterProvider.teachers);
                      } else {
                        // Edit Mode
                        final journalProvider = Provider.of<JournalProvider>(context, listen: false);
                        final hasJournal = journalProvider.journals.any((j) => groupedSchedule.scheduleIds.contains(j.scheduleId));
                        
                        final sameDates = startDate.year == groupedSchedule.startDate.year &&
                            startDate.month == groupedSchedule.startDate.month &&
                            startDate.day == groupedSchedule.startDate.day &&
                            calculatedEndDate.year == groupedSchedule.endDate.year &&
                            calculatedEndDate.month == groupedSchedule.endDate.month &&
                            calculatedEndDate.day == groupedSchedule.endDate.day;
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
                            final res = await scheduleProvider.updateSchedule(updatedSched, masterProvider.teachers);
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
                          while (!current.isAfter(calculatedEndDate)) {
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
                          success = await scheduleProvider.createMultipleSchedules(schedulesToCreate, masterProvider.teachers);
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Simpan',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 18.r,
                                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                backgroundImage: teacher.photoUrl != null && teacher.photoUrl!.isNotEmpty
                                    ? NetworkImage(teacher.photoUrl!)
                                    : null,
                                child: teacher.photoUrl == null || teacher.photoUrl!.isEmpty
                                    ? Text(
                                        teacher.name.isNotEmpty ? teacher.name.substring(0, 1).toUpperCase() : 'G',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2563EB),
                                          fontSize: 13.sp,
                                        ),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${cls.name} • Jam Ke-${sched.teachingHours.join(', ')}',
                                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 16),
                                              onPressed: () => _showFormDialog(groupedSchedule: sched),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.all(4.w),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
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
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.all(4.w),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      'Mata Pelajaran: ${subject.name}',
                                      style: TextStyle(fontSize: 11.5.sp, color: Colors.grey[700], fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(height: 1.h),
                                    Text(
                                      'Guru: ${teacher.name}',
                                      style: TextStyle(fontSize: 11.5.sp, color: const Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                    ),
                                    if (sched.note != null && sched.note!.isNotEmpty) ...[
                                      SizedBox(height: 1.h),
                                      Text(
                                        'Catatan: ${sched.note}',
                                        style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                    const Divider(height: 8),
                                    Wrap(
                                      spacing: 8.w,
                                      runSpacing: 4.h,
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          '${AppHelper.formatDateShort(sched.startDate)} s/d ${AppHelper.formatDateShort(sched.endDate)}',
                                          style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[500]),
                                        ),
                                        Text(
                                          'Hari: ${sched.weekdays.map(getWeekdayName).join(', ')}',
                                          style: TextStyle(fontSize: 10.5.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                                          decoration: BoxDecoration(
                                            color: (sched.isActive ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            sched.isActive ? 'Aktif' : 'Nonaktif',
                                            style: TextStyle(
                                              fontSize: 9.5.sp,
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
