import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Standard cohesive dialog action buttons (Batal vs Konfirmasi/Aksi).
/// Menyelaraskan tinggi, radius, padding, dan hierarki visual tombol
/// pada seluruh AlertDialog dan Modal di aplikasi.
class AppDialogActions extends StatelessWidget {
  final String cancelText;
  final VoidCallback? onCancel;
  final String confirmText;
  final VoidCallback? onConfirm;
  final bool isConfirmLoading;
  final Color? confirmColor;
  final Color? confirmTextColor;
  final bool isDestructive;

  const AppDialogActions({
    super.key,
    this.cancelText = 'Batal',
    this.onCancel,
    required this.confirmText,
    required this.onConfirm,
    this.isConfirmLoading = false,
    this.confirmColor,
    this.confirmTextColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final effectiveConfirmColor = isDestructive
        ? colorScheme.error
        : (confirmColor ?? const Color(0xFF2563EB));
    final effectiveConfirmTextColor = confirmTextColor ?? Colors.white;

    final cancelBorderColor = isDark
        ? const Color(0xFF475569)
        : const Color(0xFFCBD5E1);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isConfirmLoading
                  ? null
                  : (onCancel ?? () => Navigator.of(context).pop(false)),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(0, 44.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                side: BorderSide(color: cancelBorderColor, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              child: Text(
                cancelText,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: ElevatedButton(
              onPressed: isConfirmLoading ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(0, 44.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                elevation: 0,
                backgroundColor: effectiveConfirmColor,
                foregroundColor: effectiveConfirmTextColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: isConfirmLoading
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      confirmText,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
