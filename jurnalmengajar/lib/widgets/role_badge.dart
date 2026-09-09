import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const RoleBadge({
    super.key,
    required this.role,
    this.fontSize,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanRole = role.trim().toLowerCase();
    final isAdmin = cleanRole == 'admin' || cleanRole == 'superadmin';
    final isTenant = cleanRole == 'tenant';

    // ── GURU (Default) ──
    Color bgColor = isDark
        ? const Color(0xFF14532D).withValues(alpha: 0.35)
        : const Color(0xFFF0FDF4); // Guru Green
    Color borderColor = isDark
        ? const Color(0xFF22C55E).withValues(alpha: 0.55)
        : const Color(0xFF86EFAC);
    Color textColor = isDark
        ? const Color(0xFF86EFAC)
        : const Color(0xFF166534);
    String label = 'GURU';

    // ── ADMIN ──
    if (isAdmin) {
      bgColor = isDark
          ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
          : const Color(0xFFFEF2F2); // Admin Red
      borderColor = isDark
          ? const Color(0xFFEF4444).withValues(alpha: 0.55)
          : const Color(0xFFFCA5A5);
      textColor = isDark
          ? const Color(0xFFFCA5A5)
          : const Color(0xFF991B1B);
      label = 'ADMIN';
    } else if (isTenant) {
      bgColor = isDark
          ? const Color(0xFF312E81).withValues(alpha: 0.35)
          : const Color(0xFFEEF2FF); // Tenant Indigo
      borderColor = isDark
          ? const Color(0xFF6366F1).withValues(alpha: 0.55)
          : const Color(0xFFA5B4FC);
      textColor = isDark
          ? const Color(0xFFA5B4FC)
          : const Color(0xFF3730A3);
      label = 'TENANT';
    }

    final badgeWidget = Container(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : textColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin
                ? Icons.admin_panel_settings_rounded
                : (isTenant ? Icons.domain_rounded : Icons.school_rounded),
            size: (fontSize ?? 11.sp) + 2,
            color: textColor,
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: fontSize ?? 11.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          hoverColor: borderColor.withValues(alpha: 0.12),
          splashColor: borderColor.withValues(alpha: 0.2),
          child: badgeWidget,
        ),
      );
    }

    return badgeWidget;
  }
}
