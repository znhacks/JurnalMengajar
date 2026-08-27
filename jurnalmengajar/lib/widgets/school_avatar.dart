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
    final Color backgroundColor = isSelected 
        ? const Color(0xFF4F46E5) 
        : const Color(0xFFCBD5E1);

    final fallbackIcon = Icon(
      Icons.school, // Standard school / education icon representing academia
      color: Colors.white,
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
