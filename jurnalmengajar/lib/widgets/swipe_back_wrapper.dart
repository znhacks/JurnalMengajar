import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A premium wrapper widget that enables iOS/Safari-style interactive swipe-to-back gesture
/// from the left side of the screen for both Web and Mobile platforms.
/// Includes visual floating back indicator and responsive gesture zone.
class SwipeBackWrapper extends StatefulWidget {
  final Widget child;
  final bool enableSwipe;
  final double? edgeThreshold; // If null, calculates dynamically based on screen width

  const SwipeBackWrapper({
    super.key,
    required this.child,
    this.enableSwipe = true,
    this.edgeThreshold,
  });

  @override
  State<SwipeBackWrapper> createState() => _SwipeBackWrapperState();
}

class _SwipeBackWrapperState extends State<SwipeBackWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = Tween<double>(begin: 0.0, end: 0.0).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double _getEdgeThreshold(double screenWidth) {
    if (widget.edgeThreshold != null) return widget.edgeThreshold!;
    // On web/desktop, allow starting the swipe from up to 25% of the screen width (or min 140px)
    if (kIsWeb || screenWidth > 600) {
      return math.max(140.0, screenWidth * 0.25);
    }
    return 100.0;
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!widget.enableSwipe) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final maxThreshold = _getEdgeThreshold(screenWidth);

    // Only allow starting drag from the left zone
    if (details.globalPosition.dx > maxThreshold) return;

    // Check if the router or navigator can pop
    if (!context.canPop() && !Navigator.of(context).canPop()) return;

    _animController.stop();
    setState(() {
      _isDragging = true;
      _dragOffset = 0.0;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    if (details.delta.dx < 0 && _dragOffset <= 0) return;

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx)
          .clamp(0.0, MediaQuery.of(context).size.width);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.primaryVelocity ?? 0;
    final threshold = kIsWeb || screenWidth > 600 ? 120.0 : screenWidth * 0.22;
    final shouldPop = _dragOffset > threshold || velocity > 320;

    if (shouldPop) {
      // Animate out to the right and trigger pop
      _animation = Tween<double>(begin: _dragOffset, end: screenWidth).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
      )..addListener(() {
          if (mounted) {
            setState(() {
              _dragOffset = _animation.value;
            });
          }
        });

      _animController.duration = const Duration(milliseconds: 160);
      _animController.forward(from: 0.0).then((_) {
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            Navigator.of(context).maybePop();
          }
        }
      });
    } else {
      // Animate back to original position
      _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
      )..addListener(() {
          if (mounted) {
            setState(() {
              _dragOffset = _animation.value;
            });
          }
        });

      _animController.duration = const Duration(milliseconds: 180);
      _animController.forward(from: 0.0).then((_) {
        if (mounted) {
          setState(() {
            _isDragging = false;
            _dragOffset = 0.0;
          });
        }
      });
    }
  }

  void _onHorizontalDragCancel() {
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
      _dragOffset = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableSwipe) return widget.child;

    final screenWidth = MediaQuery.of(context).size.width;
    final progress = screenWidth > 0 ? (_dragOffset / screenWidth).clamp(0.0, 1.0) : 0.0;
    final popThreshold = kIsWeb || screenWidth > 600 ? 120.0 : screenWidth * 0.22;
    final isReadyToPop = _dragOffset >= popThreshold;

    return GestureDetector(
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Background scrim during drag
          if (_isDragging && _dragOffset > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15 * (1.0 - progress)),
                ),
              ),
            ),

          // Translated foreground page with subtle elevation shadow during swipe
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: Container(
              decoration: _isDragging && _dragOffset > 0
                  ? BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 20,
                          offset: const Offset(-6, 0),
                        ),
                      ],
                    )
                  : null,
              child: widget.child,
            ),
          ),

          // Floating Back Indicator on the left edge while dragging
          if (_isDragging && _dragOffset > 15)
            Positioned(
              left: math.min(_dragOffset * 0.35, 36.0),
              top: MediaQuery.of(context).size.height * 0.45,
              child: AnimatedScale(
                scale: isReadyToPop ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isReadyToPop
                        ? const Color(0xFF2563EB)
                        : Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isReadyToPop
                                ? const Color(0xFF2563EB)
                                : Colors.black)
                            .withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: isReadyToPop ? 22 : 18,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
