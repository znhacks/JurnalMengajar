import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/widgets/admin_drawer.dart';
import 'package:jurnalmengajar/widgets/guru_drawer.dart';

import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<UserModel?> getCurrentUser() async {
    return UserModel(
      id: 'test-admin',
      email: 'admin@test.com',
      fullName: 'Administrator',
      role: 'admin',
      schoolId: 'school-1',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWarningLetterRepo implements WarningLetterRepository {
  @override
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId, [String? schoolId]) async => [];
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required Widget child,
    required Size screenSize,
    ThemeData? theme,
  }) {
    final fakeRepo = _FakeAuthRepository();
    final authProvider = AuthProvider(authRepository: fakeRepo);
    final themeProvider = ThemeProvider();
    final warningProvider = WarningLetterProvider(warningLetterRepository: _FakeWarningLetterRepo());

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<WarningLetterProvider>.value(value: warningProvider),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(size: screenSize),
            child: Scaffold(
              drawer: child,
              body: Builder(
                builder: (scaffoldCtx) => Center(
                  child: ElevatedButton(
                    onPressed: () => Scaffold.of(scaffoldCtx).openDrawer(),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Sidebar / Drawer Overflow & Layout Tests', () {
    testWidgets('AdminDrawer renders without overflow and enforces antiAlias clipping & rounded corners', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: const AdminDrawer(currentRoute: '/admin/dashboard'),
          screenSize: const Size(540, 960),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify Drawer shape and clipBehavior
      final drawerFinder = find.byType(Drawer);
      expect(drawerFinder, findsOneWidget);
      final drawerWidget = tester.widget<Drawer>(drawerFinder);
      expect(drawerWidget.clipBehavior, equals(Clip.antiAlias));
      expect(drawerWidget.shape, isA<RoundedRectangleBorder>());

      // Verify dedicated footer items exist
      expect(find.text('Profil Saya'), findsOneWidget);
      expect(find.text('Mode Terang'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);

      // Verify no RenderFlex overflow exception occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminDrawer does NOT overflow on compact / small screen height (e.g. 400px)', (tester) async {
      tester.view.physicalSize = const Size(800, 800); // 400px logical height
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: const AdminDrawer(currentRoute: '/admin/dashboard'),
          screenSize: const Size(400, 400),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // On compact height, SingleChildScrollView is used to prevent any overflow
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // All items should still exist and be accessible via scrolling
      expect(find.text('Dashboard'), findsOneWidget);

      // Scroll to bottom
      await tester.drag(find.text('Dashboard'), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Profil Saya'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);

      // Absolutely zero RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('GuruDrawer renders without overflow and enforces antiAlias clipping & rounded corners', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: const GuruDrawer(currentRoute: '/guru/dashboard'),
          screenSize: const Size(540, 960),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Verify Drawer shape and clipBehavior
      final drawerFinder = find.byType(Drawer);
      expect(drawerFinder, findsOneWidget);
      final drawerWidget = tester.widget<Drawer>(drawerFinder);
      expect(drawerWidget.clipBehavior, equals(Clip.antiAlias));
      expect(drawerWidget.shape, isA<RoundedRectangleBorder>());

      expect(find.text('Keluar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GuruDrawer does NOT overflow on compact screen height (e.g. 400px)', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: const GuruDrawer(currentRoute: '/guru/dashboard'),
          screenSize: const Size(400, 400),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
