import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/core/services/cache_service.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/user_school_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Role & School Isolation Tests', () {
    test('UserSchoolModel parses active and inactive status correctly', () {
      final active = UserSchoolModel.fromJson({
        'id': '1',
        'user_id': 'u1',
        'school_id': 's1',
        'role': 'guru',
        'status': 'active',
      });
      expect(active.status, 'active');

      final inactive = UserSchoolModel.fromJson({
        'id': '2',
        'user_id': 'u1',
        'school_id': 's1',
        'role': 'guru',
        'status': 'inactive',
      });
      expect(inactive.status, 'inactive');
    });

    test('AuthProvider role classification getters', () {
      final fakeRepo = FakeAuthRepo();
      final authProvider = AuthProvider(authRepository: fakeRepo);

      expect(authProvider.isAdminAsli, isFalse);
      expect(authProvider.isAdminCadangan, isFalse);
      expect(authProvider.isGuruMurni, isTrue);
    });

    test('Admin Asli is locked to ADMIN and primary school', () async {
      final fakeRepo = FakeAuthRepo();
      final adminUser = UserModel(
        id: 'admin-id',
        email: 'admin@jurnal.com',
        fullName: 'Administrator',
        role: 'admin',
        schoolId: '00000000-0000-0000-0000-000000000001',
        schoolIds: ['00000000-0000-0000-0000-000000000001'],
      );
      fakeRepo.mockUser = adminUser;
      final authProvider = AuthProvider(authRepository: fakeRepo);
      await authProvider.login(adminUser.email, 'password');

      expect(authProvider.isAdminAsli, isTrue);
      expect(authProvider.isAdminCadangan, isFalse);
      expect(authProvider.isGuruMurni, isFalse);
      expect(authProvider.isExclusiveAdmin, isTrue);

      // Attempt to switch to guru or foreign school
      await authProvider.switchActiveSchool('00000000-0000-0000-0000-000000000099', 'SMKN 99', 'guru');
      // Must be clamped to admin and primary school
      expect(authProvider.activeRole, 'admin');
      expect(authProvider.activeSchoolId, '00000000-0000-0000-0000-000000000001');
      // User model role in memory must remain admin
      expect(authProvider.currentUser?.role, 'admin');
    });

    test('Admin Cadangan can toggle between admin and guru within their school', () async {
      final fakeRepo = FakeAuthRepo();
      final cadanganUser = UserModel(
        id: 'cadangan-id',
        email: 'guru@jurnal.com',
        fullName: 'Admin Cadangan',
        role: 'guru',
        schoolId: '00000000-0000-0000-0000-000000000001',
        schoolIds: ['00000000-0000-0000-0000-000000000001'],
      );
      fakeRepo.mockUser = cadanganUser;

      // Seed membership cache so user has admin role in SMKN 11
      await CacheService().save('user_memberships_cadangan-id', [
        {
          'id': 'us-1',
          'user_id': 'cadangan-id',
          'school_id': '00000000-0000-0000-0000-000000000001',
          'school_name': 'SMKN 11 Malang',
          'role': 'admin',
          'status': 'active',
        },
        {
          'id': 'us-2',
          'user_id': 'cadangan-id',
          'school_id': '00000000-0000-0000-0000-000000000001',
          'school_name': 'SMKN 11 Malang',
          'role': 'guru',
          'status': 'active',
        },
      ]);

      final authProvider = AuthProvider(authRepository: fakeRepo);
      await authProvider.login(cadanganUser.email, 'password');

      expect(authProvider.isAdminAsli, isFalse);
      expect(authProvider.isAdminCadangan, isTrue);
      expect(authProvider.isExclusiveAdmin, isFalse);

      // Switch to guru
      await authProvider.switchActiveSchool('00000000-0000-0000-0000-000000000001', 'SMKN 11 Malang', 'guru');
      expect(authProvider.activeRole, 'guru');
      // User base role in memory remains guru
      expect(authProvider.currentUser?.role, 'guru');

      // Switch back to admin
      await authProvider.switchActiveSchool('00000000-0000-0000-0000-000000000001', 'SMKN 11 Malang', 'admin');
      expect(authProvider.activeRole, 'admin');
      expect(authProvider.currentUser?.role, 'guru');
    });

    test('Guru Murni cannot switch to admin role', () async {
      final fakeRepo = FakeAuthRepo();
      final guruUser = UserModel(
        id: 'guru-id',
        email: 'guru.biasa@jurnal.com',
        fullName: 'Guru Biasa',
        role: 'guru',
        schoolId: '00000000-0000-0000-0000-000000000001',
        schoolIds: ['00000000-0000-0000-0000-000000000001'],
      );
      fakeRepo.mockUser = guruUser;
      final authProvider = AuthProvider(authRepository: fakeRepo);
      await authProvider.login(guruUser.email, 'password');

      expect(authProvider.isAdminAsli, isFalse);
      expect(authProvider.isAdminCadangan, isFalse);
      expect(authProvider.isGuruMurni, isTrue);

      // Attempt to switch to admin
      await authProvider.switchActiveSchool('00000000-0000-0000-0000-000000000001', 'SMKN 11 Malang', 'admin');
      // Must be clamped to guru
      expect(authProvider.activeRole, 'guru');
      expect(authProvider.currentUser?.role, 'guru');
    });
  });
}
