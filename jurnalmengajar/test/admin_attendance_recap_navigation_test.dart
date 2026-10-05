import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/widgets/admin_drawer.dart';
import 'package:jurnalmengajar/widgets/guru_drawer.dart';

class _FakeAuthRepository implements AuthRepository {
  final UserModel? _mockUser;
  _FakeAuthRepository(this._mockUser);

  @override
  Future<UserModel?> getCurrentUser() async => _mockUser;

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
    required UserModel user,
  }) {
    final fakeRepo = _FakeAuthRepository(user);
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
          theme: AppTheme.lightTheme,
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

  testWidgets('AdminDrawer includes Rekap Kehadiran menu item', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final adminUser = UserModel(
      id: 'admin_1',
      fullName: 'Admin Sekolah',
      email: 'admin@sekolah.sch.id',
      role: 'admin',
      registeredRole: 'admin',
      schoolId: 'sch_1',
      schoolName: 'SMK Negeri 1',
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const AdminDrawer(currentRoute: '/admin/dashboard'),
        screenSize: const Size(540, 960),
        user: adminUser,
      ),
    );
    await tester.pumpAndSettle();

    // Open drawer
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Rekap Kehadiran'), findsOneWidget);
    expect(find.byIcon(Icons.fact_check_rounded), findsOneWidget);
  });

  testWidgets('GuruDrawer DOES NOT include Rekap Kehadiran menu item', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final guruUser = UserModel(
      id: 'guru_1',
      fullName: 'Bapak Guru',
      email: 'guru@sekolah.sch.id',
      role: 'guru',
      registeredRole: 'guru',
      schoolId: 'sch_1',
      schoolName: 'SMK Negeri 1',
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const GuruDrawer(currentRoute: '/guru/dashboard'),
        screenSize: const Size(540, 960),
        user: guruUser,
      ),
    );
    await tester.pumpAndSettle();

    // Open drawer
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Rekap Kehadiran'), findsNothing);
  });
}
