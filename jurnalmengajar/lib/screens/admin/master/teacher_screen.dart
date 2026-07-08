import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/master_data_provider.dart';
import '../../../models/teacher_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';

class MasterTeacherScreen extends StatefulWidget {
  const MasterTeacherScreen({super.key});

  @override
  State<MasterTeacherScreen> createState() => _MasterTeacherScreenState();
}

class _MasterTeacherScreenState extends State<MasterTeacherScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
  }

  void _showFormDialog({TeacherModel? teacher}) {
    final nameController = TextEditingController(text: teacher?.name ?? '');
    final posController = TextEditingController(text: teacher?.position ?? '');
    final phoneController = TextEditingController(text: teacher?.phoneNumber ?? '');
    final emailController = TextEditingController(text: teacher?.email ?? '');
    final addressController = TextEditingController(text: teacher?.address ?? '');
    File? tempImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDialogImage() async {
            final XFile? img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
            if (img != null) {
              setDialogState(() {
                tempImage = File(img.path);
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
                    teacher == null ? 'Tambah Guru Baru' : 'Edit Data Guru',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),

                  // Teacher Photo selection
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44.r,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: tempImage != null
                              ? FileImage(tempImage!)
                              : (teacher?.photoUrl != null && teacher!.photoUrl!.startsWith('http')
                                  ? NetworkImage(teacher.photoUrl!)
                                  : (teacher?.photoUrl != null
                                      ? FileImage(File(teacher!.photoUrl!))
                                      : null)) as ImageProvider?,
                          child: tempImage == null && teacher?.photoUrl == null
                              ? Icon(Icons.person, size: 44.r, color: Colors.grey[400])
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: pickDialogImage,
                            child: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: const BoxDecoration(color: Color(0xFF0D9488), shape: BoxShape.circle),
                              child: Icon(Icons.camera_alt, size: 14.r, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap', hintText: 'Nama lengkap beserta gelar'),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: posController,
                    decoration: const InputDecoration(labelText: 'Jabatan', hintText: 'Contoh: Guru Fisika'),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Nomor Telepon', hintText: 'Contoh: 08123456789'),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: teacher == null,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Contoh: guru@jurnal.com',
                      helperText: 'Email digunakan guru untuk login (default pass: password123)',
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Alamat', hintText: 'Alamat lengkap rumah'),
                  ),
                  SizedBox(height: 24.h),

                  ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        AppHelper.showSnackBar(context, 'Nama guru tidak boleh kosong', isError: true);
                        return;
                      }
                      if (emailController.text.trim().isEmpty) {
                        AppHelper.showSnackBar(context, 'Email tidak boleh kosong', isError: true);
                        return;
                      }

                      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                      bool success;

                      if (teacher == null) {
                        success = await masterProvider.createTeacher(TeacherModel(
                          id: '',
                          name: nameController.text.trim(),
                          position: posController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          email: emailController.text.trim(),
                          address: addressController.text.trim(),
                          photoUrl: tempImage?.path,
                        ));
                      } else {
                        success = await masterProvider.updateTeacher(teacher.copyWith(
                          name: nameController.text.trim(),
                          position: posController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                          address: addressController.text.trim(),
                          photoUrl: tempImage?.path ?? teacher.photoUrl,
                        ));
                      }

                      if (success && context.mounted) {
                        AppHelper.showSnackBar(context, 'Data guru berhasil disimpan!');
                        Navigator.pop(context);
                      } else if (context.mounted) {
                        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menyimpan data guru.', isError: true);
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
    final success = await masterProvider.deleteTeacher(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Data guru berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus data guru.', isError: true);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    if (phone.trim().isEmpty) {
      AppHelper.showSnackBar(context, 'Nomor WhatsApp belum terdaftar', isError: true);
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }

    final url = Uri.parse('https://wa.me/$cleanPhone');
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        AppHelper.showSnackBar(context, 'Tidak dapat membuka WhatsApp', isError: true);
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Gagal membuka link WhatsApp', isError: true);
      }
    }
  }

  /// Group teachers by position, applying search filter first.
  Map<String, List<TeacherModel>> _buildGroups(List<TeacherModel> teachers) {
    final filtered = _searchQuery.isEmpty
        ? teachers
        : teachers.where((t) {
            return t.name.toLowerCase().contains(_searchQuery) ||
                t.position.toLowerCase().contains(_searchQuery) ||
                t.email.toLowerCase().contains(_searchQuery);
          }).toList();

    final Map<String, List<TeacherModel>> groups = {};
    for (final t in filtered) {
      final key = t.position.trim().isEmpty ? 'Lainnya' : t.position.trim();
      groups.putIfAbsent(key, () => []).add(t);
    }

    // Sort keys alphabetically, but put 'Lainnya' at the end
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'Lainnya') return 1;
        if (b == 'Lainnya') return -1;
        return a.compareTo(b);
      });

    return {for (final k in sortedKeys) k: groups[k]!};
  }

  Widget _buildTeacherCard(TeacherModel t) {
    return Dismissible(
      key: Key(t.id),
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
      onDismissed: (_) => _handleDelete(t.id),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Guru'),
            content: const Text(
                'Apakah Anda yakin ingin menghapus data guru ini? Akun login guru tersebut juga akan dihapus.'),
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
              radius: 24.r,
              backgroundColor: const Color(0xFFF1F5F9),
              backgroundImage: t.photoUrl != null && t.photoUrl!.startsWith('http')
                  ? NetworkImage(t.photoUrl!)
                  : (t.photoUrl != null ? FileImage(File(t.photoUrl!)) : null) as ImageProvider?,
              child: t.photoUrl == null
                  ? Icon(Icons.person, size: 24.r, color: Colors.grey[400])
                  : null,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.name,
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    t.email,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chat,
                color: t.phoneNumber.trim().isEmpty ? Colors.grey[400] : const Color(0xFF25D366),
              ),
              onPressed: () => _launchWhatsApp(t.phoneNumber),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
              onPressed: () => _showFormDialog(teacher: t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0D9488),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count guru',
              style: TextStyle(
                fontSize: 11.sp,
                color: const Color(0xFF0D9488),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final teachers = masterProvider.teachers;
    final groups = _buildGroups(teachers);
    final hasResults = groups.isNotEmpty;

    // Build a flat list of items: [header, card, card, ..., header, card, ...]
    final List<Widget> listItems = [];
    groups.forEach((category, categoryTeachers) {
      listItems.add(_buildGroupHeader(category, categoryTeachers.length));
      for (final t in categoryTeachers) {
        listItems.add(Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: _buildTeacherCard(t),
        ));
      }
      listItems.add(SizedBox(height: 4.h));
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Data Guru'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/teachers'),
      body: Column(
        children: [
          // --- Search Bar ---
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari guru berdasarkan nama, jabatan, atau email...',
                hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20.r),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18.r, color: Colors.grey[400]),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5),
                ),
              ),
            ),
          ),

          // --- List ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF0D9488),
              child: masterProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : teachers.isEmpty
                      ? const AppEmptyWidget(
                          title: 'Guru Kosong',
                          subtitle: 'Tekan tombol + di bawah untuk menambah data guru.',
                        )
                      : !hasResults
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off, size: 48.r, color: Colors.grey[300]),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'Tidak ada guru yang cocok',
                                      style: TextStyle(
                                          fontSize: 14.sp, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      '"$_searchQuery"',
                                      style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
                              children: listItems,
                            ),
            ),
          ),
        ],
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
