import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const RoleBadge({
    super.key,
    required this.role,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final cleanRole = role.trim().toLowerCase();
    final isAdmin = cleanRole == 'admin' || cleanRole == 'superadmin';
    final isTenant = cleanRole == 'tenant';

    Color bgColor = const Color(0xFFF0FDF4); // Guru Green
    Color borderColor = const Color(0xFF86EFAC);
    Color textColor = const Color(0xFF166534);
    String label = 'GURU';

    if (isAdmin) {
      bgColor = const Color(0xFFFEF2F2); // Admin Red
      borderColor = const Color(0xFFFCA5A5);
      textColor = const Color(0xFF991B1B);
      label = 'ADMIN';
    } else if (isTenant) {
      bgColor = const Color(0xFFEEF2FF); // Tenant Indigo
      borderColor = const Color(0xFFA5B4FC);
      textColor = const Color(0xFF3730A3);
      label = 'TENANT';
    }

    return Container(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: textColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.admin_panel_settings_rounded : (isTenant ? Icons.domain_rounded : Icons.school_rounded),
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
  }
}
