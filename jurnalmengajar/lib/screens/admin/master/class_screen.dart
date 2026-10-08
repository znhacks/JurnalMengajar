import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../models/class_model.dart';
import '../../../models/period_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/admin_search_filter_bar.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';
import '../../../widgets/animated_widgets.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/excel_export_service.dart';
import '../../../widgets/student_import_modal.dart';

class MasterClassScreen extends StatefulWidget {
  const MasterClassScreen({super.key});

  @override
  State<MasterClassScreen> createState() => _MasterClassScreenState();
}

class _MasterClassScreenState extends State<MasterClassScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedPeriodId = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  bool _isExporting = false;

  Future<void> _handleExportExcel(List<ClassModel> classes, MasterDataProvider master, AuthProvider auth) async {
    if (_isExporting) return;
    if (classes.isEmpty) {
      AppHelper.showSnackBar(context, 'Tidak ada data kelas untuk diekspor.', isError: true);
      return;
    }

    setState(() => _isExporting = true);
    AppHelper.showSnackBar(context, 'Mempersiapkan file Excel...');

    try {
      final schoolName = auth.activeSchoolName.isNotEmpty ? auth.activeSchoolName : 'Sekolah';
      await ExcelExportService.exportClasses(
        classes: classes,
        masterProvider: master,
        schoolName: schoolName,
      );
      if (mounted) {
        AppHelper.showSnackBar(context, 'Data berhasil diekspor ke Excel.');
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Ekspor gagal. Silakan coba lagi.', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _refreshData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData(authProvider.activeSchoolId);
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

                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                      final activeSchoolId = authProvider.activeSchoolId ?? masterProvider.currentSchoolId;
                      bool success;

                      if (classItem == null) {
                        success = await masterProvider.createClass(
                          ClassModel(
                            id: '',
                            periodId: selectedPeriodId!,
                            name: nameController.text.trim(),
                            studentCount: 0,
                            schoolId: activeSchoolId,
                          ),
                        );
                      } else {
                        success = await masterProvider.updateClass(
                          classItem.copyWith(
                            periodId: selectedPeriodId!,
                            name: nameController.text.trim(),
                            schoolId: activeSchoolId ?? classItem.schoolId,
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

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final classes = masterProvider.classes;

    final filteredClasses = classes.where((c) {
      final matchesSearch = _searchQuery.isEmpty || c.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesPeriod = _selectedPeriodId == 'all' || c.periodId == _selectedPeriodId;
      return matchesSearch && matchesPeriod;
    }).toList();

    final filterItems = [
      AdminFilterItem(id: 'all', label: 'Semua', count: classes.length),
      ...masterProvider.periods.map((p) => AdminFilterItem(
        id: p.id,
        label: p.name + (p.isActive ? ' (Aktif)' : ''),
        count: classes.where((c) => c.periodId == p.id).length,
      )),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/admin/dashboard');
      },
      child: Scaffold(
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
                    icon: const Icon(
                      Icons.checklist_rounded,
                      color: Colors.white,
                    ),
                    tooltip: _selectedIds.length == filteredClasses.length ? 'Batal Pilih Semua' : 'Pilih Semua',
                    onPressed: () => _selectAll(filteredClasses),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: 'Hapus Massal',
                    onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                  ),
                ],
              )
            : AppBar(
                leading: Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                ),
                title: const Text('Kelas & Siswa'),
                actions: [
                  if (_isExporting)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Center(
                        child: SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                        ),
                      ),
                    ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    tooltip: 'Opsi Lainnya',
                    onSelected: (value) {
                      switch (value) {
                        case 'import_excel':
                          StudentImportModal.show(
                            context,
                            availableClasses: classes,
                            onImportSuccess: _refreshData,
                          );
                          break;
                        case 'export_excel':
                          final authProvider = Provider.of<AuthProvider>(context, listen: false);
                          _handleExportExcel(classes, masterProvider, authProvider);
                          break;
                        case 'promotions':
                          context.push('/admin/master-data/student-promotions');
                          break;
                        case 'batch_select':
                          _toggleSelectionMode();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'import_excel',
                        enabled: classes.isNotEmpty,
                        child: Row(
                          children: [
                            Icon(
                              Icons.file_upload_outlined,
                              color: classes.isNotEmpty ? const Color(0xFF2563EB) : Colors.grey,
                              size: 20.r,
                            ),
                            SizedBox(width: 12.w),
                            const Text('Impor Siswa Excel'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export_excel',
                        enabled: !_isExporting && classes.isNotEmpty,
                        child: Row(
                          children: [
                            Icon(
                              Icons.table_view_rounded,
                              color: (!_isExporting && classes.isNotEmpty) ? const Color(0xFF10B981) : Colors.grey,
                              size: 20.r,
                            ),
                            SizedBox(width: 12.w),
                            const Text('Ekspor Excel'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'promotions',
                        child: Row(
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              color: const Color(0xFFF59E0B),
                              size: 20.r,
                            ),
                            SizedBox(width: 12.w),
                            const Text('Kenaikan & Mutasi Kelas'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'batch_select',
                        enabled: classes.isNotEmpty,
                        child: Row(
                          children: [
                            Icon(
                              Icons.checklist_rounded,
                              color: classes.isNotEmpty ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                              size: 20.r,
                            ),
                            SizedBox(width: 12.w),
                            const Text('Pilih Massal'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/classes'),
      body: masterProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
              ? const AppEmptyWidget(
                  title: 'Kelas Kosong',
                  subtitle: 'Tekan tombol + di bawah untuk menambah kelas.',
                )
              : Column(
                  children: [
                    AdminSearchFilterBar(
                      hintText: 'Cari nama kelas...',
                      searchController: _searchController,
                      onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                      filterItems: filterItems,
                      selectedFilterId: _selectedPeriodId,
                      onFilterSelected: (id) => setState(() => _selectedPeriodId = id),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshData,
                        color: const Color(0xFF2563EB),
                        child: filteredClasses.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: 60.h),
                                  const AppEmptyWidget(
                                    title: 'Kelas Tidak Ditemukan',
                                    subtitle: 'Tidak ada data kelas yang cocok dengan pencarian atau filter.',
                                    icon: Icons.search_off_rounded,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: EdgeInsets.all(16.w),
                                itemCount: filteredClasses.length,
                                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                                itemBuilder: (context, index) {
                                  final item = filteredClasses[index];
                  final period = masterProvider.periods.firstWhere(
                    (p) => p.id == item.periodId,
                    orElse: () =>
                        PeriodModel(id: '', name: 'Periode--', isActive: false),
                  );
                  final isSelected = _selectedIds.contains(item.id);
                  final isDark = Theme.of(context).brightness == Brightness.dark;

                  return FadeSlideIn(
                    delay: Duration(milliseconds: (index * 40).clamp(0, 400)),
                    child: ScaleTap(
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
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                              : (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                                    color: Theme.of(context).colorScheme.onSurface,
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
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded),
                              tooltip: 'Opsi Kelas',
                              padding: EdgeInsets.zero,
                              onSelected: (value) async {
                                switch (value) {
                                  case 'view_students':
                                    context.push('/admin/master-data/classes/${item.id}/students');
                                    break;
                                  case 'promotions':
                                    context.push('/admin/master-data/student-promotions?classId=${item.id}');
                                    break;
                                  case 'import_students':
                                    StudentImportModal.show(
                                      context,
                                      initialClass: item,
                                      availableClasses: classes,
                                      onImportSuccess: _refreshData,
                                    );
                                    break;
                                  case 'edit':
                                    _showFormDialog(classItem: item);
                                    break;
                                  case 'delete':
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
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'view_students',
                                  child: Row(
                                    children: [
                                      Icon(Icons.visibility_outlined, color: Colors.blue, size: 20.r),
                                      SizedBox(width: 12.w),
                                      const Text('Lihat Siswa'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'promotions',
                                  child: Row(
                                    children: [
                                      Icon(Icons.trending_up_rounded, color: const Color(0xFFF59E0B), size: 20.r),
                                      SizedBox(width: 12.w),
                                      const Text('Kenaikan / Mutasi Kelas'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'import_students',
                                  child: Row(
                                    children: [
                                      Icon(Icons.file_upload_outlined, color: const Color(0xFF0D9488), size: 20.r),
                                      SizedBox(width: 12.w),
                                      const Text('Impor Siswa ke Kelas Ini'),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, color: Colors.indigo, size: 20.r),
                                      SizedBox(width: 12.w),
                                      const Text('Edit Kelas'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, color: Colors.red, size: 20.r),
                                      SizedBox(width: 12.w),
                                      const Text(
                                        'Hapus Kelas',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    ),
  );
}
}
