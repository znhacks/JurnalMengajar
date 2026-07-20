import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/user_model.dart';
import '../../models/teacher_model.dart';
import '../../core/utils/helper.dart';
import '../../core/utils/image_crop_helper.dart';
import '../../repositories/supabase_auth_repository.dart';
import '../../widgets/image_viewer.dart';
import '../../providers/warning_letter_provider.dart';

class GuruProfilScreen extends StatefulWidget {
  const GuruProfilScreen({super.key});

  @override
  State<GuruProfilScreen> createState() => _GuruProfilScreenState();
}

class _GuruProfilScreenState extends State<GuruProfilScreen> {
  bool _showFullName = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final masterProvider = Provider.of<MasterDataProvider>(
        context,
        listen: false,
      );
      final warningProvider = Provider.of<WarningLetterProvider>(
        context,
        listen: false,
      );

      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        await masterProvider.loadAllData();
        if (!mounted) return;
        final teacher = masterProvider.teachers.firstWhere(
          (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
          orElse: () => TeacherModel(
            id: '',
            name: '',
            position: '',
            address: '',
            phoneNumber: '',
            email: '',
          ),
        );
        if (teacher.id.isNotEmpty) {
          await Future.wait([
            warningProvider.loadTeacherWarningLetters(teacher.id),
            Provider.of<ScheduleProvider>(context, listen: false)
                .loadTeacherSchedules(teacher.id, DateTime.now()),
            Provider.of<JournalProvider>(context, listen: false)
                .loadTeacherJournals(teacher.id),
          ]);
        }
      }
    });
  }

  Future<void> _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    // Router redirection handles steering to login
  }

  Future<void> _handleDeleteAccount(UserModel user) async {
    final confirmed1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: const Text(
          'HAPUS AKUN ANDA',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Apakah Anda yakin ingin menghapus akun guru Anda secara permanen? '
          'Seluruh data Anda (termasuk jadwal dan jurnal mengajar) akan terhapus dan Anda akan langsung dikeluarkan dari aplikasi.',
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
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

  void _showEditProfileDialog(UserModel user, TeacherModel teacher) {
    final nameController = TextEditingController(text: user.fullName);
    final emailController = TextEditingController(text: user.email);
    final posController = TextEditingController(
      text: user.position ?? teacher.position,
    );
    final phoneController = TextEditingController(
      text: user.phoneNumber ?? teacher.phoneNumber,
    );
    final addrController = TextEditingController(
      text: user.address ?? teacher.address,
    );
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
          Future<void> pickDialogImage({
            ImageSource source = ImageSource.gallery,
          }) async {
            final result = await pickAndCropImage(
              context: context,
              source: source,
            );
            if (result != null) {
              setDialogState(() {
                tempImageBytes = result.bytes;
                tempImageName = result.name;
              });
            }
          }

          Future<void> showImageSourceSheet() async {
            await showModalBottomSheet<void>(
              context: context,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              ),
              builder: (sheetCtx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 8.h),
                    Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'Pilih Sumber Foto',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0F2F1),
                        child: Icon(
                          Icons.photo_library_outlined,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      title: const Text('Galeri Foto'),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        pickDialogImage(source: ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE0F2F1),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      title: const Text('Kamera'),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        pickDialogImage(source: ImageSource.camera);
                      },
                    ),
                    SizedBox(height: 8.h),
                  ],
                ),
              ),
            );
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
                    'Edit Profil Anda',
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
                                          ? CachedNetworkImageProvider(
                                              user.photoUrl!,
                                            )
                                          : null)
                                      as ImageProvider?,
                            child:
                                tempImageBytes == null && user.photoUrl == null
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
                            onTap: showImageSourceSheet,
                            child: Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
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
                    controller: emailController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'contoh@email.com',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  GestureDetector(
                    onTap: isSaving
                        ? null
                        : () {
                            final masterProvider =
                                Provider.of<MasterDataProvider>(
                                  context,
                                  listen: false,
                                );
                            final subjectNames = masterProvider.subjects
                                .map((s) => s.name)
                                .toList();
                            _showPositionSelector(
                              context,
                              subjectNames,
                              posController.text,
                              (selected) {
                                setDialogState(() {
                                  posController.text = selected;
                                });
                              },
                            );
                          },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: posController,
                        enabled: !isSaving,
                        decoration: const InputDecoration(
                          labelText: 'Jabatan',
                          hintText:
                              'Ketuk untuk memilih jabatan / guru mapel...',
                          prefixIcon: Icon(Icons.badge_outlined),
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                      ),
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
                            if (nameController.text.trim().isEmpty) {
                              AppHelper.showSnackBar(
                                context,
                                'Nama lengkap tidak boleh kosong',
                                isError: true,
                              );
                              return;
                            }
                            final newEmail = emailController.text.trim();
                            if (newEmail.isEmpty) {
                              AppHelper.showSnackBar(
                                context,
                                'Email tidak boleh kosong',
                                isError: true,
                              );
                              return;
                            }
                            if (posController.text.trim().isEmpty) {
                              AppHelper.showSnackBar(
                                context,
                                'Jabatan/guru mapel tidak boleh kosong',
                                isError: true,
                              );
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            final masterProvider =
                                Provider.of<MasterDataProvider>(
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
                              bool emailSuccess = true;
                              final isEmailChanged = newEmail.toLowerCase() != user.email.toLowerCase();
                              
                              if (isEmailChanged) {
                                emailSuccess = await authProvider.changeEmail(newEmail);
                              }

                              // Optimistically update local teacher details cache without reloading everything
                              if (authProvider.currentUser != null) {
                                masterProvider.updateTeacherFromUser(
                                  authProvider.currentUser!,
                                );
                              } else {
                                masterProvider.updateTeacherFromUser(
                                  updatedUser,
                                );
                              }
                              
                              if (context.mounted) {
                                if (isEmailChanged && emailSuccess) {
                                  AppHelper.showSnackBar(
                                    context,
                                    'Profil diperbarui! Silakan verifikasi email baru Anda melalui tautan konfirmasi yang dikirim.',
                                  );
                                  Navigator.pop(context);
                                } else if (isEmailChanged && !emailSuccess) {
                                  AppHelper.showSnackBar(
                                    context,
                                    'Profil diperbarui, tetapi gagal mengirim konfirmasi email baru: ${authProvider.errorMessage}',
                                    isError: true,
                                  );
                                } else {
                                  AppHelper.showSnackBar(
                                    context,
                                    'Profil berhasil diperbarui!',
                                  );
                                  Navigator.pop(context);
                                }
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
    final scheduleProvider = context.watch<ScheduleProvider>();

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    final isLoading = masterProvider.isLoading ||
        scheduleProvider.isLoading ||
        journalProvider.isLoading;

    final errorMessage = masterProvider.errorMessage ??
        scheduleProvider.errorMessage ??
        journalProvider.errorMessage;

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

    final isFirstLoad = teacher.id.isEmpty && masterProvider.teachers.isEmpty;

    if (isFirstLoad && isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (isFirstLoad && errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, color: Colors.red, size: 48),
                SizedBox(height: 16.h),
                Text(
                  'Gagal Memuat Profil',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.h),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 24.h),
                ElevatedButton.icon(
                  onPressed: () {
                    masterProvider.loadAllData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: Size(150.w, 40.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profil Pengajar'),
        bottom: isLoading
            ? PreferredSize(
                preferredSize: Size.fromHeight(2.h),
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  title: const Text('Konfirmasi Logout'),
                  content: const Text(
                    'Apakah Anda yakin ingin keluar dari aplikasi?',
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Card Header with Gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A), // Slate 900
                      Color(0xFF2563EB), // Teal 600
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        GestureDetector(
                          onTap:
                              currentUser.photoUrl != null &&
                                  currentUser.photoUrl!.startsWith('http')
                              ? () {
                                  FullScreenImageViewer.show(
                                    context,
                                    currentUser.photoUrl!,
                                    'guru_profile_avatar',
                                  );
                                }
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5.r,
                              ),
                            ),
                            child: Hero(
                              tag: 'guru_profile_avatar',
                              child: CircleAvatar(
                                radius: 36.r,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                backgroundImage: (teacher.photoUrl != null && teacher.photoUrl!.startsWith('http'))
                                    ? CachedNetworkImageProvider(teacher.photoUrl!)
                                    : (currentUser.photoUrl != null &&
                                            currentUser.photoUrl!.startsWith('http')
                                        ? CachedNetworkImageProvider(currentUser.photoUrl!)
                                        : null) as ImageProvider?,
                                child: (teacher.photoUrl == null || !teacher.photoUrl!.startsWith('http')) &&
                                        (currentUser.photoUrl == null || !currentUser.photoUrl!.startsWith('http'))
                                    ? Icon(
                                        Icons.person,
                                        size: 36.r,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () =>
                                _showEditProfileDialog(currentUser, teacher),
                            child: Container(
                              padding: EdgeInsets.all(5.w),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 12.r,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showFullName = !_showFullName;
                              });
                            },
                            child: Text(
                              teacher.name.isNotEmpty ? teacher.name : currentUser.fullName,
                              maxLines: _showFullName ? null : 1,
                              overflow: _showFullName
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            teacher.position.isNotEmpty ? teacher.position : (currentUser.position ?? 'Guru'),
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              'JABATAN: ${currentUser.role.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),

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
              SizedBox(height: 6.h),
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
                      'Jabatan',
                      teacher.position.isNotEmpty ? teacher.position : (currentUser.position ?? 'Guru'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileDetailItem(
                      Icons.email_outlined,
                      'Email',
                      teacher.email.isNotEmpty ? teacher.email : currentUser.email,
                      isEmail: true,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileDetailItem(
                      Icons.phone_outlined,
                      'No. Telepon',
                      teacher.phoneNumber.isNotEmpty ? teacher.phoneNumber : (currentUser.phoneNumber ?? 'Belum Diisi'),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileDetailItem(
                      Icons.home_outlined,
                      'Alamat Lengkap',
                      teacher.address.isNotEmpty ? teacher.address : (currentUser.address ?? 'Belum Diisi'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Text(
                'PENGATURAN AKUN',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8.h),
              Consumer<WarningLetterProvider>(
                builder: (context, warningProvider, child) {
                  final unreadCount = warningProvider.warningLetters
                      .where((w) => w.status == 'unread')
                      .length;

                  return Row(
                    children: [
                      // 1. Edit Profil
                      _buildHorizontalAction(
                        icon: Icons.edit_rounded,
                        label: 'Edit Profil',
                        color: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                        onTap: () => _showEditProfileDialog(currentUser, teacher),
                      ),
                      // 2. Surat Peringatan
                      _buildHorizontalAction(
                        icon: Icons.mail_rounded,
                        label: 'Peringatan',
                        color: const Color(0xFFBA1A1A),
                        bgColor: unreadCount > 0 ? const Color(0xFFFEE2E2) : const Color(0xFFF8FAFC),
                        badgeCount: unreadCount,
                        onTap: () => context.push('/guru/warning-letters'),
                      ),
                      // 3. Tentang Aplikasi
                      _buildHorizontalAction(
                        icon: Icons.info_outline_rounded,
                        label: 'Tentang',
                        color: const Color(0xFF64748B),
                        bgColor: const Color(0xFFF1F5F9),
                        onTap: () => context.push('/about'),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 20.h),

              // Danger Zone Panel (Compact & Elegant)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.15),
                    width: 1.r,
                  ),
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                  leading: Container(
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
                  title: Text(
                    'Zona Bahaya',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[800],
                    ),
                  ),
                  subtitle: Text(
                    'Hapus akun guru secara permanen',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.red[700],
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => _handleDeleteAccount(currentUser),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: Text(
                      'Hapus Akun',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
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
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 18.r, color: const Color(0xFF2563EB)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isEmail)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified,
                    size: 10.r,
                    color: const Color(0xFF10B981),
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    'Aktif',
                    style: TextStyle(
                      fontSize: 9.sp,
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

  Widget _buildHorizontalAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 2.w),
        elevation: 0,
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
          side: BorderSide(
            color: badgeCount > 0 ? color.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 2.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, color: color, size: 20.r),
                    if (badgeCount > 0)
                      Positioned(
                        top: -4.h,
                        right: -4.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 14.r,
                            minHeight: 14.r,
                          ),
                          child: Center(
                            child: Text(
                              '$badgeCount',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPositionSelector(
    BuildContext context,
    List<String> subjects,
    String currentPosition,
    Function(String) onSelect,
  ) {
    final searchController = TextEditingController();
    List<String> options = subjects.map((s) => 'Guru $s').toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final query = searchController.text.toLowerCase();
          final filteredOptions = options
              .where((opt) => opt.toLowerCase().contains(query))
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SizedBox(
              height: 400.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pilih Jabatan / Guru Mapel',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Cari mata pelajaran / jabatan...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: filteredOptions.isEmpty
                        ? const Center(
                            child: Text('Tidak ada pilihan ditemukan'),
                          )
                        : ListView.builder(
                            itemCount: filteredOptions.length,
                            itemBuilder: (context, index) {
                              final opt = filteredOptions[index];
                              final isSelected =
                                  opt.toLowerCase() ==
                                  currentPosition.toLowerCase();
                              return ListTile(
                                title: Text(
                                  opt,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : null,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Color(0xFF2563EB),
                                      )
                                    : null,
                                onTap: () {
                                  onSelect(opt);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
