import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../models/subject_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';

class MasterSubjectScreen extends StatefulWidget {
  const MasterSubjectScreen({super.key});

  @override
  State<MasterSubjectScreen> createState() => _MasterSubjectScreenState();
}

class _MasterSubjectScreenState extends State<MasterSubjectScreen> {
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

  void _selectAll(List<SubjectModel> allSubjects) {
    setState(() {
      if (_selectedIds.length == allSubjects.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allSubjects.map((s) => s.id));
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $count Mata Pelajaran', style: const TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menghapus $count mata pelajaran yang dipilih?'),
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
      final success = await masterProvider.deleteMultipleSubjects(idsToDelete);
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count mata pelajaran berhasil dihapus.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus mata pelajaran.', isError: true);
      }
    }
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
  }

  void _showFormDialog({SubjectModel? subject}) {
    final nameController = TextEditingController(text: subject?.name ?? '');
    bool isActive = subject?.isActive ?? true;

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
                    subject == null ? 'Tambah Mata Pelajaran Baru' : 'Edit Mata Pelajaran',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Mata Pelajaran',
                      hintText: 'Contoh: Matematika Peminatan',
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SwitchListTile(
                    title: const Text('Status Aktif'),
                    subtitle: const Text('Apakah mata pelajaran ini aktif digunakan saat ini'),
                    value: isActive,
                    activeThumbColor: const Color(0xFF2563EB),
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
                        AppHelper.showSnackBar(context, 'Nama pelajaran tidak boleh kosong', isError: true);
                        return;
                      }

                      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                      bool success;

                      if (subject == null) {
                        success = await masterProvider.createSubject(SubjectModel(
                          id: '',
                          name: nameController.text.trim(),
                          isActive: isActive,
                        ));
                      } else {
                        success = await masterProvider.updateSubject(subject.copyWith(
                          name: nameController.text.trim(),
                          isActive: isActive,
                        ));
                      }

                      if (success && context.mounted) {
                        AppHelper.showSnackBar(context, 'Mata pelajaran berhasil disimpan!');
                        Navigator.pop(context);
                      } else if (context.mounted) {
                        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menyimpan mata pelajaran.', isError: true);
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
    final success = await masterProvider.deleteSubject(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Mata pelajaran berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus mata pelajaran.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final subjects = masterProvider.subjects;

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
                    _selectedIds.length == subjects.length ? Icons.deselect : Icons.select_all,
                    color: Colors.white,
                  ),
                  tooltip: _selectedIds.length == subjects.length ? 'Batal Pilih Semua' : 'Pilih Semua',
                  onPressed: () => _selectAll(subjects),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus Massal',
                  onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                ),
              ],
            )
          : AppBar(
              title: const Text('Master Pelajaran'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Pilih Massal',
                  onPressed: subjects.isEmpty ? null : () => _toggleSelectionMode(),
                ),
              ],
            ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/subjects'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2563EB),
        child: masterProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : subjects.isEmpty
                ? const AppEmptyWidget(
                    title: 'Mata Pelajaran Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah daftar pelajaran.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: subjects.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final subject = subjects[index];
                      final isSelected = _selectedIds.contains(subject.id);

                      return InkWell(
                        onTap: _isSelectionMode ? () => _toggleSelectItem(subject.id) : null,
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode(initialId: subject.id);
                          } else {
                            _toggleSelectItem(subject.id);
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
                                  onChanged: (_) => _toggleSelectItem(subject.id),
                                ),
                                SizedBox(width: 4.w),
                              ],
                              CircleAvatar(
                                backgroundColor: subject.isActive ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                child: Icon(
                                  subject.isActive ? Icons.menu_book : Icons.block,
                                  color: subject.isActive ? const Color(0xFF2563EB) : Colors.red,
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject.name,
                                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      subject.isActive ? 'Aktif' : 'Tidak Aktif',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: subject.isActive ? const Color(0xFF2563EB) : Colors.red,
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
                                      onPressed: () => _showFormDialog(subject: subject),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Hapus Pelajaran'),
                                            content: const Text('Apakah Anda yakin ingin menghapus mata pelajaran ini?'),
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
                                          _handleDelete(subject.id);
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
