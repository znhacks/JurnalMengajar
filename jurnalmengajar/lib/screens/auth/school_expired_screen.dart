import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/helper.dart';
import '../../widgets/wave_clipper.dart';

class SchoolExpiredScreen extends StatefulWidget {
  const SchoolExpiredScreen({super.key});

  @override
  State<SchoolExpiredScreen> createState() => _SchoolExpiredScreenState();
}

class _SchoolExpiredScreenState extends State<SchoolExpiredScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolCodeController = TextEditingController();
  final _schoolCodeFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _schoolCodeController.dispose();
    _schoolCodeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLinkSchool(AuthProvider authProvider) async {
    final code = _schoolCodeController.text.trim();
    if (code.isEmpty) {
      AppHelper.showSnackBar(context, 'Masukkan kode sekolah terlebih dahulu.', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await authProvider.joinSchoolWithCode(
      code,
      role: authProvider.activeRole,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        AppHelper.showSnackBar(context, 'Sekolah berhasil diperbarui!');
      } else {
        AppHelper.showSnackBar(
          context,
          authProvider.errorMessage ?? 'Gagal menghubungkan ke sekolah baru.',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleDeleteAccount(AuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Akun Permanen'),
        content: const Text(
          'Apakah Anda yakin ingin menghapus akun Anda secara permanen? '
          'Semua data Anda akan dihapus dan tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoading = true;
      });

      final success = await authProvider.deleteAccount(authProvider.currentUser!.id);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          AppHelper.showSnackBar(context, 'Akun Anda telah berhasil dihapus.');
        } else {
          AppHelper.showSnackBar(
            context,
            authProvider.errorMessage ?? 'Gagal menghapus akun.',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 24.w,
            vertical: kIsWeb ? 16 : 32.h,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: kIsWeb ? 380 : 440),
            child: Card(
              elevation: 12,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.r),
              ),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Section with Wave
                  Stack(
                    children: [
                      ClipPath(
                        clipper: const WaveClipper(),
                        child: Container(
                          height: kIsWeb ? 130 : 155.h,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 239, 68, 68),
                                Color.fromARGB(255, 220, 38, 38),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: kIsWeb ? 16 : 20.h,
                            bottom: kIsWeb ? 28 : 36.h,
                            left: 16.w,
                            right: 16.w,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.domain_disabled_rounded,
                                color: Colors.white,
                                size: kIsWeb ? 40 : 48.r,
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Akses Ditangguhkan',
                                style: TextStyle(
                                  fontSize: kIsWeb ? 16 : 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Content Section
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      kIsWeb ? 20 : 24.w,
                      kIsWeb ? 8 : 12.h,
                      kIsWeb ? 20 : 24.w,
                      kIsWeb ? 16 : 20.h,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: const Color(0xFFFEE2E2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: const Color(0xFFEF4444),
                                  size: 20.r,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    'Tidak terdapat sekolah dengan kode ini, mungkin berlangganan pada jmpanel.vercel.app telah expired/school dihapus',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF991B1B),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Text(
                            'Hubungkan ke Sekolah Baru',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextFormField(
                            controller: _schoolCodeController,
                            focusNode: _schoolCodeFocusNode,
                            textCapitalization: TextCapitalization.characters,
                            onFieldSubmitted: _isLoading ? null : (_) => _handleLinkSchool(authProvider),
                            decoration: InputDecoration(
                              hintText: 'Masukkan Kode Sekolah baru...',
                              prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF64748B)),
                              filled: true,
                              fillColor: const Color(0xFFF1F5F9),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isLoading ? null : () => _handleLinkSchool(authProvider),
                            child: _isLoading
                                ? SizedBox(
                                    height: 20.r,
                                    width: 20.r,
                                    child: const CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Hubungkan Sekolah Baru'),
                          ),
                          SizedBox(height: 16.h),
                          const Divider(color: Color(0xFFE2E8F0)),
                          SizedBox(height: 12.h),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            onPressed: _isLoading ? null : () => authProvider.logout(),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Keluar dari Akun'),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              padding: EdgeInsets.symmetric(vertical: 12.h),
                            ),
                            onPressed: _isLoading ? null : () => _handleDeleteAccount(authProvider),
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('Hapus Akun secara Permanen'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
