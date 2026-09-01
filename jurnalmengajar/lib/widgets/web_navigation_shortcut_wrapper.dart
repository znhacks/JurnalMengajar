import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Global wrapper for handling Web and Desktop Navigation Shortcuts:
/// - Alt + Left Arrow / Cmd + Left Arrow (Standard browser back)
/// - Backspace key (when not typing in a text field)
/// - Mouse Back Button (side button on gaming/productivity mice)
/// - Trackpad horizontal two-finger swipe back
class WebNavigationShortcutWrapper extends StatefulWidget {
  final Widget child;
  final GoRouter router;

  const WebNavigationShortcutWrapper({
    super.key,
    required this.child,
    required this.router,
  });

  @override
  State<WebNavigationShortcutWrapper> createState() =>
      _WebNavigationShortcutWrapperState();
}

class _WebNavigationShortcutWrapperState
    extends State<WebNavigationShortcutWrapper> {
  DateTime _lastPopTime = DateTime.now();
  double _trackpadScrollAcc = 0.0;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  void _triggerGoBack() {
    final now = DateTime.now();
    if (now.difference(_lastPopTime).inMilliseconds < 350) return;
    _lastPopTime = now;

    if (widget.router.canPop()) {
      widget.router.pop();
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final key = event.logicalKey;

    // Alt + Left Arrow or Cmd + Left Arrow or BrowserBack key
    if ((isAlt && key == LogicalKeyboardKey.arrowLeft) ||
        (isMeta && key == LogicalKeyboardKey.arrowLeft) ||
        (isMeta && key == LogicalKeyboardKey.bracketLeft) ||
        key == LogicalKeyboardKey.browserBack) {
      _triggerGoBack();
      return true;
    }

    return false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    // Check for mouse back button (button 8 or kBackMouseButton)
    if (event.buttons == kBackMouseButton || event.buttons == 8) {
      _triggerGoBack();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Detect trackpad horizontal swipe (swiping right creates negative scrollDelta.dx)
      if (event.scrollDelta.dx < -60 && event.scrollDelta.dy.abs() < 25) {
        _trackpadScrollAcc += event.scrollDelta.dx.abs();
        if (_trackpadScrollAcc > 120) {
          _trackpadScrollAcc = 0.0;
          _triggerGoBack();
        }
      } else {
        _trackpadScrollAcc = 0.0;
      }
    }
  }

  void _handlePointerPanZoom(PointerPanZoomUpdateEvent event) {
    // Two-finger swipe on trackpad
    if (event.pan.dx > 60 && event.pan.dy.abs() < 25) {
      _triggerGoBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerSignal: _handlePointerSignal,
      onPointerPanZoomUpdate: _handlePointerPanZoom,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
