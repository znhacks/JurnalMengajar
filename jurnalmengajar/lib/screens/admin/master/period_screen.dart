import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../models/period_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';

class MasterPeriodScreen extends StatefulWidget {
  const MasterPeriodScreen({super.key});

  @override
  State<MasterPeriodScreen> createState() => _MasterPeriodScreenState();
}

class _MasterPeriodScreenState extends State<MasterPeriodScreen> {
  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
  }

  void _showFormDialog({PeriodModel? period}) {
    final nameController = TextEditingController(text: period?.name ?? '');
    bool isActive = period?.isActive ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20.h,
                left: 20.w,
                right: 20.w,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        period == null ? 'Tambah Periode Baru' : 'Edit Periode',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16.h),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Periode',
                          hintText: 'Contoh: 2025/2026 Ganjil',
                        ),
                      ),
                      SizedBox(height: 16.h),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text('Status Aktif'),
                        subtitle: const Text('Hanya boleh ada satu periode aktif dalam satu waktu'),
                        value: isActive,
                        activeThumbColor: const Color(0xFF0D9488),
                        onChanged: (val) {
                          setDialogState(() {
                            isActive = val;
                          });
                        },
                      ),
                      SizedBox(height: 24.h),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) {
                            AppHelper.showSnackBar(context, 'Nama periode tidak boleh kosong', isError: true);
                            return;
                          }

                          final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                          bool success;

                          if (period == null) {
                            success = await masterProvider.createPeriod(PeriodModel(
                              id: '',
                              name: nameController.text.trim(),
                              isActive: isActive,
                            ));
                          } else {
                            success = await masterProvider.updatePeriod(period.copyWith(
                              name: nameController.text.trim(),
                              isActive: isActive,
                            ));
                          }

                          if (success && mounted) {
                            AppHelper.showSnackBar(context, 'Periode berhasil disimpan!');
                            Navigator.pop(context);
                          } else if (mounted) {
                            AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menyimpan periode.', isError: true);
                          }
                        },
                        child: const Text('Simpan'),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleDelete(String id) async {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final success = await masterProvider.deletePeriod(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Periode berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus periode.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final periods = masterProvider.periods;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Periode'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/periods'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0D9488),
        child: masterProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : periods.isEmpty
                ? const AppEmptyWidget(
                    title: 'Periode Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah periode akademik.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: periods.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final period = periods[index];
                      return Dismissible(
                        key: Key(period.id),
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
                        onDismissed: (_) => _handleDelete(period.id),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Periode'),
                              content: const Text('Apakah Anda yakin ingin menghapus periode akademik ini?'),
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
                                backgroundColor: period.isActive ? const Color(0xFF0D9488).withValues(alpha: 0.1) : Colors.grey[100],
                                child: Icon(
                                  period.isActive ? Icons.check : Icons.history,
                                  color: period.isActive ? const Color(0xFF0D9488) : Colors.grey,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      period.name,
                                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      period.isActive ? 'Periode Aktif' : 'Tidak Aktif',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: period.isActive ? const Color(0xFF0D9488) : Colors.grey[600],
                                        fontWeight: period.isActive ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                                onPressed: () => _showFormDialog(period: period),
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
