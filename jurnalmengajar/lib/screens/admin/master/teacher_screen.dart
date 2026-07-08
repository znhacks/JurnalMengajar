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
                    enabled: teacher == null, // Email is matching login key, disabled on edit
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

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final teachers = masterProvider.teachers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Data Guru'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/teachers'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0D9488),
        child: masterProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : teachers.isEmpty
                ? const AppEmptyWidget(
                    title: 'Guru Kosong',
                    subtitle: 'Tekan tombol + di bawah untuk menambah data guru.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: teachers.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final t = teachers[index];
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
                              content: const Text('Apakah Anda yakin ingin menghapus data guru ini? Akun login guru tersebut juga akan dihapus.'),
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
                                    : (t.photoUrl != null
                                        ? FileImage(File(t.photoUrl!))
                                        : null) as ImageProvider?,
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
                                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      t.position,
                                      style: TextStyle(fontSize: 12.sp, color: const Color(0xFF0D9488), fontWeight: FontWeight.bold),
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
