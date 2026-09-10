import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/core/services/cache_service.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/user_school_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/core/utils/helper.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/widgets/role_badge.dart';

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

    test('UserModel status and approval getters work correctly', () {
      final activeGuru = UserModel(
        id: 'g1',
        email: 'guru1@smkn11.com',
        fullName: 'Guru Aktif',
        role: 'guru',
        status: 'active',
        schoolId: '00000000-0000-0000-0000-000000000001',
      );
      expect(activeGuru.isActive, isTrue);
      expect(activeGuru.isPending, isFalse);

      final pendingGuru = UserModel(
        id: 'g2',
        email: 'pending@smkn11.com',
        fullName: 'Guru Menunggu',
        role: 'pending_guru',
        status: 'pending',
        schoolId: '00000000-0000-0000-0000-000000000001',
      );
      expect(pendingGuru.isActive, isFalse);
      expect(pendingGuru.isPending, isTrue);

      final inactiveUser = UserModel(
        id: 'g3',
        email: 'inactive@smkn11.com',
        fullName: 'Guru Inaktif',
        role: 'guru',
        status: 'inactive',
        schoolId: '00000000-0000-0000-0000-000000000001',
      );
      expect(inactiveUser.isActive, isFalse);
      expect(inactiveUser.isPending, isFalse);
    });

    test('Master User filtering isolates active users vs pending registrations', () {
      final users = [
        UserModel(
          id: 'u1',
          email: 'admin@jurnal.com',
          fullName: 'Admin SMKN 11 Malang',
          role: 'admin',
          status: 'active',
          schoolId: '00000000-0000-0000-0000-000000000001',
        ),
        UserModel(
          id: 'u2',
          email: 'guru@jurnal.com',
          fullName: 'Heru Sudjatmiko (Admin Cadangan)',
          role: 'admin',
          membershipRole: 'admin',
          status: 'active',
          schoolId: '00000000-0000-0000-0000-000000000001',
        ),
        UserModel(
          id: 'u3',
          email: 'jasmine@jurnal.com',
          fullName: 'Jasmine (Guru Aktif)',
          role: 'guru',
          status: 'active',
          schoolId: '00000000-0000-0000-0000-000000000001',
        ),
        UserModel(
          id: 'u4',
          email: 'calon@jurnal.com',
          fullName: 'Calon Guru (Pending)',
          role: 'pending_guru',
          status: 'pending',
          schoolId: '00000000-0000-0000-0000-000000000001',
        ),
      ];

      // Filter for "Pengguna Aktif"
      final activeUsers = users.where((u) {
        if (u.isPending || u.status == 'pending' || u.role.toLowerCase() == 'pending_guru') return false;
        if (u.status != null && u.status != 'active') return false;
        final r = u.role.toLowerCase();
        return r == 'guru' || r == 'admin' || r == 'superadmin' || r == 'teacher';
      }).toList();

      expect(activeUsers.length, 3);
      expect(activeUsers.map((u) => u.id), containsAll(['u1', 'u2', 'u3']));
      expect(activeUsers.any((u) => u.id == 'u4'), isFalse);

      // Filter for "Guru Mendaftar"
      final pendingUsers = users.where((u) {
        return u.isPending || u.role.toLowerCase() == 'pending_guru' || u.status == 'pending';
      }).toList();

      expect(pendingUsers.length, 1);
      expect(pendingUsers.first.id, 'u4');

      // Search for foreign admin in active school dataset returns 0 results
      final searchResults = users.where((u) => u.email.contains('adminsmkn100')).toList();
      expect(searchResults.isEmpty, isTrue);
    });

    test('Calendar schedule indicators identify dates accurately with multi-tenant isolation', () {
      final schoolA = '00000000-0000-0000-0000-000000000001';
      final schoolB = '99999999-9999-9999-9999-999999999999';

      final List<ScheduleModel> mockSchedules = [
        // Active schedule on 2026-09-10 in School A (has time component 08:30)
        ScheduleModel(
          id: 's1',
          periodId: 'p1',
          teacherId: 't1',
          subjectId: 'sub1',
          classId: 'c1',
          teachingHour: 1,
          date: DateTime(2026, 9, 10, 8, 30),
          schoolId: schoolA,
          isActive: true,
        ),
        // Second schedule on 2026-09-10 in School A (hour 2)
        ScheduleModel(
          id: 's2',
          periodId: 'p1',
          teacherId: 't1',
          subjectId: 'sub2',
          classId: 'c1',
          teachingHour: 2,
          date: DateTime(2026, 9, 10, 9, 15),
          schoolId: schoolA,
          isActive: true,
        ),
        // Schedule on 2026-09-15 in School B
        ScheduleModel(
          id: 's3',
          periodId: 'p1',
          teacherId: 't1',
          subjectId: 'sub1',
          classId: 'c2',
          teachingHour: 3,
          date: DateTime(2026, 9, 15, 10, 0),
          schoolId: schoolB,
          isActive: true,
        ),
        // Inactive schedule on 2026-09-20 in School A
        ScheduleModel(
          id: 's4',
          periodId: 'p1',
          teacherId: 't1',
          subjectId: 'sub1',
          classId: 'c1',
          teachingHour: 1,
          date: DateTime(2026, 9, 20, 7, 30),
          schoolId: schoolA,
          isActive: false,
        ),
      ];

      // Helper simulating calendar scheduledDateKeys calculation for School A
      Set<String> getScheduledDates(List<ScheduleModel> schedules, String activeSchoolId) {
        final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(activeSchoolId) ?? activeSchoolId.trim();
        final keys = <String>{};
        for (final s in schedules) {
          if (!s.isActive) continue;
          if (cleanActiveSchoolId.isNotEmpty) {
            final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
            if (sSchoolId != null && sSchoolId.isNotEmpty && sSchoolId != cleanActiveSchoolId) {
              continue;
            }
          }
          final key = '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
          keys.add(key);
        }
        return keys;
      }

      // Context 1: School A is active
      final scheduledDatesSchoolA = getScheduledDates(mockSchedules, schoolA);

      // Date with no schedule (e.g. 2026-09-09) -> false (normal)
      expect(scheduledDatesSchoolA.contains('2026-09-09'), isFalse);

      // Date with schedules (2026-09-10) -> true (yellow indicator)
      expect(scheduledDatesSchoolA.contains('2026-09-10'), isTrue);

      // Multiple schedules on same day still result in exactly 1 entry
      expect(scheduledDatesSchoolA.where((k) => k == '2026-09-10').length, 1);

      // Date with schedule in School B (2026-09-15) must NOT appear in School A
      expect(scheduledDatesSchoolA.contains('2026-09-15'), isFalse);

      // Inactive schedule (2026-09-20) must NOT appear
      expect(scheduledDatesSchoolA.contains('2026-09-20'), isFalse);

      // Context 2: School B is active
      final scheduledDatesSchoolB = getScheduledDates(mockSchedules, schoolB);

      // 2026-09-10 from School A must NOT appear in School B
      expect(scheduledDatesSchoolB.contains('2026-09-10'), isFalse);

      // 2026-09-15 from School B appears in School B
      expect(scheduledDatesSchoolB.contains('2026-09-15'), isTrue);
    });

    testWidgets('RoleBadge is theme-aware in Light and Dark mode for GURU and ADMIN', (tester) async {
      // 1. Light Mode - GURU
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(body: RoleBadge(role: 'guru')),
          ),
        ),
      );
      expect(find.text('GURU'), findsOneWidget);
      var container = tester.widget<Container>(find.descendant(of: find.byType(RoleBadge), matching: find.byType(Container)).first);
      var decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFF0FDF4));

      // 2. Dark Mode - GURU
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: Theme(
              data: ThemeData(brightness: Brightness.dark),
              child: const Scaffold(body: RoleBadge(role: 'guru')),
            ),
          ),
        ),
      );
      expect(find.text('GURU'), findsOneWidget);
      container = tester.widget<Container>(find.descendant(of: find.byType(RoleBadge), matching: find.byType(Container)).first);
      decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNot(equals(const Color(0xFFF0FDF4))));
      expect(decoration.color, isNot(equals(Colors.white)));
      expect(decoration.color, const Color(0xFF14532D).withValues(alpha: 0.35));

      // 3. Light Mode - ADMIN
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: Theme(
              data: ThemeData(brightness: Brightness.light),
              child: const Scaffold(body: RoleBadge(role: 'admin')),
            ),
          ),
        ),
      );
      expect(find.text('ADMIN'), findsOneWidget);
      container = tester.widget<Container>(find.descendant(of: find.byType(RoleBadge), matching: find.byType(Container)).first);
      decoration = container.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFFEF2F2));

      // 4. Dark Mode - ADMIN
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            home: Theme(
              data: ThemeData(brightness: Brightness.dark),
              child: const Scaffold(body: RoleBadge(role: 'admin')),
            ),
          ),
        ),
      );
      expect(find.text('ADMIN'), findsOneWidget);
      container = tester.widget<Container>(find.descendant(of: find.byType(RoleBadge), matching: find.byType(Container)).first);
      decoration = container.decoration as BoxDecoration;
      expect(decoration.color, isNot(equals(const Color(0xFFFEF2F2))));
      expect(decoration.color, isNot(equals(Colors.white)));
      expect(decoration.color, const Color(0xFF7F1D1D).withValues(alpha: 0.35));
    });
  });
}
