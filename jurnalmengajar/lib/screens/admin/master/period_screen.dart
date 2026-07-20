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

  void _selectAll(List<PeriodModel> allPeriods) {
    setState(() {
      if (_selectedIds.length == allPeriods.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allPeriods.map((p) => p.id));
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $count Periode Akademik', style: const TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menghapus $count periode akademik yang dipilih?'),
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
      final success = await masterProvider.deleteMultiplePeriods(idsToDelete);
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count periode akademik berhasil dihapus.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus periode akademik.', isError: true);
      }
    }
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
  }

  void _showFormDialog({PeriodModel? period}) {
    final nameController = TextEditingController(text: period?.name ?? '');
    bool isActive = period?.isActive ?? false;

    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final hasExistingActivePeriod = masterProvider.periods.any(
      (p) => p.isActive && (period == null || p.id != period.id),
    );
    final existingActivePeriodName = masterProvider.periods.firstWhere(
      (p) => p.isActive && (period == null || p.id != period.id),
      orElse: () => PeriodModel(id: '', name: '', isActive: false),
    ).name;

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
                        activeThumbColor: const Color(0xFF2563EB),
                        onChanged: (val) {
                          setDialogState(() {
                            isActive = val;
                          });
                        },
                      ),
                      SizedBox(height: 8.h),
                      if (isActive && hasExistingActivePeriod) ...[
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: const Color(0xFFD97706),
                                size: 20.r,
                              ),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Perhatian',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF92400E),
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      'Mengaktifkan periode ini akan menonaktifkan periode "$existingActivePeriodName" yang saat ini sedang aktif.',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.h),
                      ],
                      SizedBox(height: 16.h),
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

                          if (success && context.mounted) {
                            AppHelper.showSnackBar(context, 'Periode berhasil disimpan!');
                            Navigator.pop(context);
                          } else if (context.mounted) {
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
                    _selectedIds.length == periods.length ? Icons.deselect : Icons.select_all,
                    color: Colors.white,
                  ),
                  tooltip: _selectedIds.length == periods.length ? 'Batal Pilih Semua' : 'Pilih Semua',
                  onPressed: () => _selectAll(periods),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus Massal',
                  onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                ),
              ],
            )
          : AppBar(
              title: const Text('Master Periode'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Pilih Massal',
                  onPressed: periods.isEmpty ? null : () => _toggleSelectionMode(),
                ),
              ],
            ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/periods'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2563EB),
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
                      final isSelected = _selectedIds.contains(period.id);

                      return InkWell(
                        onTap: _isSelectionMode ? () => _toggleSelectItem(period.id) : null,
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode(initialId: period.id);
                          } else {
                            _toggleSelectItem(period.id);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
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
                                  onChanged: (_) => _toggleSelectItem(period.id),
                                ),
                                SizedBox(width: 4.w),
                              ],
                              CircleAvatar(
                                backgroundColor: period.isActive ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.grey[100],
                                child: Icon(
                                  period.isActive ? Icons.check : Icons.history,
                                  color: period.isActive ? const Color(0xFF2563EB) : Colors.grey,
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
                                        color: period.isActive ? const Color(0xFF2563EB) : Colors.grey[600],
                                        fontWeight: period.isActive ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_isSelectionMode)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                                      onPressed: () => _showFormDialog(period: period),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
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
                                        if (confirm == true) {
                                          _handleDelete(period.id);
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
