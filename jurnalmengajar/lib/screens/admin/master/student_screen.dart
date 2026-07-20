import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../providers/master_data_provider.dart';
import '../../../models/student_model.dart';
import '../../../models/class_model.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/animated_widgets.dart';

class MasterStudentScreen extends StatefulWidget {
  final String classId;
  const MasterStudentScreen({super.key, required this.classId});

  @override
  State<MasterStudentScreen> createState() => _MasterStudentScreenState();
}

class _MasterStudentScreenState extends State<MasterStudentScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
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

  void _selectAll(List<StudentModel> allStudents) {
    setState(() {
      if (_selectedIds.length == allStudents.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allStudents.map((s) => s.id));
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $count Data Siswa', style: const TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menghapus $count data siswa yang dipilih secara permanen?'),
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
      final success = await masterProvider.deleteMultipleStudents(idsToDelete, widget.classId);
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count data siswa berhasil dihapus.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus data siswa.', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false)
        .loadStudentsForClass(widget.classId);
  }

  void _showFormDialog({StudentModel? studentItem}) {
    final nameController = TextEditingController(text: studentItem?.name ?? '');
    final nisController = TextEditingController(text: studentItem?.nis ?? '');
    final parentPhoneController = TextEditingController(text: studentItem?.parentPhoneNumber ?? '');
    String selectedGender = studentItem?.gender ?? 'L'; // Default Laki-laki

    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pull handler line
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: AppTheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    studentItem == null ? 'Tambah Siswa Baru' : 'Edit Data Siswa',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.onBackground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),

                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap Siswa',
                      hintText: 'Masukkan nama lengkap siswa',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.outlineVariant),
                      ),
                    ),
                    style: GoogleFonts.hankenGrotesk(fontSize: 14.sp),
                  ),
                  SizedBox(height: 16.h),

                  // NIS Field
                  TextField(
                    controller: nisController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nomor Induk Siswa (NIS)',
                      hintText: 'Masukkan NIS siswa (opsional)',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.outlineVariant),
                      ),
                    ),
                    style: GoogleFonts.hankenGrotesk(fontSize: 14.sp),
                  ),
                  SizedBox(height: 16.h),

                  // Parent Phone Field
                  TextField(
                    controller: parentPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Nomor Telepon Orang Tua',
                      hintText: 'Masukkan No. HP ortu (opsional)',
                      prefixIcon: const Icon(Icons.phone_android_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.outlineVariant),
                      ),
                    ),
                    style: GoogleFonts.hankenGrotesk(fontSize: 14.sp),
                  ),
                  SizedBox(height: 16.h),

                  // Gender Selection (Premium Chips)
                  Text(
                    'Jenis Kelamin',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Container(
                            alignment: Alignment.center,
                            width: double.infinity,
                            child: Text(
                              'Laki-laki',
                              style: GoogleFonts.hankenGrotesk(
                                fontWeight: FontWeight.bold,
                                color: selectedGender == 'L'
                                    ? Colors.white
                                    : AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          selected: selectedGender == 'L',
                          selectedColor: AppTheme.primaryColor,
                          backgroundColor: AppTheme.surfaceContainerLow,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedGender = 'L';
                              });
                            }
                          },
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: ChoiceChip(
                          label: Container(
                            alignment: Alignment.center,
                            width: double.infinity,
                            child: Text(
                              'Perempuan',
                              style: GoogleFonts.hankenGrotesk(
                                fontWeight: FontWeight.bold,
                                color: selectedGender == 'P'
                                    ? Colors.white
                                    : AppTheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          selected: selectedGender == 'P',
                          selectedColor: const Color(0xFFEC4899), // Pink for females
                          backgroundColor: AppTheme.surfaceContainerLow,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() {
                                selectedGender = 'P';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 28.h),

                  // Save Button
                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        AppHelper.showSnackBar(context, 'Nama siswa tidak boleh kosong', isError: true);
                        return;
                      }

                      bool success;
                      final newStudent = StudentModel(
                        id: studentItem?.id ?? '',
                        classId: widget.classId,
                        name: nameController.text.trim(),
                        nis: nisController.text.trim().isEmpty ? null : nisController.text.trim(),
                        gender: selectedGender,
                        parentPhoneNumber: parentPhoneController.text.trim().isEmpty ? null : parentPhoneController.text.trim(),
                      );

                      if (studentItem == null) {
                        success = await masterProvider.createStudent(newStudent);
                      } else {
                        success = await masterProvider.updateStudent(newStudent);
                      }

                      if (success && context.mounted) {
                        AppHelper.showSnackBar(context, 'Data siswa berhasil disimpan!');
                        Navigator.pop(context);
                      } else if (context.mounted) {
                        AppHelper.showSnackBar(
                          context,
                          masterProvider.errorMessage ?? 'Gagal menyimpan data siswa.',
                          isError: true,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Simpan Data',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
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
    final success = await masterProvider.deleteStudent(id, widget.classId);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Data siswa berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(
        context,
        masterProvider.errorMessage ?? 'Gagal menghapus data siswa.',
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
    final cls = masterProvider.classes.firstWhere(
      (c) => c.id == widget.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );

    final filteredStudents = masterProvider.students.where((s) {
      final nameMatch = s.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final nisMatch = s.nis?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
      return nameMatch || nisMatch;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
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
                    _selectedIds.length == filteredStudents.length ? Icons.deselect : Icons.select_all,
                    color: Colors.white,
                  ),
                  tooltip: _selectedIds.length == filteredStudents.length ? 'Batal Pilih Semua' : 'Pilih Semua',
                  onPressed: () => _selectAll(filteredStudents),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus Massal',
                  onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                ),
              ],
            )
          : AppBar(
              title: Text(
                'Daftar Siswa',
                style: GoogleFonts.hankenGrotesk(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onBackground,
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppTheme.onBackground),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Pilih Massal',
                  onPressed: filteredStudents.isEmpty ? null : () => _toggleSelectionMode(),
                ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryColor,
        child: masterProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Class summary header card
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          cls.name,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${filteredStudents.length} Siswa Terdaftar',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau NIS siswa...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.outlineVariant),
                        ),
                      ),
                      style: GoogleFonts.hankenGrotesk(fontSize: 13.sp),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // List of students
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? ListView(
                            children: [
                              SizedBox(height: 50.h),
                              AppEmptyWidget(
                                title: _searchQuery.isEmpty ? 'Siswa Kosong' : 'Siswa Tidak Ditemukan',
                                subtitle: _searchQuery.isEmpty
                                    ? 'Belum ada data siswa di kelas ini. Ketuk tombol + di bawah untuk menambah.'
                                    : 'Tidak ada siswa yang cocok dengan kata pencarian Anda.',
                                icon: Icons.people_outline_rounded,
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                            itemCount: filteredStudents.length,
                            separatorBuilder: (context, _) => SizedBox(height: 12.h),
                            itemBuilder: (context, index) {
                              final student = filteredStudents[index];
                              final isMale = student.gender == 'L';
                              final genderColor = isMale ? const Color(0xFF2563EB) : const Color(0xFFEC4899);
                              final isSelected = _selectedIds.contains(student.id);

                              return FadeSlideIn(
                                delay: Duration(milliseconds: (index * 35).clamp(0, 400)),
                                child: ScaleTap(
                                  onTap: _isSelectionMode
                                      ? () => _toggleSelectItem(student.id)
                                      : null,
                                  onLongPress: () {
                                    if (!_isSelectionMode) {
                                      _toggleSelectionMode(initialId: student.id);
                                    } else {
                                      _toggleSelectItem(student.id);
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF2563EB) : AppTheme.outlineVariant,
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                    children: [
                                      if (_isSelectionMode) ...[
                                        Checkbox(
                                          value: isSelected,
                                          activeColor: const Color(0xFF2563EB),
                                          onChanged: (_) => _toggleSelectItem(student.id),
                                        ),
                                        SizedBox(width: 4.w),
                                      ],
                                      // Initials avatar
                                      CircleAvatar(
                                        radius: 17.r,
                                        backgroundColor: genderColor.withValues(alpha: 0.1),
                                        child: Text(
                                          student.name.isNotEmpty
                                              ? student.name.substring(0, 1).toUpperCase()
                                              : 'S',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontWeight: FontWeight.bold,
                                            color: genderColor,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10.w),

                                      // Student details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              student.name,
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.onBackground,
                                              ),
                                            ),
                                            SizedBox(height: 2.h),
                                            Row(
                                              children: [
                                                Text(
                                                  student.nis != null ? 'NIS: ${student.nis}' : 'NIS: -',
                                                  style: GoogleFonts.hankenGrotesk(
                                                    fontSize: 11.sp,
                                                    color: AppTheme.onSurfaceVariant,
                                                  ),
                                                ),
                                                Text(
                                                  '  ·  ${isMale ? 'L' : 'P'}',
                                                  style: GoogleFonts.hankenGrotesk(
                                                    fontSize: 11.sp,
                                                    color: genderColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (student.parentPhoneNumber != null && student.parentPhoneNumber!.isNotEmpty) ...[
                                              SizedBox(height: 2.h),
                                              Text(
                                                'No. Ortu: ${student.parentPhoneNumber}',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 10.sp,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Compact action icons
                                      if (!_isSelectionMode)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _actionIcon(
                                              Icons.edit_outlined,
                                              Colors.indigo,
                                              () => _showFormDialog(studentItem: student),
                                            ),
                                            _actionIcon(
                                              Icons.delete_outline,
                                              Colors.red,
                                              () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (context) => AlertDialog(
                                                    title: const Text('Hapus Siswa'),
                                                    content: Text(
                                                        'Apakah Anda yakin ingin menghapus data ${student.name} secara permanen?'),
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
                                                if (confirm == true) _handleDelete(student.id);
                                              },
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
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
