import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/utils/helper.dart';
import '../../repositories/supabase_auth_repository.dart';

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
        isError: true,
      );
      return;
    }

    final confirmed1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text(
          'HAPUS AKUN ANDA',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus akun administrator Anda secara permanen? '
          'Seluruh data Anda akan terhapus dan Anda akan langsung dikeluarkan dari aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Lanjutkan',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed1 == true && mounted) {
      final confirmed2 = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: const Text(
            'Konfirmasi Terakhir',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'TINDAKAN INI TIDAK BISA DIBATALKAN. Apakah Anda benar-benar yakin ingin menghapus akun Anda sekarang?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Kembali'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'HAPUS AKUN SAYA',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
            isError: true,
          );
        }
      }
    }
  }

  void _showEditProfileDialog(UserModel user) {
    final nameController = TextEditingController(text: user.fullName);
    final posController = TextEditingController(
      text: user.position ?? 'Administrator',
    );
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final addrController = TextEditingController(text: user.address ?? '');
    Uint8List? tempImageBytes;
    String? tempImageName;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDialogImage() async {
            final XFile? img = await _picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
            );
            if (img != null) {
              final bytes = await img.readAsBytes();
              setDialogState(() {
                tempImageBytes = bytes;
                tempImageName = img.name;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 12.h,
              left: 24.w,
              right: 24.w,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Edit Profil Admin',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20.h),

                  // Avatar edit
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 3.r,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 48.r,
                            backgroundColor: const Color(0xFFF1F5F9),
                            backgroundImage: tempImageBytes != null
                                ? MemoryImage(tempImageBytes!)
                                : (user.photoUrl != null &&
                                              user.photoUrl!.startsWith('http')
                                          ? CachedNetworkImageProvider(user.photoUrl!)
                                          : null)
                                      as ImageProvider?,
                            child: tempImageBytes == null && user.photoUrl == null
                                ? Icon(
                                    Icons.person,
                                    size: 48.r,
                                    color: Colors.grey[400],
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: pickDialogImage,
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: const BoxDecoration(
                                color: Color(0xFF0D9488),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 16.r,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Fields
                  TextField(
                    controller: nameController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      hintText: 'Masukkan nama lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: posController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Jabatan',
                      hintText: 'Masukkan jabatan',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: phoneController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Telepon',
                      hintText: 'Masukkan nomor telepon',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: addrController,
                    enabled: !isSaving,
                    decoration: const InputDecoration(
                      labelText: 'Alamat',
                      hintText: 'Masukkan alamat rumah',
                      prefixIcon: Icon(Icons.home_outlined),
                    ),
                  ),
                  SizedBox(height: 28.h),

                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setDialogState(() {
                              isSaving = true;
                            });

                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            final masterProvider = Provider.of<MasterDataProvider>(
                              context,
                              listen: false,
                            );

                            // Upload foto profil jika ada (web-compatible)
                            String? uploadedPhotoUrl = user.photoUrl;
                            if (tempImageBytes != null &&
                                tempImageName != null &&
                                authProvider.authRepository
                                    is SupabaseAuthRepository) {
                              try {
                                final supabaseRepo =
                                    authProvider.authRepository
                                        as SupabaseAuthRepository;
                                uploadedPhotoUrl = await supabaseRepo
                                    .uploadProfilePhoto(
                                      tempImageBytes!,
                                      tempImageName!,
                                      user.id,
                                    );
                              } catch (e) {
                                if (context.mounted) {
                                  AppHelper.showSnackBar(
                                    context,
                                    'Gagal upload foto: $e',
                                    isError: true,
                                  );
                                }
                                setDialogState(() {
                                  isSaving = false;
                                });
                                return;
                              }
                            }

                            final updatedUser = user.copyWith(
                              fullName: nameController.text.trim(),
                              position: posController.text.trim(),
                              phoneNumber: phoneController.text.trim(),
                              address: addrController.text.trim(),
                              photoUrl: uploadedPhotoUrl,
                            );

                            final success = await authProvider.updateProfile(
                              updatedUser,
                            );
                            if (success) {
                              await masterProvider.loadAllData();
                              if (context.mounted) {
                                AppHelper.showSnackBar(
                                  context,
                                  'Profil berhasil diperbarui!',
                                );
                                Navigator.pop(context);
                              }
                            } else {
                              if (context.mounted) {
                                AppHelper.showSnackBar(
                                  context,
                                  authProvider.errorMessage ??
                                      'Gagal memperbarui profil.',
                                  isError: true,
                                );
                              }
                            }
                            setDialogState(() {
                              isSaving = false;
                            });
                          },
                    child: isSaving
                        ? SizedBox(
                            width: 24.w,
                            height: 24.h,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text('Simpan Perubahan'),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final journalProvider = context.watch<JournalProvider>();
    
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    final isSuperAdmin = currentUser.email.toLowerCase() == 'admin@jurnal.com';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profil Administrator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  title: const Text('Konfirmasi Logout'),
                  content: const Text(
                    'Apakah Anda yakin ingin keluar dari halaman Administrator?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleLogout();
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
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
              // Profile Card Header with Gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 28.h, horizontal: 20.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A), // Slate 900
                      Color(0xFF0D9488), // Teal 600
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 54.r,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: currentUser.photoUrl != null &&
                                    currentUser.photoUrl!.startsWith('http')
                                ? CachedNetworkImageProvider(currentUser.photoUrl!)
                                : null,
                            child: (currentUser.photoUrl == null ||
                                    !currentUser.photoUrl!.startsWith('http'))
                                ? Icon(
                                    Icons.person,
                                    size: 54.r,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 4.w,
                          child: GestureDetector(
                            onTap: () => _showEditProfileDialog(currentUser),
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 16.r,
                                color: const Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      currentUser.fullName,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      currentUser.position ?? 'Administrator',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: const Color(0xFF2DD4BF), // Light Teal
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.r,
                        ),
                      ),
                      child: Text(
                        'ROLE: ADMIN',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Quick Stats Section (New Hub Widget)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Guru',
                      value: '${masterProvider.teachers.length}',
                      icon: Icons.people_alt_outlined,
                      color: const Color(0xFF0F172A),
                      onTap: () => context.push('/admin/master-data/teachers'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Kelas',
                      value: '${masterProvider.classes.length}',
                      icon: Icons.class_outlined,
                      color: const Color(0xFF0D9488),
                      onTap: () => context.push('/admin/master-data/classes'),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Pending',
                      value: '${journalProvider.journals.where((j) => j.status == 'pending').length}',
                      icon: Icons.pending_actions_outlined,
                      color: const Color(0xFFF59E0B),
                      onTap: () => context.push('/admin/approvals'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // Detail List Section
              Text(
                'INFORMASI AKUN',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8.h),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                  side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
                child: Column(
                  children: [
                    _buildProfileDetailItem(
                      Icons.badge_outlined,
                      'Jabatan / Posisi',
                      currentUser.position ?? 'Administrator',
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileDetailItem(
                      Icons.email_outlined,
                      'Email',
                      currentUser.email,
                      isEmail: true,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileDetailItem(
                      Icons.phone_outlined,
                      'No. Telepon',
                      currentUser.phoneNumber ?? 'Belum Diisi',
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileDetailItem(
                      Icons.home_outlined,
                      'Alamat',
                      currentUser.address ?? 'Belum Diisi',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // Edit Button
              ElevatedButton.icon(
                onPressed: () => _showEditProfileDialog(currentUser),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Profil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size.fromHeight(50.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Danger Zone Panel
              Text(
                'ZONA BAHAYA',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[400],
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          'Hapus Akun',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      isSuperAdmin
                          ? 'Akun administrator utama (admin@jurnal.com) dilindungi sistem dan tidak dapat dihapus.'
                          : 'Tindakan berikut akan menghapus akun administrator Anda secara permanen beserta seluruh data terkait.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.red[700],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSuperAdmin
                            ? null
                            : () => _handleDeleteAccount(currentUser),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('Hapus Akun Saya'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[500],
                          elevation: 0,
                          minimumSize: Size.fromHeight(48.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20.r,
                  color: color,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailItem(
    IconData icon,
    String title,
    String value, {
    bool isEmail = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              icon,
              size: 20.r,
              color: const Color(0xFF0D9488),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isEmail)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified,
                    size: 12.r,
                    color: const Color(0xFF10B981),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Aktif',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
