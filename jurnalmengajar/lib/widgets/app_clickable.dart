import 'package:flutter/material.dart';

/// A lightweight, clean, and accessible wrapper that ensures interactive elements
/// display the standard pointer (hand) cursor on Web and Desktop when clickable.
///
/// Use this in place of raw [GestureDetector] whenever an element can be clicked
/// or tapped by the user, providing consistent visual feedback across all platforms.
class AppClickable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HitTestBehavior behavior;
  final MouseCursor cursor;

  const AppClickable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior = HitTestBehavior.opaque,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = onTap != null || onLongPress != null;
    return MouseRegion(
      cursor: isInteractive ? cursor : MouseCursor.defer,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: behavior,
        child: child,
      ),
    );
  }
}
