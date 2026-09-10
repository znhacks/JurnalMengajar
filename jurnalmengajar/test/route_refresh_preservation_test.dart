import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/core/router/app_router.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';

class TestMockAuthRepo implements AuthRepository {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Route Refresh & Deep Link Preservation Tests', () {
    testWidgets('AppRouter registers all deep link and tab routes', (tester) async {
      final fakeRepo = TestMockAuthRepo();
      final guruUser = UserModel(
        id: 'guru-1',
        email: 'guru@sekolah.sch.id',
        fullName: 'Guru Teladan',
        role: 'guru',
        schoolId: 'sch-1',
      );
      fakeRepo.mockUser = guruUser;

      final authProvider = AuthProvider(authRepository: fakeRepo);

      late GoRouter router;
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider,
          child: Builder(
            builder: (context) {
              router = AppRouter.router(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final routes = router.configuration.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      // Guru deep links
      expect(routes, contains('/guru/dashboard'));
      expect(routes, contains('/guru/jadwal'));
      expect(routes, contains('/guru/jurnal'));
      expect(routes, contains('/guru/profil'));
      expect(routes, contains('/guru/statistik'));
      expect(routes, contains('/guru/statistics'));
      expect(routes, contains('/guru/download-jurnal'));
      expect(routes, contains('/guru/warning-letters'));

      // Admin deep links
      expect(routes, contains('/admin/dashboard'));
      expect(routes, contains('/admin/master-data/users'));
      expect(routes, contains('/admin/master-data/teachers'));
      expect(routes, contains('/admin/master-data/classes'));
      expect(routes, contains('/admin/schedules'));
      expect(routes, contains('/admin/approvals'));
      expect(routes, contains('/admin/journals'));

      // Auth & Root
      expect(routes, contains('/'));
      expect(routes, contains('/splash'));
      expect(routes, contains('/login'));
    });

    test('AuthProvider restores user, active role, and active school consistently', () async {
      final fakeRepo = TestMockAuthRepo();
      final guruUser = UserModel(
        id: 'guru-test',
        email: 'guru@sekolah.sch.id',
        fullName: 'Guru Pengajar',
        role: 'guru',
        schoolId: 'sch-001',
      );
      fakeRepo.mockUser = guruUser;

      final authProvider = AuthProvider(authRepository: fakeRepo);
      await authProvider.login('guru@sekolah.sch.id', 'password');

      // Verify state after authentication
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser?.id, 'guru-test');
      expect(authProvider.activeRole, 'guru');
      expect(authProvider.activeSchoolId, 'sch-001');

      // Verify Guru cannot switch to admin role
      await authProvider.switchActiveSchool('sch-001', 'SMK 1', 'admin');
      expect(authProvider.activeRole, 'guru'); // Still guru
    });
  });
}
