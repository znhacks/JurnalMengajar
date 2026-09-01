import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Global wrapper for handling Web and Desktop Navigation Shortcuts:
/// - Alt + Left Arrow / Cmd + Left Arrow (Standard browser back)
/// - Ctrl + Left Arrow (when not editing text)
/// - Escape key (Esc to go back / unfocus)
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

  bool _isEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    if (context.findAncestorStateOfType<EditableTextState>() != null) return true;
    if (context.findAncestorWidgetOfExactType<EditableText>() != null) return true;
    return false;
  }

  void _triggerGoBack() {
    final now = DateTime.now();
    if (now.difference(_lastPopTime).inMilliseconds < 300) return;
    _lastPopTime = now;

    if (widget.router.canPop()) {
      widget.router.pop();
      return;
    }

    try {
      final location =
          widget.router.routerDelegate.currentConfiguration.uri.toString();
      if (location.startsWith('/admin') && location != '/admin/dashboard') {
        widget.router.go('/admin/dashboard');
      } else if (location.startsWith('/guru') &&
          location != '/guru/dashboard') {
        widget.router.go('/guru/dashboard');
      } else if (location == '/register' || location == '/reset-password') {
        widget.router.go('/login');
      } else if (location == '/about') {
        widget.router.go('/guru/dashboard');
      }
    } catch (e) {
      debugPrint('Navigation shortcut fallback error: $e');
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final isControl = HardwareKeyboard.instance.isControlPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;
    final key = event.logicalKey;

    // 1. Alt + Left Arrow or Cmd + Left Arrow or Cmd + [ or BrowserBack key
    if ((isAlt && key == LogicalKeyboardKey.arrowLeft) ||
        (isMeta && key == LogicalKeyboardKey.arrowLeft) ||
        (isMeta && key == LogicalKeyboardKey.bracketLeft) ||
        key == LogicalKeyboardKey.browserBack) {
      _triggerGoBack();
      return true;
    }

    // 2. Ctrl + Left Arrow (navigates back when not actively editing text)
    if (isControl && key == LogicalKeyboardKey.arrowLeft) {
      if (!_isEditingText()) {
        _triggerGoBack();
        return true;
      }
    }

    // 3. Escape key (Esc to close focus or navigate back)
    if (key == LogicalKeyboardKey.escape) {
      if (_isEditingText()) {
        FocusManager.instance.primaryFocus?.unfocus();
        return false;
      } else {
        _triggerGoBack();
        return true;
      }
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
      if (event.scrollDelta.dx < -30 && event.scrollDelta.dy.abs() < 30) {
        _trackpadScrollAcc += event.scrollDelta.dx.abs();
        if (_trackpadScrollAcc > 60) {
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
    if (event.pan.dx > 30 && event.pan.dy.abs() < 30) {
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
