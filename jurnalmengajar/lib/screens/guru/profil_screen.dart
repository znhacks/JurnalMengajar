import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
          await warningProvider.loadTeacherWarningLetters(teacher.id);
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
    final scheduleProvider = context.watch<ScheduleProvider>();

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

    // Calculate teacher stats
    final teacherJournals = journalProvider.journals
        .where((j) => j.teacherId == teacher.id)
        .toList();
    final totalJournals = teacherJournals.length;
    final verifiedJournals = teacherJournals
        .where((j) => j.status == 'verified')
        .length;
    final totalSchedules = scheduleProvider.schedules
        .where((s) => s.teacherId == teacher.id)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Profil Pengajar'),
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
                                backgroundImage:
                                    currentUser.photoUrl != null &&
                                        currentUser.photoUrl!.startsWith('http')
                                    ? CachedNetworkImageProvider(
                                        currentUser.photoUrl!,
                                      )
                                    : null,
                                child:
                                    (currentUser.photoUrl == null ||
                                        !currentUser.photoUrl!.startsWith(
                                          'http',
                                        ))
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
                              currentUser.fullName,
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
                            currentUser.position ?? teacher.position,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: const Color(0xFF2DD4BF), // Light Teal
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
                              'ROLE: ${currentUser.role.toUpperCase()}',
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

              // Live Stats Row for Teacher
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Jadwal',
                      value: '$totalSchedules',
                      icon: Icons.calendar_today_outlined,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Jurnal',
                      value: '$totalJournals',
                      icon: Icons.menu_book_outlined,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Disetujui',
                      value: '$verifiedJournals',
                      icon: Icons.check_circle_outline_rounded,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              // Detail List Section
              Text(
                'INFORMASI GURU',
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
                      currentUser.position ?? teacher.position,
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
                      currentUser.phoneNumber ?? teacher.phoneNumber,
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _buildProfileDetailItem(
                      Icons.home_outlined,
                      'Alamat Lengkap',
                      currentUser.address ?? teacher.address,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),

              // Edit Button
              ElevatedButton.icon(
                onPressed: () => _showEditProfileDialog(currentUser, teacher),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Edit Profil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: Size.fromHeight(50.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Warning Letters Button (SP)
              Consumer<WarningLetterProvider>(
                builder: (context, warningProvider, child) {
                  final unreadCount = warningProvider.warningLetters
                      .where((w) => w.status == 'unread')
                      .length;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: ElevatedButton(
                      onPressed: () => context.push('/guru/warning-letters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: unreadCount > 0
                            ? const Color(0xFFBA1A1A)
                            : Colors.white,
                        foregroundColor: unreadCount > 0
                            ? Colors.white
                            : const Color(0xFFBA1A1A),
                        side: BorderSide(
                          color: const Color(0xFFBA1A1A),
                          width: 1.5.r,
                        ),
                        elevation: 0,
                        minimumSize: Size.fromHeight(50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            unreadCount > 0
                                ? Icons.mail_rounded
                                : Icons.mail_outline_rounded,
                            size: 18,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Surat Peringatan Saya',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: TextStyle(
                                  color: const Color(0xFFBA1A1A),
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              // About App Button
              OutlinedButton.icon(
                onPressed: () => context.push('/about'),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Tentang Aplikasi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
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
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2),
                    width: 1.r,
                  ),
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
                      'Tindakan berikut akan menghapus akun guru Anda secara permanen beserta seluruh data jadwal dan jurnal mengajar.',
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
                        onPressed: () => _handleDeleteAccount(currentUser),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('Hapus Akun Saya'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
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
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16.r, color: color),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
