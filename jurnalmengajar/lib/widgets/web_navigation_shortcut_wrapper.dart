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
/// - Forward counterparts (Alt/Cmd/Ctrl + Right Arrow, mouse forward button,
///   trackpad swipe left) return to the page left via the back actions above.
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
  DateTime _lastForwardTime = DateTime.fromMillisecondsSinceEpoch(0);
  double _trackpadScrollAcc = 0.0;
  double _trackpadForwardScrollAcc = 0.0;

  /// Locations left behind when a page leaves the route stack, newest last.
  /// Powers the forward (swipe-to-return) gesture. A fresh push navigation
  /// clears it, so forward never jumps somewhere surprising.
  final List<String> _forwardStack = [];
  String? _pendingForwardTo;
  String _lastLocation = '';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _lastLocation = _currentLocation() ?? '';
    widget.router.routerDelegate.addListener(_handleRouteChange);
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_handleRouteChange);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  String? _currentLocation() {
    try {
      final config = widget.router.routerDelegate.currentConfiguration;
      final matches = config.matches;
      if (matches.isEmpty) {
        final uri = config.uri.toString();
        return uri.isEmpty ? null : uri;
      }
      final last = matches.last;
      if (last is ImperativeRouteMatch) {
        // Pushed pages keep the list uri stale; the inner list holds the page uri.
        return last.matches.uri.toString();
      }
      return config.uri.toString();
    } catch (_) {
      return null;
    }
  }

  void _handleRouteChange() {
    if (!mounted) return;
    final current = _currentLocation();
    if (current == null || current == _lastLocation || _lastLocation.isEmpty) {
      if (current != null) _lastLocation = current;
      return;
    }
    if (_pendingForwardTo != null) {
      // Arrival from our own forward action: entry already consumed.
      _pendingForwardTo = null;
    } else if (_departureStillInStack(_lastLocation)) {
      // Fresh navigation pushed on top: forward history is invalid.
      _forwardStack.clear();
    } else {
      // Departed page left the stack (back pop, fallback, browser back):
      // it becomes a forward target.
      _forwardStack.add(_lastLocation);
      if (_forwardStack.length > 20) _forwardStack.removeAt(0);
    }
    _lastLocation = current;
  }

  bool _departureStillInStack(String departure) {
    try {
      final departurePath = Uri.parse(departure).path;
      final matches = widget.router.routerDelegate.currentConfiguration.matches;
      return matches.any((m) => m.matchedLocation == departurePath);
    } catch (_) {
      return true;
    }
  }

  bool _isEditingText() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    final context = focus.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    if (context.findAncestorStateOfType<EditableTextState>() != null)
      return true;
    if (context.findAncestorWidgetOfExactType<EditableText>() != null)
      return true;
    return false;
  }

  void _triggerGoBack() {
    final now = DateTime.now();
    if (now.difference(_lastPopTime).inMilliseconds < 300) return;
    _lastPopTime = now;

    // Check if root navigator has an active modal/dialog/sheet to pop first
    final rootNav = widget.router.routerDelegate.navigatorKey.currentState;
    if (rootNav != null && rootNav.canPop()) {
      rootNav.pop();
      return;
    }

    final from = _currentLocation();
    if (widget.router.canPop()) {
      widget.router.pop();
      return;
    }

    try {
      final location =
          from ??
          widget.router.routerDelegate.currentConfiguration.uri.toString();
      String? fallback;
      if (location.startsWith('/admin') && location != '/admin/dashboard') {
        fallback = '/admin/dashboard';
      } else if (location.startsWith('/guru') &&
          location != '/guru/dashboard') {
        fallback = '/guru/dashboard';
      } else if (location == '/register' || location == '/reset-password') {
        fallback = '/login';
      } else if (location == '/about') {
        fallback = '/guru/dashboard';
      }
      if (fallback != null && fallback != location) {
        widget.router.go(fallback);
      }
    } catch (e) {
      debugPrint('Navigation shortcut fallback error: $e');
    }
  }

  void _triggerGoForward() {
    final now = DateTime.now();
    if (now.difference(_lastForwardTime).inMilliseconds < 300) return;
    _lastForwardTime = now;

    if (_forwardStack.isEmpty) return;
    final target = _forwardStack.removeLast();
    if (target == _currentLocation()) return;
    _pendingForwardTo = target;
    try {
      widget.router.go(target);
    } catch (e) {
      debugPrint('Navigation shortcut forward error: $e');
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

    // 1b. Alt + Right Arrow or Cmd + Right Arrow or Cmd + ] or BrowserForward key
    if ((isAlt && key == LogicalKeyboardKey.arrowRight) ||
        (isMeta && key == LogicalKeyboardKey.arrowRight) ||
        (isMeta && key == LogicalKeyboardKey.bracketRight) ||
        key == LogicalKeyboardKey.browserForward) {
      _triggerGoForward();
      return true;
    }

    // 2b. Ctrl + Right Arrow (navigates forward when not actively editing text)
    if (isControl && key == LogicalKeyboardKey.arrowRight) {
      if (!_isEditingText()) {
        _triggerGoForward();
        return true;
      }
    }

    // 3. Escape key (Priority 1: close text focus, Priority 2: close open dialog/modal, Priority 3: navigate back)
    if (key == LogicalKeyboardKey.escape) {
      if (_isEditingText()) {
        FocusManager.instance.primaryFocus?.unfocus();
        return false;
      }

      // Prioritas 1: Tutup modal/dialog jika sedang terbuka
      final rootNav = widget.router.routerDelegate.navigatorKey.currentState;
      if (rootNav != null && rootNav.canPop()) {
        rootNav.pop();
        return true;
      }

      // Prioritas 2: Jika tidak ada modal/dialog yang terbuka, navigasi Back sesuai riwayat
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
    // Check for mouse forward button (button 16 or kForwardMouseButton)
    if (event.buttons == kForwardMouseButton || event.buttons == 16) {
      _triggerGoForward();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      // Detect trackpad horizontal swipe (swiping right creates negative scrollDelta.dx)
      if (event.scrollDelta.dx < -30 && event.scrollDelta.dy.abs() < 30) {
        _trackpadScrollAcc += event.scrollDelta.dx.abs();
        _trackpadForwardScrollAcc = 0.0;
        if (_trackpadScrollAcc > 60) {
          _trackpadScrollAcc = 0.0;
          _triggerGoBack();
        }
      } else if (event.scrollDelta.dx > 30 && event.scrollDelta.dy.abs() < 30) {
        // Opposite direction: trackpad swipe left returns forward.
        _trackpadForwardScrollAcc += event.scrollDelta.dx.abs();
        _trackpadScrollAcc = 0.0;
        if (_trackpadForwardScrollAcc > 60) {
          _trackpadForwardScrollAcc = 0.0;
          _triggerGoForward();
        }
      } else {
        _trackpadScrollAcc = 0.0;
        _trackpadForwardScrollAcc = 0.0;
      }
    }
  }

  void _handlePointerPanZoom(PointerPanZoomUpdateEvent event) {
    // Two-finger swipe on trackpad
    if (event.pan.dx > 30 && event.pan.dy.abs() < 30) {
      _triggerGoBack();
    } else if (event.pan.dx < -30 && event.pan.dy.abs() < 30) {
      _triggerGoForward();
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
