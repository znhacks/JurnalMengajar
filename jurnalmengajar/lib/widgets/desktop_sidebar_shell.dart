import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

/// Layout aplikasi untuk web desktop: menu sidebar dikunci di kiri dan konten
/// halaman berada di sebelahnya.
///
/// Widget ini dipakai sebagai builder [ShellRoute] sehingga posisinya berada
/// DI DALAM Navigator. Thanks to that, navigasi (`context.go/push`),
/// `showDialog`, dan `Navigator.pop` dari menu sidebar tetap bekerja seperti
/// biasanya, dan halaman yang dibuka lewat push tidak menutupi sidebar.
///
/// Di luar web desktop widget ini hanya meneruskan [child] tanpa perubahan.
class DesktopSidebarShell extends StatelessWidget {
  const DesktopSidebarShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  /// Route aktif untuk menandai menu yang sedang terbuka.
  final String currentRoute;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppShell.isDesktopWeb(context)) return child;

    final media = MediaQuery.of(context);
    final contentWidth = media.size.width - kDesktopSidebarWidth;
    if (contentWidth <= 0) return child;

    final isAdmin = context.watch<AuthProvider>().activeRole == 'admin';

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
            child: isAdmin
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
            child: child,
          ),
        ),
      ],
    );
  }
}