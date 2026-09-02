import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SchoolAvatar extends StatelessWidget {
  final String? logoUrl;
  final String schoolName;
  final double radius;
  final bool isSelected;

  const SchoolAvatar({
    super.key,
    required this.logoUrl,
    required this.schoolName,
    this.radius = 20,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor = isSelected 
        ? const Color(0xFF4F46E5) 
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    final Color iconColor = isSelected
        ? Colors.white
        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF64748B));

    final fallbackIcon = Icon(
      Icons.school_rounded,
      color: iconColor,
      size: (radius * 1.1).r,
    );

    return CircleAvatar(
      backgroundColor: backgroundColor,
      radius: radius.r,
      child: logoUrl != null && logoUrl!.trim().isNotEmpty
          ? ClipOval(
              child: Image.network(
                logoUrl!.trim(),
                width: (radius * 2).r,
                height: (radius * 2).r,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallbackIcon,
              ),
            )
          : fallbackIcon,
    );
  }
}
