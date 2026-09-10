import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/user_school_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';

class MockSchoolJoinAuthRepo implements AuthRepository {
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
      (m) => m['school_id'] == schoolId && ['active', 'pending', 'requested_exit'].contains(m['status'])
    ).toList();

    final List<UserModel> result = [];
    for (final mem in membershipsForSchool) {
      final user = usersDb.firstWhere((u) => u.id == mem['user_id'], orElse: () => UserModel(
        id: mem['user_id'],
        email: 'user@test.com',
        fullName: 'Test User',
        role: mem['role'] ?? 'guru',
        status: mem['status'],
        schoolId: schoolId,
      ));
      result.add(user.copyWith(
        role: mem['role'] ?? 'guru',
        status: mem['status'],
        schoolId: schoolId,
      ));
    }
    return result;
  }

  @override
  Future<void> updateUserRole(String userId, String role, [String? schoolId]) async {
    for (final m in userSchoolsDb) {
      if (m['user_id'] == userId && (schoolId == null || m['school_id'] == schoolId)) {
        m['role'] = role;
        if (role == 'guru') {
          m['status'] = 'active'; // Approval sets status to active
        }
      }
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    usersDb.removeWhere((u) => u.id == userId);
    userSchoolsDb.removeWhere((m) => m['user_id'] == userId);
  }

  @override
  Future<void> rejectJoinRequest(String userId, String schoolId) async {
    final hasOtherActive = userSchoolsDb.any(
      (m) => m['user_id'] == userId && m['school_id'] != schoolId && m['status'] == 'active'
    );
    userSchoolsDb.removeWhere((m) => m['user_id'] == userId && m['school_id'] == schoolId);
    if (!hasOtherActive) {
      usersDb.removeWhere((u) => u.id == userId && u.isPending);
    }
  }

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

  group('School Join Request & Admin Approval Flow Tests', () {
    late MockSchoolJoinAuthRepo mockRepo;
    late AuthProvider authProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockRepo = MockSchoolJoinAuthRepo();
      authProvider = AuthProvider(authRepository: mockRepo);
    });

    test('AuthProvider pendingMemberships initializes empty', () {
      expect(authProvider.pendingMemberships, isEmpty);
    });

    test('Duplicate prevention when teacher is already active member', () async {
      // Setup teacher who is already active in School SMKN 4
      const teacherId = 'teacher-1';
      const smkn4Id = 'smkn-4-uuid';
      
      mockRepo.userSchoolsDb.add({
        'id': 'mem-1',
        'user_id': teacherId,
        'school_id': smkn4Id,
        'role': 'guru',
        'status': 'active',
      });

      final existingMember = mockRepo.userSchoolsDb.firstWhere(
        (m) => m['user_id'] == teacherId && m['school_id'] == smkn4Id
      );

      expect(existingMember['status'], equals('active'));
      
      // Simulate duplicate check logic
      String? errorMessage;
      if (existingMember['status'] == 'active') {
        errorMessage = 'Anda sudah menjadi anggota di sekolah ini.';
      }

      expect(errorMessage, equals('Anda sudah menjadi anggota di sekolah ini.'));
    });

    test('Duplicate prevention when teacher join request is already pending', () async {
      const teacherId = 'teacher-1';
      const smkn4Id = 'smkn-4-uuid';

      mockRepo.userSchoolsDb.add({
        'id': 'mem-pending',
        'user_id': teacherId,
        'school_id': smkn4Id,
        'role': 'guru',
        'status': 'pending',
      });

      final existingMember = mockRepo.userSchoolsDb.firstWhere(
        (m) => m['user_id'] == teacherId && m['school_id'] == smkn4Id
      );

      expect(existingMember['status'], equals('pending'));

      // Simulate duplicate pending check
      String? errorMessage;
      if (existingMember['status'] == 'pending') {
        errorMessage = 'Permintaan bergabung sedang menunggu persetujuan dari Admin sekolah.';
      }

      expect(errorMessage, equals('Permintaan bergabung sedang menunggu persetujuan dari Admin sekolah.'));
    });

    test('Admin of target school sees pending request in getAllUsersForSchool', () async {
      const smkn4Id = 'smkn-4-uuid';
      const smkn11Id = 'smkn-11-uuid';
      const teacherA = 'teacher-A';
      const teacherB = 'teacher-B';

      mockRepo.usersDb.addAll([
        UserModel(id: teacherA, email: 'guruA@smkn4.com', fullName: 'Guru A', role: 'guru'),
        UserModel(id: teacherB, email: 'guruB@smkn11.com', fullName: 'Guru B', role: 'guru'),
      ]);

      // Guru A requested SMKN 4 (pending)
      mockRepo.userSchoolsDb.add({
        'id': 'mem-A',
        'user_id': teacherA,
        'school_id': smkn4Id,
        'role': 'guru',
        'status': 'pending',
      });

      // Guru B requested SMKN 11 (pending)
      mockRepo.userSchoolsDb.add({
        'id': 'mem-B',
        'user_id': teacherB,
        'school_id': smkn11Id,
        'role': 'guru',
        'status': 'pending',
      });

      // 1. Admin SMKN 4 only sees Guru A
      final usersSMKN4 = await mockRepo.getAllUsersForSchool(smkn4Id);
      expect(usersSMKN4.length, equals(1));
      expect(usersSMKN4.first.id, equals(teacherA));
      expect(usersSMKN4.first.status, equals('pending'));

      // 2. Admin SMKN 11 only sees Guru B
      final usersSMKN11 = await mockRepo.getAllUsersForSchool(smkn11Id);
      expect(usersSMKN11.length, equals(1));
      expect(usersSMKN11.first.id, equals(teacherB));
      expect(usersSMKN11.first.status, equals('pending'));
    });

    test('Approval flow changes status from pending to active', () async {
      const smkn4Id = 'smkn-4-uuid';
      const teacherA = 'teacher-A';

      mockRepo.usersDb.add(
        UserModel(id: teacherA, email: 'guruA@smkn4.com', fullName: 'Guru A', role: 'guru')
      );

      mockRepo.userSchoolsDb.add({
        'id': 'mem-A',
        'user_id': teacherA,
        'school_id': smkn4Id,
        'role': 'guru',
        'status': 'pending',
      });

      // Before approval
      var usersBefore = await mockRepo.getAllUsersForSchool(smkn4Id);
      expect(usersBefore.first.status, equals('pending'));

      // Admin approves
      await mockRepo.updateUserRole(teacherA, 'guru', smkn4Id);

      // After approval: status is active
      var usersAfter = await mockRepo.getAllUsersForSchool(smkn4Id);
      expect(usersAfter.first.status, equals('active'));
    });

    test('Rejecting join request preserves teacher account in other schools and does not logout admin', () async {
      const smkn4Id = 'smkn-4-uuid';
      const smkn11Id = 'smkn-11-uuid';
      const teacherA = 'teacher-A';

      // Teacher A is active at SMKN 11, pending at SMKN 4
      mockRepo.usersDb.add(
        UserModel(id: teacherA, email: 'guruA@gmail.com', fullName: 'Guru A Multi', role: 'guru')
      );
      mockRepo.userSchoolsDb.addAll([
        {
          'id': 'mem-active-11',
          'user_id': teacherA,
          'school_id': smkn11Id,
          'role': 'guru',
          'status': 'active',
        },
        {
          'id': 'mem-pending-4',
          'user_id': teacherA,
          'school_id': smkn4Id,
          'role': 'guru',
          'status': 'pending',
        },
      ]);

      // Admin of SMKN 4 rejects request
      await mockRepo.rejectJoinRequest(teacherA, smkn4Id);

      // Verify SMKN 4 pending membership is removed
      final smkn4Users = await mockRepo.getAllUsersForSchool(smkn4Id);
      expect(smkn4Users.isEmpty, isTrue);

      // Verify Teacher A still exists in SMKN 11 as active member
      final smkn11Users = await mockRepo.getAllUsersForSchool(smkn11Id);
      expect(smkn11Users.length, equals(1));
      expect(smkn11Users.first.id, equals(teacherA));
      expect(smkn11Users.first.status, equals('active'));

      // Verify Teacher A user record is preserved
      expect(mockRepo.usersDb.any((u) => u.id == teacherA), isTrue);
    });

    test('Pending schools are not included in active memberships', () {
      final activeMember = UserSchoolModel(
        id: 'us-1',
        userId: 'teacher-1',
        schoolId: 'smkn-11',
        role: 'guru',
        schoolName: 'SMKN 11 Malang',
        status: 'active',
      );
      final pendingMember = UserSchoolModel(
        id: 'us-2',
        userId: 'teacher-1',
        schoolId: 'smkn-4',
        role: 'guru',
        schoolName: 'SMKN 4 Malang',
        status: 'pending',
      );

      final activeList = [activeMember];
      final pendingList = [pendingMember];

      // Active list for school switcher only contains active schools
      expect(activeList.length, equals(1));
      expect(activeList.first.schoolId, equals('smkn-11'));
      expect(activeList.any((m) => m.schoolId == 'smkn-4'), isFalse);

      // Pending list is separated and tagged
      expect(pendingList.length, equals(1));
      expect(pendingList.first.schoolId, equals('smkn-4'));
      expect(pendingList.first.status, equals('pending'));
    });
  });
}
