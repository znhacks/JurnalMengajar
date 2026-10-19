import 'package:flutter/material.dart';

import 'desktop_sidebar_shell.dart';

/// Pengganti langsung [Scaffold] untuk halaman yang memakai menu geser.
///
/// Pada web desktop, sidebar sudah selalu terlihat di kiri sehingga drawer
/// dimatikan (tombol menu otomatis dari Scaffold ikut hilang). Di luar web
/// desktop perilakunya sama persis dengan [Scaffold] biasa.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.appBar,
    this.body,
    this.drawer,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.bottomSheet,
    this.endDrawer,
    this.bottomNavigationBar,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? drawer;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final List<Widget>? persistentFooterButtons;
  final Widget? bottomSheet;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final hasPermanentSidebar = AppShell.isDesktopWeb(context);

    return Scaffold(
      appBar: appBar,
      // Drawer geser hanya dipakai saat sidebar belum permanen.
      drawer: hasPermanentSidebar ? null : drawer,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      persistentFooterButtons: persistentFooterButtons,
      bottomSheet: bottomSheet,
      endDrawer: endDrawer,
      bottomNavigationBar: bottomNavigationBar,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: body,
    );
  }
}

/// Membungkus tombol menu drawer pada AppBar.
///
/// Pada web desktop tombol ini disembunyikan karena menu sudah selalu tampil
/// di sidebar, sedangkan di layar sempit perilakunya tidak berubah sama sekali.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppShell.isDesktopWeb(context)) return const SizedBox.shrink();
    return child;
  }
}
