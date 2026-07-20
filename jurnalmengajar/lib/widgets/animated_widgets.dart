import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// An interactive widget that scales down slightly when pressed, providing tactile bounce feedback.
class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final Duration duration;

  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 120),
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null || widget.onLongPress != null) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// A wrapper widget that smoothly slides up and fades in when rendered.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.slideOffset = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: delay)
        .fadeIn(duration: duration, curve: Curves.easeOutQuad)
        .slideY(
          begin: slideOffset,
          end: 0,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
  }
}

/// A widget that gently pulses (scales up and down continuously) to draw attention to badges or status indicators.
class PulsingBadge extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double maxScale;

  const PulsingBadge({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1200),
    this.maxScale = 1.08,
  });

  @override
  Widget build(BuildContext context) {
    return child.animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(
          begin: const Offset(1.0, 1.0),
          end: Offset(maxScale, maxScale),
          duration: duration,
          curve: Curves.easeInOut,
        );
  }
}
