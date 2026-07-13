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

class MasterStudentScreen extends StatefulWidget {
  final String classId;
  const MasterStudentScreen({super.key, required this.classId});

  @override
  State<MasterStudentScreen> createState() => _MasterStudentScreenState();
}

class _MasterStudentScreenState extends State<MasterStudentScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
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
      appBar: AppBar(
        title: Text(
          'Daftar Siswa',
          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
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
                    margin: EdgeInsets.all(16.w),
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cls.name,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 18.sp,
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
                        SizedBox(height: 8.h),
                        Text(
                          'Kelola data siswa, nomor induk siswa, dan jenis kelamin kelas ${cls.name} di halaman ini.',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.4,
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

                              return Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    // Initials avatar
                                    CircleAvatar(
                                      radius: 20.r,
                                      backgroundColor: genderColor.withValues(alpha: 0.1),
                                      child: Text(
                                        student.name.isNotEmpty
                                            ? student.name.substring(0, 1).toUpperCase()
                                            : 'S',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontWeight: FontWeight.bold,
                                          color: genderColor,
                                          fontSize: 16.sp,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),

                                    // Student details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student.name,
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 14.sp,
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
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Container(
                                                width: 4.w,
                                                height: 4.w,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.outline,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                isMale ? 'Laki-laki' : 'Perempuan',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 11.sp,
                                                  color: genderColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action buttons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
                                          onPressed: () => _showFormDialog(studentItem: student),
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.all(8.w),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          onPressed: () async {
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
                                                    child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              _handleDelete(student.id);
                                            }
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.all(8.w),
                                        ),
                                      ],
                                    ),
                                  ],
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
