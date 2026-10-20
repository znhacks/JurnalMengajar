import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/widgets/admin_drawer.dart';
import 'package:jurnalmengajar/widgets/app_scaffold.dart';
import 'package:jurnalmengajar/widgets/desktop_sidebar_shell.dart';
import 'package:jurnalmengajar/widgets/guru_drawer.dart';

class _FakeAuthRepository implements AuthRepository {
  final UserModel? user;

  _FakeAuthRepository([this.user]);

  @override
  Future<UserModel?> getCurrentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWarningLetterRepo implements WarningLetterRepository {
  @override
  Future<List<WarningLetterModel>> getByTeacherId(
    String teacherId, [
    String? schoolId,
  ]) async => [];
  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(WarningLetterModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> markAsRead(String id) async {}
  @override
  Future<void> update(WarningLetterModel model) async {}
}

UserModel _adminUser() => UserModel(
  id: 'admin-1',
  email: 'admin@test.com',
  fullName: 'Administrator',
  role: 'admin',
  schoolId: 'school-1',
);

UserModel _guruUser() => UserModel(
  id: 'guru-1',
  email: 'guru@test.com',
  fullName: 'Guru Pengajar',
  role: 'guru',
  schoolId: 'school-1',
);

/// Halaman uji yang meniru pola layar aplikasi: drawer + tombol menu.
class _TestScreen extends StatelessWidget {
  const _TestScreen({this.useGuruDrawer = false, required this.label});

  final bool useGuruDrawer;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      drawer: useGuruDrawer
          ? const GuruDrawer(currentRoute: '/guru/dashboard')
          : const AdminDrawer(currentRoute: '/admin/dashboard'),
      appBar: AppBar(
        leading: AppMenuButton(
          child: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ),
        title: const Text('Halaman Uji'),
      ),
      body: Center(child: Text(label)),
    );
  }
}

/// Router dengan struktur yang sama dengan app_router.dart: halaman aplikasi
/// (admin/guru) berada di dalam ShellRoute, halaman auth di luar shell.
GoRouter _buildTestRouter({required bool guru}) {
  return GoRouter(
    initialLocation: guru ? '/guru/dashboard' : '/admin/dashboard',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Form Login'))),
      ),
      ShellRoute(
        builder: (context, state, child) => DesktopSidebarShell(
          currentRoute: state.uri.hasQuery
              ? state.uri.toString()
              : state.uri.path,
          child: child,
        ),
        routes: [
          if (guru)
            GoRoute(
              path: '/guru/dashboard',
              builder: (context, state) =>
                  const _TestScreen(useGuruDrawer: true, label: 'Isi Halaman'),
            ),
          if (!guru) ...[
            GoRoute(
              path: '/admin/dashboard',
              builder: (context, state) =>
                  const _TestScreen(label: 'Isi Halaman'),
            ),
            GoRoute(
              path: '/admin/teacher-statistics',
              builder: (context, state) =>
                  const _TestScreen(label: 'Halaman Statistik'),
            ),
          ],
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    AppShell.forceDesktopWeb = null;
  });

  Widget buildTestApp({
    required WidgetTester tester,
    required UserModel user,
    required GoRouter router,
    Size screenSize = const Size(1440, 900),
  }) {
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final authProvider = AuthProvider(
      authRepository: _FakeAuthRepository(user),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: ThemeProvider()),
        ChangeNotifierProvider<WarningLetterProvider>.value(
          value: WarningLetterProvider(
            warningLetterRepository: _FakeWarningLetterRepo(),
          ),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(1280, 800),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQueryData(size: screenSize),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  group('Web desktop sidebar', () {
    testWidgets('sidebar admin tampil permanen dan tombol menu disembunyikan', (
      tester,
    ) async {
      AppShell.forceDesktopWeb = true;
      final router = _buildTestRouter(guru: false);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        buildTestApp(tester: tester, user: _adminUser(), router: router),
      );
      await tester.pumpAndSettle();

      // Sidebar tetap terlihat tanpa perlu membuka drawer
      expect(find.byType(AdminDrawerPanel), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      expect(find.text('Statistik Guru'), findsOneWidget);
      expect(find.text('Isi Halaman'), findsOneWidget);

      // Tombol menu disembunyikan (sidebar sudah selalu tampil)
      expect(find.byIcon(Icons.menu_rounded), findsNothing);

      // Konten berada di kanan sidebar, tidak tertutup
      final sidebarWidth = tester.getSize(find.byType(AdminDrawerPanel)).width;
      expect(
        sidebarWidth,
        moreOrLessEquals(kDesktopSidebarWidth, epsilon: 0.5),
      );
    });

    testWidgets('menu di sidebar benar-benar menavigasi halaman', (
      tester,
    ) async {
      AppShell.forceDesktopWeb = true;
      final router = _buildTestRouter(guru: false);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        buildTestApp(tester: tester, user: _adminUser(), router: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Statistik Guru'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Halaman Statistik'), findsOneWidget);
      // Sidebar tetap ada setelah navigasi
      expect(find.byType(AdminDrawerPanel), findsOneWidget);
    });

    testWidgets('dialog dari sidebar tetap bisa dibuka', (tester) async {
      AppShell.forceDesktopWeb = true;
      final router = _buildTestRouter(guru: false);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        buildTestApp(tester: tester, user: _adminUser(), router: router),
      );
      await tester.pumpAndSettle();

      // Tombol "Keluar" membuka dialog konfirmasi (butuh akses Navigator)
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Konfirmasi Keluar'), findsOneWidget);

      // Batalkan dialog
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Keluar'), findsNothing);
    });

    testWidgets('sidebar guru tampil permanen di halaman guru', (tester) async {
      AppShell.forceDesktopWeb = true;
      final router = _buildTestRouter(guru: true);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        buildTestApp(tester: tester, user: _guruUser(), router: router),
      );
      await tester.pumpAndSettle();

      expect(find.byType(GuruDrawerPanel), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
    });

    testWidgets('sidebar ikut hilang di halaman login (luar shell)', (
      tester,
    ) async {
      AppShell.forceDesktopWeb = true;
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Form Login'))),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        buildTestApp(tester: tester, user: _adminUser(), router: router),
      );
      await tester.pumpAndSettle();

      expect(find.text('Form Login'), findsOneWidget);
      expect(find.byType(AdminDrawerPanel), findsNothing);
    });

    testWidgets('di luar web desktop drawer geser tetap seperti semula', (
      tester,
    ) async {
      AppShell.forceDesktopWeb = false;
      final router = _buildTestRouter(guru: false);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        buildTestApp(tester: tester, user: _adminUser(), router: router),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminDrawerPanel), findsNothing);
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // Drawer masih bisa dibuka seperti di aplikasi mobile
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(AdminDrawerPanel), findsOneWidget);
      expect(find.text('Statistik Guru'), findsOneWidget);

      // Dan menavigasi tetap berfungsi dari drawer
      await tester.tap(find.text('Statistik Guru'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Halaman Statistik'), findsOneWidget);
    });
  });
}