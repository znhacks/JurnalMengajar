import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// WebResponsiveContainer ensures that on Web (Chrome/Desktop browsers)
/// the mobile UI is centered with a max-width limit and shadow/border,
/// preventing stretched/distorted mobile views on large desktop screens,
/// while leaving the mobile native experience untouched.
class WebResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color backgroundColor;

  const WebResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 900.0,
    this.backgroundColor = const Color(0xFFF8FAFC),
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > maxWidth) {
          return Container(
            color: const Color(0xFFE2E8F0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: child,
                  ),
                ),
              ),
            ),
          );
        }
        return child;
      },
    );
  }
}
