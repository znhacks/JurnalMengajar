import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/utils/helper.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
  }

  Future<void> _handleDeleteAccount(UserModel user) async {
    // Safety check for main admin
    if (user.email.toLowerCase() == 'admin@jurnal.com') {
      AppHelper.showSnackBar(
        context, 
        'Akun admin utama (admin@jurnal.com) tidak dapat dihapus.', 
        isError: true
      );
      return;
    }

    final confirmed1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAPUS AKUN ANDA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'Apakah Anda yakin ingin menghapus akun administrator Anda secara permanen? '
          'Seluruh data Anda akan terhapus dan Anda akan langsung dikeluarkan dari aplikasi.'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjutkan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed1 == true && mounted) {
      final confirmed2 = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi Terakhir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: const Text(
            'TINDAKAN INI TIDAK BISA DIBATALKAN. Apakah Anda benar-benar yakin ingin menghapus akun Anda sekarang?'
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Kembali')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('HAPUS AKUN SAYA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirmed2 == true && mounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.deleteAccount(user.id);
        if (success && mounted) {
          AppHelper.showSnackBar(context, 'Akun Anda berhasil dihapus.');
        } else if (mounted) {
          AppHelper.showSnackBar(
            context, 
            authProvider.errorMessage ?? 'Gagal menghapus akun.', 
            isError: true
          );
        }
      }
    }
  }

  void _showEditProfileDialog(UserModel user) {
    final nameController = TextEditingController(text: user.fullName);
    final posController = TextEditingController(text: user.position ?? 'Administrator');
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final addrController = TextEditingController(text: user.address ?? '');
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
                    'Edit Profil Admin',
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
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    final isSuperAdmin = currentUser.email.toLowerCase() == 'admin@jurnal.com';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Administrator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar dari halaman Administrator?'),
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
      drawer: const AdminDrawer(currentRoute: '/admin/profile'),
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
                        backgroundImage: currentUser.photoUrl != null && currentUser.photoUrl!.startsWith('http')
                            ? NetworkImage(currentUser.photoUrl!)
                            : (currentUser.photoUrl != null
                                ? FileImage(File(currentUser.photoUrl!))
                                : null) as ImageProvider?,
                        child: currentUser.photoUrl == null
                            ? Icon(Icons.person, size: 54.r, color: Colors.grey[400])
                            : null,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        currentUser.fullName,
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        currentUser.position ?? 'Administrator',
                        style: TextStyle(fontSize: 14.sp, color: const Color(0xFF4F46E5), fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ROLE: ADMIN',
                          style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5)),
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
                      _buildProfileDetailItem(Icons.badge_outlined, 'Jabatan / Posisi', currentUser.position ?? 'Administrator'),
                      const Divider(height: 24),
                      _buildProfileDetailItem(Icons.email_outlined, 'Email', currentUser.email),
                      const Divider(height: 24),
                      _buildProfileDetailItem(Icons.phone_outlined, 'No. Telepon', currentUser.phoneNumber ?? 'Belum Diisi'),
                      const Divider(height: 24),
                      _buildProfileDetailItem(Icons.home_outlined, 'Alamat', currentUser.address ?? 'Belum Diisi'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Edit Button
              ElevatedButton.icon(
                onPressed: () => _showEditProfileDialog(currentUser),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Profil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(height: 20.h),

              // Danger Zone Panel
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                ),
                color: const Color(0xFFFFF5F5),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          SizedBox(width: 8.w),
                          Text(
                            'Zona Bahaya (Danger Zone)',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        isSuperAdmin 
                          ? 'Akun administrator utama (admin@jurnal.com) dilindungi sistem dan tidak dapat dihapus.'
                          : 'Tindakan berikut akan menghapus akun administrator Anda secara permanen. Seluruh data autentikasi dan profil Anda akan terhapus.',
                        style: TextStyle(fontSize: 12.sp, color: Colors.red[700], height: 1.4),
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: isSuperAdmin ? null : () => _handleDeleteAccount(currentUser),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Hapus Akun Saya'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            disabledForegroundColor: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
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
