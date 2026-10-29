import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/utils/helper.dart';
import '../../models/user_school_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_dialog_actions.dart';
import '../../widgets/profile_photo_view.dart';
import '../../widgets/web_responsive_container.dart';

/// Screen displayed when an authenticated teacher currently has no active school
/// (e.g., newly registered without school, exited previous school, or removed).
class NoSchoolScreen extends StatefulWidget {
  const NoSchoolScreen({super.key});

  @override
  State<NoSchoolScreen> createState() => _NoSchoolScreenState();
}

class _NoSchoolScreenState extends State<NoSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isRefreshing = false;

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleJoinSchool(AuthProvider authProvider) async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      AppHelper.showSnackBar(
        context,
        'Masukkan kode sekolah terlebih dahulu.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();

    try {
      final success = await authProvider.joinSchoolWithCode(code, role: 'guru');

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (success) {
        _codeController.clear();
        AppHelper.showSnackBar(
          context,
          'Permintaan bergabung berhasil dikirim! Menunggu persetujuan Admin Sekolah.',
        );
      } else {
        AppHelper.showSnackBar(
          context,
          authProvider.errorMessage ??
              'Gagal bergabung dengan kode sekolah tersebut.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppHelper.showSnackBar(
        context,
        e.toString().replaceAll('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _handleRefreshStatus(AuthProvider authProvider) async {
    setState(() => _isRefreshing = true);
    try {
      await authProvider.loadUserMemberships();
      if (!mounted) return;
      AppHelper.showSnackBar(context, 'Status keanggotaan berhasil diperbarui.');
    } catch (e) {
      if (!mounted) return;
      AppHelper.showSnackBar(
        context,
        'Gagal memperbarui status: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _handleCancelPending(
    AuthProvider authProvider,
    UserSchoolModel pending,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Batalkan Permintaan',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan permintaan bergabung ke ${pending.schoolName}?',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14.sp,
            color: const Color(0xFF475569),
          ),
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          AppDialogActions(
            cancelText: 'Kembali',
            confirmText: 'Ya, Batalkan',
            isDestructive: true,
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isRefreshing = true);
    final ok = await authProvider.leaveSchool(
      pending.schoolId,
      membershipId: pending.id,
    );

    if (!mounted) return;
    setState(() => _isRefreshing = false);

    if (ok) {
      AppHelper.showSnackBar(
        context,
        'Permintaan bergabung berhasil dibatalkan.',
      );
    } else {
      AppHelper.showSnackBar(
        context,
        authProvider.errorMessage ?? 'Gagal membatalkan permintaan.',
        isError: true,
      );
    }
  }

  Future<void> _handleLogout(AuthProvider authProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Keluar dari Akun',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun saat ini?',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14.sp,
            color: const Color(0xFF475569),
          ),
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          AppDialogActions(
            cancelText: 'Batal',
            confirmText: 'Keluar',
            isDestructive: true,
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await authProvider.logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final pendingMemberships = authProvider.pendingMemberships;
    final inactiveMemberships = authProvider.inactiveMemberships;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);
    final textMuted = const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16.w,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: borderColor, height: 1),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(7.w),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(9.r),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Jurnal Mengajar',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'Pusat Hubungan Sekolah',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w500,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Periksa Ulang Status',
            icon: _isRefreshing
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2563EB),
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    size: 22.sp,
                    color: textSecondary,
                  ),
            onPressed: _isRefreshing
                ? null
                : () => _handleRefreshStatus(authProvider),
          ),
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: IconButton(
              icon: Icon(
                Icons.logout_rounded,
                size: 20.sp,
                color: const Color(0xFFE11D48),
              ),
              onPressed: () => _handleLogout(authProvider),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: WebResponsiveContainer(
          maxWidth: 640.0,
          backgroundColor: backgroundColor,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. User Identity Card
                Container(
                  padding: EdgeInsets.all(18.w),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24.r),
                        child: Container(
                          width: 54.w,
                          height: 54.w,
                          color: const Color(0xFF2563EB),
                          child: (currentUser != null &&
                                  currentUser.photoUrl != null &&
                                  currentUser.photoUrl!.isNotEmpty)
                              ? ProfilePhotoView(
                                  userId: currentUser.id,
                                  photoUrl: currentUser.photoUrl,
                                  fallback: Center(
                                    child: Text(
                                      (currentUser.fullName.isNotEmpty)
                                          ? currentUser.fullName[0].toUpperCase()
                                          : 'G',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 22.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    (currentUser?.fullName != null &&
                                            currentUser!.fullName.isNotEmpty)
                                        ? currentUser.fullName[0].toUpperCase()
                                        : 'G',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 22.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser?.fullName ?? 'Guru Pengajar',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              currentUser?.email ?? '',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(20.r),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF475569)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7.w,
                                    height: 7.w,
                                    decoration: BoxDecoration(
                                      color: pendingMemberships.isNotEmpty
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF64748B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    pendingMemberships.isNotEmpty
                                        ? 'Menunggu Persetujuan Admin'
                                        : 'Nonaktif',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.5.sp,
                                      fontWeight: FontWeight.w700,
                                      color: pendingMemberships.isNotEmpty
                                          ? (isDark
                                              ? const Color(0xFFFCD34D)
                                              : const Color(0xFFB45309))
                                          : textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16.h),

                // 2. Pending Join Request Card (if any)
                if (pendingMemberships.isNotEmpty) ...[
                  ...pendingMemberships.map((pending) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 16.h),
                      padding: EdgeInsets.all(18.w),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF78350F).withValues(alpha: 0.25)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFFD97706).withValues(alpha: 0.5)
                              : const Color(0xFFFDE68A),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 18.sp,
                                color: const Color(0xFFD97706),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'PERMINTAAN SEDANG DIPROSES',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD97706),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            pending.schoolName,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          if (pending.schoolCode != null &&
                              pending.schoolCode!.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'Kode Sekolah: ${pending.schoolCode}',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w500,
                                color: textSecondary,
                              ),
                            ),
                          ],
                          SizedBox(height: 10.h),
                          Text(
                            'Permintaan bergabung Anda telah terkirim. Akun akan aktif secara otomatis setelah disetujui oleh Administrator atau Operator sekolah tersebut.',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.sp,
                              color: textSecondary,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isRefreshing
                                      ? null
                                      : () => _handleCancelPending(
                                            authProvider,
                                            pending,
                                          ),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 11.h,
                                    ),
                                    side: BorderSide(
                                      color: const Color(0xFFE11D48)
                                          .withValues(alpha: 0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                  ),
                                  child: Text(
                                    'Batalkan Permintaan',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFE11D48),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isRefreshing
                                      ? null
                                      : () => _handleRefreshStatus(authProvider),
                                  icon: _isRefreshing
                                      ? SizedBox(
                                          width: 14.w,
                                          height: 14.w,
                                          child: const CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(Icons.refresh_rounded, size: 16.sp),
                                  label: Text(
                                    'Cek Status',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 11.h,
                                    ),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10.r),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // 3. Primary Action: Join School Card
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.w),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Icon(
                                Icons.domain_add_rounded,
                                color: const Color(0xFF2563EB),
                                size: 22.sp,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Gabung ke Sekolah',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Masukkan kode sekolah untuk menghubungkan akun',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.5.sp,
                                      fontWeight: FontWeight.w500,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 18.h),
                        Text(
                          'Kode Sekolah',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextFormField(
                          controller: _codeController,
                          focusNode: _codeFocusNode,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9\-]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Contoh: SMKN11 atau SCH-8910',
                            hintStyle: GoogleFonts.hankenGrotesk(
                              fontSize: 13.5.sp,
                              color: textMuted,
                            ),
                            prefixIcon: Icon(
                              Icons.tag_rounded,
                              color: textMuted,
                              size: 20.sp,
                            ),
                            suffixIcon: _codeController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _codeController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 14.h,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: const BorderSide(
                                color: Color(0xFF2563EB),
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        SizedBox(height: 16.h),
                        SizedBox(
                          width: double.infinity,
                          height: 48.h,
                          child: ElevatedButton(
                            onPressed: (_isSubmitting ||
                                    _codeController.text.trim().isEmpty)
                                ? null
                                : () => _handleJoinSchool(authProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    width: 20.w,
                                    height: 20.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    'Kirim Permintaan Bergabung',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // 4. Inactive / Past School History (if any)
                if (inactiveMemberships.isNotEmpty) ...[
                  Container(
                    padding: EdgeInsets.all(18.w),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 18.sp,
                              color: textMuted,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Riwayat Sekolah Sebelumnya',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        ...inactiveMemberships.map((inactive) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 8.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 10.h,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inactive.schoolName,
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 13.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Status: Tidak Aktif / Selesai Bertugas',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.sp,
                                          color: textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        SizedBox(height: 4.h),
                        Text(
                          'Catatan: Seluruh riwayat jurnal mengajar dan kehadiran Anda di sekolah sebelumnya tetap tersimpan aman di arsip sekolah.',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.sp,
                            color: textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],

                // 5. Information Guide Box
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20.sp,
                        color: textMuted,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'Belum memiliki kode sekolah? Hubungi Kepala Sekolah, Administrator, atau Operator IT di tempat Anda mengajar untuk mendapatkan kode resmi sekolah.',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.5.sp,
                            color: textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
