import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../models/user_model.dart';
import '../../models/teacher_model.dart';
import '../../core/utils/helper.dart';

class GuruProfilScreen extends StatefulWidget {
  const GuruProfilScreen({super.key});

  @override
  State<GuruProfilScreen> createState() => _GuruProfilScreenState();
}

class _GuruProfilScreenState extends State<GuruProfilScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    // Router redirection handles steering to login
  }

  void _showEditProfileDialog(UserModel user, TeacherModel teacher) {
    final nameController = TextEditingController(text: user.fullName);
    final posController = TextEditingController(text: user.position ?? teacher.position);
    final phoneController = TextEditingController(text: user.phoneNumber ?? teacher.phoneNumber);
    final addrController = TextEditingController(text: user.address ?? teacher.address);
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
                    'Edit Profil Anda',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  
                  // Avatar edit
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44.r,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: tempImage != null
                              ? FileImage(tempImage!)
                              : (user.photoUrl != null && user.photoUrl!.startsWith('http')
                                  ? NetworkImage(user.photoUrl!)
                                  : null) as ImageProvider?,
                          child: tempImage == null && user.photoUrl == null
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
                  SizedBox(height: 20.h),

                  // Fields
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap', hintText: 'Masukkan nama lengkap'),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: posController,
                    decoration: const InputDecoration(labelText: 'Jabatan', hintText: 'Masukkan jabatan'),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Nomor Telepon', hintText: 'Masukkan nomor telepon'),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: addrController,
                    decoration: const InputDecoration(labelText: 'Alamat', hintText: 'Masukkan alamat rumah'),
                  ),
                  SizedBox(height: 24.h),

                  ElevatedButton(
                    onPressed: () async {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);

                      final updatedUser = user.copyWith(
                        fullName: nameController.text.trim(),
                        position: posController.text.trim(),
                        phoneNumber: phoneController.text.trim(),
                        address: addrController.text.trim(),
                        photoUrl: tempImage?.path ?? user.photoUrl,
                      );

                      final success = await authProvider.updateProfile(updatedUser);
                      if (success) {
                        // Reload master data to update corresponding teacher details cache
                        await masterProvider.loadAllData();
                        if (context.mounted) {
                          AppHelper.showSnackBar(context, 'Profil berhasil diperbarui!');
                          Navigator.pop(context);
                        }
                      } else {
                        if (context.mounted) {
                          AppHelper.showSnackBar(context, authProvider.errorMessage ?? 'Gagal memperbarui profil.', isError: true);
                        }
                      }
                    },
                    child: const Text('Simpan Perubahan'),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
      orElse: () => TeacherModel(
        id: '',
        name: currentUser.fullName,
        position: currentUser.position ?? 'Guru',
        address: currentUser.address ?? 'Belum Diisi',
        phoneNumber: currentUser.phoneNumber ?? 'Belum Diisi',
        email: currentUser.email,
        photoUrl: currentUser.photoUrl,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pengajar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Card Header
              Card(
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 16.w),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 54.r,
                        backgroundColor: const Color(0xFFF1F5F9),
                        backgroundImage: teacher.photoUrl != null && teacher.photoUrl!.startsWith('http')
                            ? NetworkImage(teacher.photoUrl!)
                            : (teacher.photoUrl != null
                                ? FileImage(File(teacher.photoUrl!))
                                : null) as ImageProvider?,
                        child: teacher.photoUrl == null
                            ? Icon(Icons.person, size: 54.r, color: Colors.grey[400])
                            : null,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        teacher.name,
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        teacher.position,
                        style: TextStyle(fontSize: 14.sp, color: const Color(0xFF0D9488), fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ROLE: ${currentUser.role.toUpperCase()}',
                          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Detail List Card
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      _buildProfileDetailItem(Icons.badge_outlined, 'NIP / Jabatan', teacher.position),
                      const Divider(height: 24),
                      _buildProfileDetailItem(Icons.email_outlined, 'Email', teacher.email),
                      const Divider(height: 24),
                      _buildProfileDetailItem(Icons.phone_outlined, 'No. Telepon', teacher.phoneNumber),
                      const Divider(height: 24),
                      _buildProfileDetailItem(Icons.home_outlined, 'Alamat Lengkap', teacher.address),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Edit Button
              ElevatedButton.icon(
                onPressed: () => _showEditProfileDialog(currentUser, teacher),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Profil'),
              ),
              SizedBox(height: 12.h),
              OutlinedButton.icon(
                onPressed: () => context.push('/about'),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Tentang Aplikasi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D9488),
                  side: const BorderSide(color: Color(0xFF0D9488)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailItem(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22.w, color: const Color(0xFF0D9488)),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: TextStyle(fontSize: 14.sp, color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
