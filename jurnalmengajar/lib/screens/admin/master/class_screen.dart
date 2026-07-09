import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../models/class_model.dart';
import '../../../models/period_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';

class MasterClassScreen extends StatefulWidget {
  const MasterClassScreen({super.key});

  @override
  State<MasterClassScreen> createState() => _MasterClassScreenState();
}

class _MasterClassScreenState extends State<MasterClassScreen> {
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

  void _showFormDialog({ClassModel? classItem}) {
    final nameController = TextEditingController(text: classItem?.name ?? '');
    final studentCountController = TextEditingController(text: classItem != null ? '${classItem.studentCount}' : '');
    
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final activePeriod = masterProvider.activePeriod;
    
    // Choose periodId: existing class's periodId, or the currently active period, or the first period in list
    String? selectedPeriodId = classItem?.periodId ?? activePeriod?.id ?? (masterProvider.periods.isNotEmpty ? masterProvider.periods.first.id : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                    classItem == null ? 'Tambah Kelas Baru' : 'Edit Kelas',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  
                  // Period Selector Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedPeriodId,
                    decoration: const InputDecoration(labelText: 'Periode Akademik'),
                    items: masterProvider.periods.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(p.name + (p.isActive ? ' (Aktif)' : '')),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedPeriodId = val;
                      });
                    },
                  ),
                  SizedBox(height: 12.h),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kelas',
                      hintText: 'Contoh: Kelas X-A, XI-MIPA 1',
                    ),
                  ),
                  SizedBox(height: 12.h),

                  TextField(
                    controller: studentCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Siswa',
                      hintText: 'Contoh: 32',
                    ),
                  ),
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedPeriodId == null) {
                        AppHelper.showSnackBar(context, 'Pilih periode akademik terlebih dahulu', isError: true);
                        return;
                      }
                      if (nameController.text.trim().isEmpty) {
                        AppHelper.showSnackBar(context, 'Nama kelas tidak boleh kosong', isError: true);
                        return;
                      }
                      final sCount = int.tryParse(studentCountController.text.trim());
                      if (sCount == null || sCount <= 0) {
                        AppHelper.showSnackBar(context, 'Jumlah siswa harus berupa angka positif', isError: true);
                        return;
                      }

                      bool success;

                      if (classItem == null) {
                        success = await masterProvider.createClass(ClassModel(
                          id: '',
                          periodId: selectedPeriodId!,
                          name: nameController.text.trim(),
                          studentCount: sCount,
                        ));
                      } else {
                        success = await masterProvider.updateClass(classItem.copyWith(
                          periodId: selectedPeriodId!,
                          name: nameController.text.trim(),
                          studentCount: sCount,
                        ));
                      }

                      if (success && context.mounted) {
                        AppHelper.showSnackBar(context, 'Kelas berhasil disimpan!');
                        Navigator.pop(context);
                      } else if (context.mounted) {
                        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menyimpan kelas.', isError: true);
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
    final success = await masterProvider.deleteClass(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Kelas berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus kelas.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final classes = masterProvider.classes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Kelas'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/classes'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2563EB),
        child: masterProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : classes.isEmpty
                ? const AppEmptyWidget(
                    title: 'Kelas Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah kelas.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: classes.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final item = classes[index];
                      final period = masterProvider.periods.firstWhere(
                        (p) => p.id == item.periodId,
                        orElse: () => PeriodModel(id: '', name: 'Periode--', isActive: false),
                      );

                      return Dismissible(
                        key: Key(item.id),
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
                        onDismissed: (_) => _handleDelete(item.id),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Kelas'),
                              content: const Text('Apakah Anda yakin ingin menghapus kelas ini?'),
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
                                backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                child: Icon(Icons.class_, color: const Color(0xFF2563EB), size: 20.w),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Periode: ${period.name}',
                                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      '${item.studentCount} Siswa',
                                      style: TextStyle(fontSize: 12.sp, color: const Color(0xFF2563EB), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                                    onPressed: () => _showFormDialog(classItem: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Hapus Kelas'),
                                          content: const Text('Apakah Anda yakin ingin menghapus kelas ini?'),
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
                                        _handleDelete(item.id);
                                      }
                                    },
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
