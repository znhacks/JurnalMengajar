import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';

class MockAdminUserRemovalRepo implements AuthRepository {
  UserModel? mockUser;
  final List<Map<String, dynamic>> userSchoolsDb = [];
  final List<UserModel> usersDb = [];

  @override
  Future<UserModel?> getCurrentUser() async => mockUser;

  @override
  Future<UserModel> login(String email, String password) async => mockUser!;

  @override
  Future<UserModel> loginWithGoogle() async => mockUser!;

  @override
  Future<void> logout() async => mockUser = null;

  @override
  Future<void> register(UserModel user, String password) async {
    usersDb.add(user);
  }

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> changeEmail(String newEmail) async {}

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    mockUser = user;
    return user;
  }

  @override
  Future<void> updateFcmToken(String userId, String token) async {}

  @override
  Future<List<UserModel>> getAllUsers([String? schoolId]) async => usersDb;

  @override
  Future<List<UserModel>> getAllUsersForSchool(String schoolId) async {
    final membershipsForSchool = userSchoolsDb.where(
      (m) => m['school_id'] == schoolId && ['active', 'pending', 'requested_exit'].contains(m['status']),
    ).toList();

    final List<UserModel> result = [];
    for (final mem in membershipsForSchool) {
      final user = usersDb.firstWhere(
        (u) => u.id == mem['user_id'],
        orElse: () => UserModel(
          id: mem['user_id'],
          email: 'user@test.com',
          fullName: 'Test User',
          role: mem['role'] ?? 'guru',
          status: mem['status'],
          schoolId: schoolId,
        ),
      );
      result.add(user.copyWith(
        role: mem['role'] ?? 'guru',
        status: mem['status'],
        schoolId: schoolId,
      ));
    }
    return result;
  }

  @override
  Future<void> updateUserRole(String userId, String role, [String? schoolId]) async {}

  @override
  Future<void> deleteAccount(String userId) async {
    usersDb.removeWhere((u) => u.id == userId);
  }

  @override
  Future<void> leaveSchool({required String schoolId, required String userId, String? membershipId}) async {
    // Remove or deactivate user from user_schools for that school
    userSchoolsDb.removeWhere((m) => m['user_id'] == userId && m['school_id'] == schoolId);

    // Update target user's active school if it was this school
    final targetIndex = usersDb.indexWhere((u) => u.id == userId);
    if (targetIndex != -1) {
      final user = usersDb[targetIndex];
      final newSchoolIds = user.schoolIds.where((s) => s != schoolId).toList();
      final newSchoolId = user.schoolId == schoolId
          ? (newSchoolIds.isNotEmpty ? newSchoolIds.first : null)
          : user.schoolId;
      usersDb[targetIndex] = user.copyWith(
        schoolIds: newSchoolIds,
        schoolId: newSchoolId,
        clearSchoolId: newSchoolId == null,
      );
    }
  }

  @override
  Future<void> rejectJoinRequest(String userId, String schoolId) async {}

  @override
  Future<void> requestExitFromSchool(String membershipId, {String? schoolId, String? role, String? userId}) async {}

  @override
  Future<void> cancelExitRequest(String membershipId, {String? schoolId, String? role, String? userId}) async {}

  @override
  Future<List<Map<String, dynamic>>> getPendingExitRequests(String schoolId) async => [];

  @override
  Future<void> approveExitRequest(String membershipId) async {}

  @override
  Future<void> rejectExitRequest(String membershipId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Removing Teacher (Trash Can Icon) Flow Tests', () {
    late MockAdminUserRemovalRepo mockRepo;
    late AuthProvider authProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockRepo = MockAdminUserRemovalRepo();

      // Admin user
      mockRepo.mockUser = UserModel(
        id: 'admin-1',
        email: 'admin@school.com',
        fullName: 'Admin Sekolah',
        role: 'admin',
        status: 'active',
        schoolId: 'school-A',
        schoolIds: ['school-A'],
      );
      mockRepo.usersDb.add(mockRepo.mockUser!);
      mockRepo.userSchoolsDb.add({
        'id': 'us-admin-1',
        'user_id': 'admin-1',
        'school_id': 'school-A',
        'role': 'admin',
        'status': 'active',
      });

      authProvider = AuthProvider(authRepository: mockRepo);
    });

    test('removeUserFromSchool removes teacher from current school without deleting teacher account', () async {
      const teacherId = 'teacher-1';
      final teacher = UserModel(
        id: teacherId,
        email: 'teacher@school.com',
        fullName: 'Guru Teladan',
        role: 'guru',
        status: 'active',
        schoolId: 'school-A',
        schoolIds: ['school-A', 'school-B'],
      );
      mockRepo.usersDb.add(teacher);
      mockRepo.userSchoolsDb.addAll([
        {
          'id': 'us-teacher-1-A',
          'user_id': teacherId,
          'school_id': 'school-A',
          'role': 'guru',
          'status': 'active',
        },
        {
          'id': 'us-teacher-1-B',
          'user_id': teacherId,
          'school_id': 'school-B',
          'role': 'guru',
          'status': 'active',
        },
      ]);

      // Admin triggers removal of teacher from school-A
      final success = await authProvider.removeUserFromSchool(
        userId: teacherId,
        schoolId: 'school-A',
      );

      expect(success, isTrue);

      // 1. Account must NOT be deleted
      final remainingUsers = mockRepo.usersDb.where((u) => u.id == teacherId).toList();
      expect(remainingUsers.isNotEmpty, isTrue, reason: 'Teacher account must be preserved in users table');
      final updatedTeacher = remainingUsers.first;

      // 2. School-A should no longer be in teacher's schoolIds
      expect(updatedTeacher.schoolIds.contains('school-A'), isFalse);
      expect(updatedTeacher.schoolIds.contains('school-B'), isTrue);

      // 3. UserSchoolsDb for school-A should be removed
      final schoolAMembers = mockRepo.userSchoolsDb.where((m) => m['school_id'] == 'school-A' && m['user_id'] == teacherId).toList();
      expect(schoolAMembers.isEmpty, isTrue);

      // 4. UserSchoolsDb for school-B should remain intact
      final schoolBMembers = mockRepo.userSchoolsDb.where((m) => m['school_id'] == 'school-B' && m['user_id'] == teacherId).toList();
      expect(schoolBMembers.length, equals(1));

      // 5. Admin's own membership and session must be completely unaffected
      final adminMemberships = mockRepo.userSchoolsDb.where((m) => m['user_id'] == 'admin-1').toList();
      expect(adminMemberships.length, equals(1));
    });

    test('removeUserFromSchool handles single school membership properly without deleting account', () async {
      const teacherId = 'teacher-single';
      final teacher = UserModel(
        id: teacherId,
        email: 'single@school.com',
        fullName: 'Guru Single School',
        role: 'guru',
        status: 'active',
        schoolId: 'school-A',
        schoolIds: ['school-A'],
      );
      mockRepo.usersDb.add(teacher);
      mockRepo.userSchoolsDb.add({
        'id': 'us-teacher-single-A',
        'user_id': teacherId,
        'school_id': 'school-A',
        'role': 'guru',
        'status': 'active',
      });

      final success = await authProvider.removeUserFromSchool(
        userId: teacherId,
        schoolId: 'school-A',
      );

      expect(success, isTrue);

      // Account still exists!
      final remainingUser = mockRepo.usersDb.firstWhere((u) => u.id == teacherId);
      expect(remainingUser.schoolIds.isEmpty, isTrue);
      expect(remainingUser.schoolId, isNull);
    });
  });
}
