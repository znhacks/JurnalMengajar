import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
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

  void _selectAll(List<ClassModel> allClasses) {
    setState(() {
      if (_selectedIds.length == allClasses.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allClasses.map((c) => c.id));
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $count Kelas', style: const TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menghapus $count kelas yang dipilih? Data siswa di dalamnya mungkin akan ikut terpengaruh.'),
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
      final success = await masterProvider.deleteMultipleClasses(idsToDelete);
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count kelas berhasil dihapus.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus data kelas.', isError: true);
      }
    }
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
  }

  void _showFormDialog({ClassModel? classItem}) {
    final nameController = TextEditingController(text: classItem?.name ?? '');

    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    final activePeriod = masterProvider.activePeriod;

    // Choose periodId: existing class's periodId, or the currently active period, or the first period in list
    String? selectedPeriodId =
        classItem?.periodId ??
        activePeriod?.id ??
        (masterProvider.periods.isNotEmpty
            ? masterProvider.periods.first.id
            : null);

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
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),

                  // Period Selector Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedPeriodId,
                    decoration: const InputDecoration(
                      labelText: 'Periode Akademik',
                    ),
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
                  SizedBox(height: 24.h),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedPeriodId == null) {
                        AppHelper.showSnackBar(
                          context,
                          'Pilih periode akademik terlebih dahulu',
                          isError: true,
                        );
                        return;
                      }
                      if (nameController.text.trim().isEmpty) {
                        AppHelper.showSnackBar(
                          context,
                          'Nama kelas tidak boleh kosong',
                          isError: true,
                        );
                        return;
                      }

                      bool success;

                      if (classItem == null) {
                        success = await masterProvider.createClass(
                          ClassModel(
                            id: '',
                            periodId: selectedPeriodId!,
                            name: nameController.text.trim(),
                            studentCount: 0,
                          ),
                        );
                      } else {
                        success = await masterProvider.updateClass(
                          classItem.copyWith(
                            periodId: selectedPeriodId!,
                            name: nameController.text.trim(),
                          ),
                        );
                      }

                      if (success && context.mounted) {
                        AppHelper.showSnackBar(
                          context,
                          'Kelas berhasil disimpan!',
                        );
                        Navigator.pop(context);
                      } else if (context.mounted) {
                        AppHelper.showSnackBar(
                          context,
                          masterProvider.errorMessage ??
                              'Gagal menyimpan kelas.',
                          isError: true,
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

  Future<void> _handleDelete(String id) async {
    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    final success = await masterProvider.deleteClass(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Kelas berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(
        context,
        masterProvider.errorMessage ?? 'Gagal menghapus kelas.',
        isError: true,
      );
    }
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: EdgeInsets.all(5.w),
        child: Icon(icon, color: color, size: 18.w),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final classes = masterProvider.classes;

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
                    _selectedIds.length == classes.length ? Icons.deselect : Icons.select_all,
                    color: Colors.white,
                  ),
                  tooltip: _selectedIds.length == classes.length ? 'Batal Pilih Semua' : 'Pilih Semua',
                  onPressed: () => _selectAll(classes),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus Massal',
                  onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                ),
              ],
            )
          : AppBar(
              title: const Text('Master Kelas & Siswa'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Pilih Massal',
                  onPressed: classes.isEmpty ? null : () => _toggleSelectionMode(),
                ),
              ],
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
                    orElse: () =>
                        PeriodModel(id: '', name: 'Periode--', isActive: false),
                  );
                  final isSelected = _selectedIds.contains(item.id);

                  return InkWell(
                    onTap: _isSelectionMode
                        ? () => _toggleSelectItem(item.id)
                        : () => context.push(
                            '/admin/master-data/classes/${item.id}/students',
                          ),
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        _toggleSelectionMode(initialId: item.id);
                      } else {
                        _toggleSelectItem(item.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
                              onChanged: (_) => _toggleSelectItem(item.id),
                            ),
                            SizedBox(width: 4.w),
                          ],
                          CircleAvatar(
                            radius: 18.r,
                            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                            child: Icon(
                              Icons.class_,
                              color: const Color(0xFF2563EB),
                              size: 16.w,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Row(
                                  children: [
                                    Text(
                                      period.name,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    Text(
                                      '  ·  ${item.studentCount} Siswa',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: const Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600,
                                      ),
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
                                _actionIcon(
                                  Icons.visibility_outlined,
                                  Colors.blue,
                                  () => context.push('/admin/master-data/classes/${item.id}/students'),
                                ),
                                _actionIcon(
                                  Icons.edit_outlined,
                                  Colors.indigo,
                                  () => _showFormDialog(classItem: item),
                                ),
                                _actionIcon(
                                  Icons.delete_outline,
                                  Colors.red,
                                  () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Hapus Kelas'),
                                        content: const Text(
                                          'Apakah Anda yakin ingin menghapus kelas ini?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Batal'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text(
                                              'Hapus',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) _handleDelete(item.id);
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
