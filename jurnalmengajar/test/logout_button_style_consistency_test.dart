import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/widgets/admin_drawer.dart';
import 'package:jurnalmengajar/widgets/guru_drawer.dart';

class FakeAuthRepo implements AuthRepository {
  UserModel? mockUser;

  @override
  Future<UserModel?> getCurrentUser() async => mockUser;
  @override
  Future<UserModel> login(String email, String password) async => mockUser!;
  @override
  Future<UserModel> loginWithGoogle() async => mockUser!;
  @override
  Future<void> logout() async => mockUser = null;
  @override
  Future<void> register(UserModel user, String password) async {}
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<void> changeEmail(String newEmail) async {}
  @override
  Future<UserModel> updateProfile(UserModel user) async => user;
  @override
  Future<void> updateFcmToken(String userId, String token) async {}
  @override
  Future<List<UserModel>> getAllUsers([String? schoolId]) async => [];
  @override
  Future<void> updateUserRole(String userId, String role, [String? schoolId]) async {}
  @override
  Future<void> deleteAccount(String userId) async {}
  @override
  Future<void> requestExitFromSchool(String membershipId, {String? schoolId, String? role, String? userId}) async {}
  @override
  Future<void> cancelExitRequest(String membershipId, {String? schoolId, String? role, String? userId}) async {}
  @override
  Future<List<Map<String, dynamic>>> getPendingExitRequests(String schoolId) async => [];
  @override
  Future<List<UserModel>> getAllUsersForSchool(String schoolId) async => [];
  @override
  Future<void> approveExitRequest(String membershipId) async {}
  @override
  Future<void> rejectExitRequest(String membershipId) async {}
  @override
  Future<void> rejectJoinRequest(String userId, String schoolId) async {}
  @override
  Future<void> leaveSchool({required String schoolId, required String userId, String? membershipId}) async {}
}

class FakeWarningLetterRepo implements WarningLetterRepository {
  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async => [];
  @override
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId, [String? schoolId]) async => [];
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

  Widget buildHost({
    required Widget child,
    required ThemeData theme,
    required AuthProvider authProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<WarningLetterProvider>(
          create: (_) => WarningLetterProvider(warningLetterRepository: FakeWarningLetterRepo()),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, _) => MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 800,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  AuthProvider createTestAuthProvider() {
    final fakeRepo = FakeAuthRepo();
    fakeRepo.mockUser = UserModel(
      id: 'u1',
      email: 'guru@test.com',
      fullName: 'Guru Test',
      role: 'guru',
      status: 'approved',
    );
    return AuthProvider(authRepository: fakeRepo);
  }

  group('Logout Button "Keluar" Color Consistency Tests', () {
    testWidgets('AdminDrawer (Left Reference) uses onSurface in Light Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = createTestAuthProvider();
      final lightTheme = AppTheme.lightTheme;
      final expectedColor = lightTheme.colorScheme.onSurface;

      await tester.pumpWidget(
        buildHost(
          child: const AdminDrawer(currentRoute: '/admin/dashboard'),
          theme: lightTheme,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      final keluarText = tester.widget<Text>(find.text('Keluar'));
      expect(keluarText.style?.color, equals(expectedColor));
      expect(keluarText.style?.color, isNot(equals(const Color(0xFFEF4444))));

      final logoutIcon = tester.widget<Icon>(find.byIcon(Icons.logout_rounded));
      expect(logoutIcon.color, equals(expectedColor));
      expect(logoutIcon.color, isNot(equals(const Color(0xFFEF4444))));
    });

    testWidgets('GuruDrawer (Right Target) uses onSurface in Light Mode to match AdminDrawer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = createTestAuthProvider();
      final lightTheme = AppTheme.lightTheme;
      final expectedColor = lightTheme.colorScheme.onSurface;

      await tester.pumpWidget(
        buildHost(
          child: const GuruDrawer(),
          theme: lightTheme,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      final keluarText = tester.widget<Text>(find.text('Keluar'));
      expect(keluarText.style?.color, equals(expectedColor));
      expect(keluarText.style?.color, isNot(equals(const Color(0xFFEF4444))));

      final logoutIcon = tester.widget<Icon>(find.byIcon(Icons.logout_rounded));
      expect(logoutIcon.color, equals(expectedColor));
      expect(logoutIcon.color, isNot(equals(const Color(0xFFEF4444))));
    });

    testWidgets('AdminDrawer (Left Reference) uses onSurface in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = createTestAuthProvider();
      final darkTheme = AppTheme.darkTheme;
      final expectedColor = darkTheme.colorScheme.onSurface;

      await tester.pumpWidget(
        buildHost(
          child: const AdminDrawer(currentRoute: '/admin/dashboard'),
          theme: darkTheme,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      final keluarText = tester.widget<Text>(find.text('Keluar'));
      expect(keluarText.style?.color, equals(expectedColor));
      expect(keluarText.style?.color, isNot(equals(const Color(0xFFEF4444))));

      final logoutIcon = tester.widget<Icon>(find.byIcon(Icons.logout_rounded));
      expect(logoutIcon.color, equals(expectedColor));
      expect(logoutIcon.color, isNot(equals(const Color(0xFFEF4444))));
    });

    testWidgets('GuruDrawer (Right Target) uses onSurface in Dark Mode to match AdminDrawer', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = createTestAuthProvider();
      final darkTheme = AppTheme.darkTheme;
      final expectedColor = darkTheme.colorScheme.onSurface;

      await tester.pumpWidget(
        buildHost(
          child: const GuruDrawer(),
          theme: darkTheme,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      final keluarText = tester.widget<Text>(find.text('Keluar'));
      expect(keluarText.style?.color, equals(expectedColor));
      expect(keluarText.style?.color, isNot(equals(const Color(0xFFEF4444))));

      final logoutIcon = tester.widget<Icon>(find.byIcon(Icons.logout_rounded));
      expect(logoutIcon.color, equals(expectedColor));
      expect(logoutIcon.color, isNot(equals(const Color(0xFFEF4444))));
    });

    testWidgets('Tapping "Keluar" in GuruDrawer opens confirmation dialog properly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = createTestAuthProvider();

      await tester.pumpWidget(
        buildHost(
          child: const GuruDrawer(),
          theme: AppTheme.lightTheme,
          authProvider: authProvider,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Keluar
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Logout'), findsOneWidget);
      expect(find.text('Apakah Anda yakin ingin keluar dari aplikasi?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Logout'), findsNothing);
    });
  });
}
