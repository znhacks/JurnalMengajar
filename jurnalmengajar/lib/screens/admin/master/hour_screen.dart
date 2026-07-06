import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../models/hour_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';

class MasterHourScreen extends StatefulWidget {
  const MasterHourScreen({super.key});

  @override
  State<MasterHourScreen> createState() => _MasterHourScreenState();
}

class _MasterHourScreenState extends State<MasterHourScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
  }

  Future<void> _showFormDialog({HourModel? hour}) async {
    final hourNumberController = TextEditingController(text: hour != null ? '${hour.teachingHour}' : '');
    String startTimeStr = hour?.startTime ?? '07:00';
    String endTimeStr = hour?.endTime ?? '07:45';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> selectTime(bool isStart) async {
            final parts = (isStart ? startTimeStr : endTimeStr).split(':');
            final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
            
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: initialTime,
            );

            if (picked != null) {
              final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              setDialogState(() {
                if (isStart) {
                  startTimeStr = formattedTime;
                } else {
                  endTimeStr = formattedTime;
                }
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
                    hour == null ? 'Tambah Jam Pelajaran Baru' : 'Edit Jam Pelajaran',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: hourNumberController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jam Ke-',
                      hintText: 'Contoh: 1, 2, 3',
                    ),
                  ),
                  SizedBox(height: 16.h),
                  
                  // Start & End Time Selectors
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => selectTime(true),
                          icon: const Icon(Icons.access_time),
                          label: Text('Mulai: $startTimeStr'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => selectTime(false),
                          icon: const Icon(Icons.access_time),
                          label: Text('Selesai: $endTimeStr'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[300]!),
                            foregroundColor: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: () async {
                      final hNum = int.tryParse(hourNumberController.text.trim());
                      if (hNum == null || hNum <= 0) {
                        AppHelper.showSnackBar(context, 'Nomor jam pelajaran harus angka positif', isError: true);
                        return;
                      }

                      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                      bool success;

                      if (hour == null) {
                        success = await masterProvider.createHour(HourModel(
                          id: '',
                          teachingHour: hNum,
                          startTime: startTimeStr,
                          endTime: endTimeStr,
                        ));
                      } else {
                        success = await masterProvider.updateHour(hour.copyWith(
                          teachingHour: hNum,
                          startTime: startTimeStr,
                          endTime: endTimeStr,
                        ));
                      }

                      if (success && context.mounted) {
                        AppHelper.showSnackBar(context, 'Jam pelajaran berhasil disimpan!');
                        Navigator.pop(context);
                      } else if (context.mounted) {
                        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menyimpan jam pelajaran.', isError: true);
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
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final success = await masterProvider.deleteHour(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Jam pelajaran berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus jam pelajaran.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final hours = masterProvider.hours;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Jam Pelajaran'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/hours'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0D9488),
        child: masterProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : hours.isEmpty
                ? const AppEmptyWidget(
                    title: 'Jam Pelajaran Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah jam pelajaran.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: hours.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final hour = hours[index];
                      return Dismissible(
                        key: Key(hour.id),
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
                        onDismissed: (_) => _handleDelete(hour.id),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Jam Pelajaran'),
                              content: const Text('Apakah Anda yakin ingin menghapus jam pelajaran ini?'),
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
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.1),
                                child: Text(
                                  '#${hour.teachingHour}',
                                  style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jam Pelajaran Ke-${hour.teachingHour}',
                                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 4.h),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, size: 14, color: Colors.grey),
                                        SizedBox(width: 4.w),
                                        Text(
                                          '${hour.startTime} s.d. ${hour.endTime}',
                                          style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                                onPressed: () => _showFormDialog(hour: hour),
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
