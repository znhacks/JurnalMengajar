import 'package:flutter/material.dart';

class WaveClipper extends CustomClipper<Path> {
  const WaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    // Start from top-left, go down to almost the bottom
    path.lineTo(0.0, size.height - 25);

    // Smooth cubic bezier wave
    final controlPoint1 = Offset(size.width * 0.35, size.height + 5);
    final controlPoint2 = Offset(size.width * 0.70, size.height - 45);
    final endPoint = Offset(size.width, size.height - 25);

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
