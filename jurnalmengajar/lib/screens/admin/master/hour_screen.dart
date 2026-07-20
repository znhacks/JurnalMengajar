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
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  void _toggleSelectionMode({String? initialId}) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
      if (_isSelectionMode && initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _toggleSelectItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<HourModel> allHours) {
    setState(() {
      if (_selectedIds.length == allHours.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allHours.map((h) => h.id));
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $count Jam Mengajar', style: const TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menghapus $count jam mengajar yang dipilih?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Massal', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
      final idsToDelete = _selectedIds.toList();
      final success = await masterProvider.deleteMultipleHours(idsToDelete);
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count jam mengajar berhasil dihapus.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus jam mengajar.', isError: true);
      }
    }
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
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              title: Text('${_selectedIds.length} Terpilih', style: const TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedIds.length == hours.length ? Icons.deselect : Icons.select_all,
                    color: Colors.white,
                  ),
                  tooltip: _selectedIds.length == hours.length ? 'Batal Pilih Semua' : 'Pilih Semua',
                  onPressed: () => _selectAll(hours),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus Massal',
                  onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                ),
              ],
            )
          : AppBar(
              title: const Text('Master Jam Pelajaran'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Pilih Massal',
                  onPressed: hours.isEmpty ? null : () => _toggleSelectionMode(),
                ),
              ],
            ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/hours'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2563EB),
        child: masterProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : hours.isEmpty
                ? const AppEmptyWidget(
                    title: 'Jam Pelajaran Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah jam pelajaran.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    itemCount: hours.length,
                    separatorBuilder: (context, index) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final hour = hours[index];
                      final isSelected = _selectedIds.contains(hour.id);

                      return InkWell(
                        onTap: _isSelectionMode ? () => _toggleSelectItem(hour.id) : null,
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode(initialId: hour.id);
                          } else {
                            _toggleSelectItem(hour.id);
                          }
                        },
                        borderRadius: BorderRadius.circular(12.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_isSelectionMode) ...[
                                Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF2563EB),
                                  onChanged: (_) => _toggleSelectItem(hour.id),
                                ),
                                SizedBox(width: 4.w),
                              ],
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Jam Pelajaran Ke-${hour.teachingHour}',
                                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 2.h),
                                    Row(
                                      children: [
                                        const Icon(Icons.schedule, size: 12, color: Colors.grey),
                                        SizedBox(width: 4.w),
                                        Text(
                                          '${hour.startTime} s.d. ${hour.endTime}',
                                          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isSelectionMode)
                                Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     IconButton(
                                       icon: const Icon(Icons.edit_outlined, color: Colors.indigo, size: 18),
                                       onPressed: () => _showFormDialog(hour: hour),
                                       constraints: const BoxConstraints(),
                                       padding: EdgeInsets.all(8.w),
                                     ),
                                     IconButton(
                                       icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                       onPressed: () async {
                                         final confirm = await showDialog<bool>(
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
                                         if (confirm == true) {
                                           _handleDelete(hour.id);
                                         }
                                       },
                                       constraints: const BoxConstraints(),
                                       padding: EdgeInsets.all(8.w),
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
