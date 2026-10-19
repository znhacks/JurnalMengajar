import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'admin_drawer.dart';
import 'guru_drawer.dart';

/// Lebar minimum (logical pixel) saat web desktop memakai sidebar permanen.
/// Nilainya mengikuti batas "Laptop / Desktop PC" yang dipakai di main.dart.
const double kDesktopSidebarBreakpoint = 1024;

/// Lebar sidebar permanen pada web desktop.
const double kDesktopSidebarWidth = 288;

class AppShell {
  const AppShell._();

  /// Hanya untuk widget test: memaksa/mematikan mode web desktop pada
  /// platform pengujian (kIsWeb bernilai false di `flutter test`).
  @visibleForTesting
  static bool? forceDesktopWeb;

  /// Sidebar permanen hanya aktif di web pada lebar desktop. Aplikasi mobile
  /// dan browser sempit tetap memakai menu geser (drawer) seperti sebelumnya.
  static bool isDesktopWeb(BuildContext context) {
    if (forceDesktopWeb != null) return forceDesktopWeb!;
    if (!kIsWeb) return false;
    return MediaQuery.sizeOf(context).width >= kDesktopSidebarBreakpoint;
  }
}

/// Membungkus seluruh aplikasi pada web desktop dengan sidebar yang selalu
/// terlihat di kiri. Karena dibungkus di level aplikasi, sidebar tetap ada
/// pada halaman yang dibuka lewat tombol push (detail, form, dll).
///
/// Di luar web desktop widget ini tidak mengubah apa pun.
class DesktopSidebarShell extends StatefulWidget {
  const DesktopSidebarShell({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<DesktopSidebarShell> createState() => _DesktopSidebarShellState();
}

class _DesktopSidebarShellState extends State<DesktopSidebarShell> {
  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_handleRouteChanged);
  }

  @override
  void didUpdateWidget(covariant DesktopSidebarShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routerDelegate.removeListener(_handleRouteChanged);
      widget.router.routerDelegate.addListener(_handleRouteChanged);
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_handleRouteChanged);
    super.dispose();
  }

  void _handleRouteChanged() {
    if (!mounted) return;

    // GoRouter bisa memberi tahu listener saat sedang membangun widget
    // (mis. saat route awal dipulihkan), jadi rebuild ditunda bila perlu.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      setState(() {});
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  String get _currentRoute {
    final uri = widget.router.routerDelegate.currentConfiguration.uri;
    return uri.hasQuery ? uri.toString() : uri.path;
  }

  /// Sidebar hanya ditampilkan pada halaman aplikasi, bukan pada login,
  /// splash, dan halaman pemulihan akun.
  bool _isAppRoute(String path) {
    return path.startsWith('/admin') ||
        path.startsWith('/guru') ||
        path == '/about';
  }

  @override
  Widget build(BuildContext context) {
    if (!AppShell.isDesktopWeb(context)) return widget.child;

    final authProvider = context.watch<AuthProvider>();
    if (!authProvider.isAuthenticated) return widget.child;

    final currentRoute = _currentRoute;
    final currentPath = currentRoute.split('?').first;
    if (!_isAppRoute(currentPath)) return widget.child;

    final media = MediaQuery.of(context);
    final contentWidth = media.size.width - kDesktopSidebarWidth;
    if (contentWidth <= 0) return widget.child;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: kDesktopSidebarWidth,
          child: Material(
            // Drawer menyediakan Material sebagai induk; di sini sidebar
            // permanen harus menyediakan sendiri agar ListTile/menu tetap
            // bisa menggambar ink splash.
            color: Theme.of(context).colorScheme.surface,
            child: authProvider.activeRole == 'admin'
                ? AdminDrawerPanel(
                    key: const ValueKey('desktop-sidebar-admin'),
                    currentRoute: currentRoute,
                    isPermanentSidebar: true,
                  )
                : GuruDrawerPanel(
                    key: const ValueKey('desktop-sidebar-guru'),
                    currentRoute: currentRoute,
                    isPermanentSidebar: true,
                  ),
          ),
        ),
        VerticalDivider(width: 1, thickness: 1),
        Expanded(
          child: MediaQuery(
            // Halaman di kanan hanya mendapat lebar area kontennya.
            data: media.copyWith(size: Size(contentWidth, media.size.height)),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
