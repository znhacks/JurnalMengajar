import 'package:flutter/material.dart';

class WaveClipper extends CustomClipper<Path> {
  const WaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    // Start from top-left, go down to almost the bottom
    path.lineTo(0.0, size.height - 40);

    // Beautiful cubic bezier wave mirroring the Stitch design
    final controlPoint1 = Offset(size.width * 0.3, size.height);
    final controlPoint2 = Offset(size.width * 0.7, size.height - 80);
    final endPoint = Offset(size.width, size.height - 40);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint.dx,
      endPoint.dy,
    );

    // Draw line to top-right
    path.lineTo(size.width, 0.0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
