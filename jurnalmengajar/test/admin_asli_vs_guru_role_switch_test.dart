import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:jurnalmengajar/core/services/cache_service.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/widgets/school_switcher_modal.dart';

class MockAuthRepo implements AuthRepository {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PENGUJIAN LOGIKA SWITCH ROLE: ADMIN ASLI vs AKUN GURU', () {
    const schoolAId = '00000000-0000-0000-0000-000000000001';
    const schoolAName = 'SMKN 11 Malang';
    const schoolBId = '00000000-0000-0000-0000-000000000002';
    const schoolBName = 'SMKN 4 Malang';

    testWidgets('Test A — Admin Asli: Tidak ada opsi Guru, Admin Asli tetap Admin', (tester) async {
      final fakeRepo = MockAuthRepo();
      final adminUser = UserModel(
        id: 'admin-asli-01',
        email: 'admin@smkn11.sch.id',
        fullName: 'Admin Asli Sekolah',
        role: 'admin',
        registeredRole: 'admin', // Asal akun saat registrasi: ADMIN
        schoolId: schoolAId,
        schoolName: schoolAName,
        schoolIds: [schoolAId],
      );
      fakeRepo.mockUser = adminUser;

      await CacheService().save('user_memberships_admin-asli-01', [
        {
          'id': 'mem-admin-01',
          'user_id': 'admin-asli-01',
          'school_id': schoolAId,
          'school_name': schoolAName,
          'role': 'admin',
          'status': 'active',
        },
      ]);

      final authProvider = AuthProvider(authRepository: fakeRepo);
      await authProvider.login(adminUser.email, 'password');

      // 1. Verifikasi klasifikasi akun
      expect(authProvider.isAdminAsli, isTrue, reason: 'Akun terdaftar sebagai Admin adalah Admin Asli');
      expect(authProvider.isAdminCadangan, isFalse);
      expect(authProvider.isGuruMurni, isFalse);
      expect(authProvider.activeRole, 'admin');

      // 2. Verifikasi UI Role Switcher Modal
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SchoolSwitcherModal(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Modal harus menampilkan ADMIN
      expect(find.text('ADMIN'), findsOneWidget);
      // Modal TIDAK BOLEH menampilkan opsi GURU untuk Admin Asli!
      expect(find.text('GURU'), findsNothing, reason: 'Admin Asli tidak boleh memiliki opsi Guru');

      // 3. Verifikasi upaya pemanggilan switch ke guru secara paksa
      await authProvider.switchActiveSchool(schoolAId, schoolAName, 'guru');
      expect(authProvider.activeRole, 'admin', reason: 'Admin Asli dipaksa tetap menjadi role admin');
      expect(authProvider.currentUser?.role, 'admin');
    });

    testWidgets('Test B — Guru dengan Hak Admin: Boleh switch Guru <-> Admin', (tester) async {
      final fakeRepo = MockAuthRepo();
      final guruWithAdminUser = UserModel(
        id: 'guru-cadangan-01',
        email: 'guru.cadangan@smkn11.sch.id',
        fullName: 'Budi Santoso, S.Pd',
        role: 'guru',
        registeredRole: 'pending_guru', // Asal akun saat registrasi: GURU
        schoolId: schoolAId,
        schoolName: schoolAName,
        schoolIds: [schoolAId],
      );
      fakeRepo.mockUser = guruWithAdminUser;

      // Akun guru yang memiliki hak akses Admin di sekolahnya
      await CacheService().save('user_memberships_guru-cadangan-01', [
        {
          'id': 'mem-guru-01',
          'user_id': 'guru-cadangan-01',
          'school_id': schoolAId,
          'school_name': schoolAName,
          'role': 'guru',
          'status': 'active',
        },
        {
          'id': 'mem-admin-02',
          'user_id': 'guru-cadangan-01',
          'school_id': schoolAId,
          'school_name': schoolAName,
          'role': 'admin',
          'status': 'active',
        },
      ]);

      final authProvider = AuthProvider(authRepository: fakeRepo);
      await authProvider.login(guruWithAdminUser.email, 'password');

      // 1. Verifikasi klasifikasi akun
      expect(authProvider.isAdminAsli, isFalse, reason: 'Akun dasar berasal dari guru');
      expect(authProvider.isAdminCadangan, isTrue, reason: 'Guru memiliki penugasan admin aktif');
      expect(authProvider.isGuruMurni, isFalse);

      // 2. Switch ke Admin
      await authProvider.switchActiveSchool(schoolAId, schoolAName, 'admin');
      expect(authProvider.activeRole, 'admin', reason: 'Bisa masuk mode Admin');
      expect(authProvider.currentUser?.role, 'guru', reason: 'Base role akun tetap guru');

      // 3. Verifikasi Role Switcher menampilkan Admin DAN Guru
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SchoolSwitcherModal(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('GURU'), findsOneWidget, reason: 'Guru dengan hak admin dapat melihat opsi Guru');

      // 4. Switch kembali ke Guru
      await authProvider.switchActiveSchool(schoolAId, schoolAName, 'guru');
      expect(authProvider.activeRole, 'guru', reason: 'Bisa kembali switch ke mode Guru');
      expect(authProvider.currentUser?.role, 'guru', reason: 'Identitas dasar guru tetap terjaga');
    });

    testWidgets('Test C — Guru Murni: Tetap Guru dan tidak mendapatkan akses Admin', (tester) async {
      final fakeRepo = MockAuthRepo();
      final guruMurniUser = UserModel(
        id: 'guru-murni-01',
        email: 'guru.murni@smkn11.sch.id',
        fullName: 'Siti Rahma, S.Pd',
        role: 'guru',
        registeredRole: 'pending_guru', // Asal akun saat registrasi: GURU
        schoolId: schoolAId,
        schoolName: schoolAName,
        schoolIds: [schoolAId],
      );
      fakeRepo.mockUser = guruMurniUser;

      await CacheService().save('user_memberships_guru-murni-01', [
        {
          'id': 'mem-guru-pure',
          'user_id': 'guru-murni-01',
          'school_id': schoolAId,
          'school_name': schoolAName,
          'role': 'guru',
          'status': 'active',
        },
      ]);

      final authProvider = AuthProvider(authRepository: fakeRepo);
      await authProvider.login(guruMurniUser.email, 'password');

      // 1. Verifikasi klasifikasi akun
      expect(authProvider.isAdminAsli, isFalse);
      expect(authProvider.isAdminCadangan, isFalse);
      expect(authProvider.isGuruMurni, isTrue, reason: 'Akun adalah Guru Murni');
      expect(authProvider.activeRole, 'guru');

      // 2. Verifikasi UI Role Switcher Modal
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SchoolSwitcherModal(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Guru Murni hanya melihat GURU, TIDAK BOLEH ada ADMIN
      expect(find.text('GURU'), findsOneWidget);
      expect(find.text('ADMIN'), findsNothing, reason: 'Guru murni tidak boleh melihat opsi Admin');

      // 3. Upaya paksa switch ke Admin harus ditolak
      await authProvider.switchActiveSchool(schoolAId, schoolAName, 'admin');
      expect(authProvider.activeRole, 'guru', reason: 'Guru murni dilarang menjadi admin');
    });

    test('Test D — Tenant Isolation: Admin Asli Sekolah A tidak bisa akses Sekolah B', () async {
      final fakeRepo = MockAuthRepo();
      final adminUser = UserModel(
        id: 'admin-a',
        email: 'admin@sekolah-a.sch.id',
        fullName: 'Admin Sekolah A',
        role: 'admin',
        registeredRole: 'admin',
        schoolId: schoolAId,
        schoolName: schoolAName,
        schoolIds: [schoolAId],
      );
      fakeRepo.mockUser = adminUser;

      await CacheService().save('user_memberships_admin-a', [
        {
          'id': 'mem-a',
          'user_id': 'admin-a',
          'school_id': schoolAId,
          'school_name': schoolAName,
          'role': 'admin',
          'status': 'active',
        },
      ]);

      final authProvider = AuthProvider(authRepository: fakeRepo);
      await authProvider.login(adminUser.email, 'password');

      // Coba akses Sekolah B (Sekolah yang tidak berhak diakses)
      await authProvider.switchActiveSchool(schoolBId, schoolBName, 'admin');

      // Switch harus diblokir, tetap berada di Sekolah A
      expect(authProvider.activeSchoolId, schoolAId, reason: 'Admin Asli terkunci pada sekolah induknya');
      expect(authProvider.activeRole, 'admin');
    });
  });
}
