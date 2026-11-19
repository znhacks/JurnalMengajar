import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/router/app_router.dart';
import '../core/services/connectivity_service.dart';

/// Pembungkus global yang memantau status koneksi internet,
/// menampilkan label/banner peringatan offline, serta dialog peringatan.
class OfflineIndicatorWrapper extends StatefulWidget {
  final Widget child;

  const OfflineIndicatorWrapper({super.key, required this.child});

  @override
  State<OfflineIndicatorWrapper> createState() => _OfflineIndicatorWrapperState();
}

class _OfflineIndicatorWrapperState extends State<OfflineIndicatorWrapper> {
  final ConnectivityService _connectivity = ConnectivityService.instance;
  bool _dialogShownForCurrentOfflineSession = false;

  @override
  void initState() {
    super.initState();
    _connectivity.addListener(_handleConnectivityChange);
  }

  @override
  void dispose() {
    _connectivity.removeListener(_handleConnectivityChange);
    super.dispose();
  }

  void _handleConnectivityChange() {
    if (!mounted) return;

    if (_connectivity.isOffline) {
      if (!_dialogShownForCurrentOfflineSession) {
        _dialogShownForCurrentOfflineSession = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOfflineDialog();
        });
      }
    } else {
      _dialogShownForCurrentOfflineSession = false;
    }
  }

  void _showOfflineDialog() {
    if (!mounted) return;
    final dialogContext = AppRouter.rootNavigatorKey.currentContext ?? context;

    showDialog<void>(
      context: dialogContext,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          titlePadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 8.h),
          contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          actionsPadding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFD97706),
                  size: 20,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  'Koneksi Terputus',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Perangkat Anda saat ini tidak terhubung ke internet. Aplikasi mungkin tidak dapat berjalan optimal saat offline. Data perubahan akan disinkronkan saat koneksi kembali aktif.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Mengerti',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final online = await _connectivity.checkConnectivity();
                if (mounted && !online) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Masih belum terhubung ke internet. Memeriksa kembali...',
                        style: GoogleFonts.hankenGrotesk(fontSize: 12.5.sp),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              ),
              child: Text(
                'Coba Hubungkan',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _connectivity,
      builder: (context, _) {
        final isOffline = _connectivity.isOffline;
        final justReconnected = _connectivity.justReconnected;
        final showBanner = isOffline || justReconnected;

        return Column(
          children: [
            if (showBanner) _buildBanner(isOffline: isOffline),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }

  Widget _buildBanner({required bool isOffline}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isOffline
        ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB))
        : (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5));

    final borderColor = isOffline
        ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A))
        : (isDark ? const Color(0xFF047857) : const Color(0xFFA7F3D0));

    final iconColor = isOffline
        ? const Color(0xFFD97706)
        : const Color(0xFF10B981);

    final textColor = isOffline
        ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
        : (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46));

    final text = isOffline
        ? 'Mode Offline • Aplikasi mungkin tidak berjalan optimal'
        : 'Koneksi Pulih • Anda kembali online';

    final icon = isOffline
        ? Icons.wifi_off_rounded
        : Icons.wifi_rounded;

    return Material(
      color: bgColor,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15.sp, color: iconColor),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  text,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isOffline) ...[
                SizedBox(width: 10.w),
                InkWell(
                  onTap: () => _connectivity.checkConnectivity(),
                  borderRadius: BorderRadius.circular(6.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    child: Text(
                      'Coba Lagi',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
