import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/models/nobox_config_model.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/school_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/school_repository.dart';
import 'package:jurnalmengajar/repositories/mock/mock_settings_repository.dart';
import 'package:jurnalmengajar/providers/settings_provider.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/services/nobox_service.dart';
import 'package:jurnalmengajar/screens/admin/settings_screen.dart';

/// Fake NoboxService for deterministic unit & widget tests
class FakeNoboxService extends NoboxService {
  final Map<String, NoboxConfigModel> configs = {};

  @override
  Future<NoboxConfigModel> getSchoolNoboxStatus(String schoolId) async {
    return configs[schoolId] ?? NoboxConfigModel(schoolId: schoolId);
  }

  @override
  Future<bool> saveSchoolApiKey({
    required String schoolId,
    required String apiKey,
    String channelId = '1',
    String accountId = '',
  }) async {
    configs[schoolId] = NoboxConfigModel(
      schoolId: schoolId,
      hasApiKey: true,
      maskedApiKey: '••••••••••••••••••••••••${apiKey.length > 4 ? apiKey.substring(apiKey.length - 4) : apiKey}',
      channelId: channelId,
      accountId: accountId,
      isActive: true,
      connectionStatus: 'untested',
    );
    return true;
  }

  @override
  Future<Map<String, dynamic>> testConnection(String schoolId) async {
    final existing = configs[schoolId];
    if (existing == null || !existing.hasApiKey) {
      return {'success': false, 'message': 'API Key belum diisi'};
    }
    configs[schoolId] = existing.copyWith(
      connectionStatus: 'connected',
      lastTestedAt: DateTime.now(),
    );
    return {'success': true, 'message': 'Koneksi NoBox.ai berhasil diverifikasi!'};
  }
}

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
  Future<List<UserModel>> getAllUsers([String? schoolId]) async => mockUser != null ? [mockUser!] : [];
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
  Future<List<UserModel>> getAllUsersForSchool(String schoolId) async => mockUser != null ? [mockUser!] : [];
  @override
  Future<void> approveExitRequest(String membershipId) async {}
  @override
  Future<void> rejectExitRequest(String membershipId) async {}
  @override
  Future<void> rejectJoinRequest(String userId, String schoolId) async {}
  @override
  Future<void> leaveSchool({required String schoolId, required String userId, String? membershipId}) async {}
}

class FakePeriodRepo implements PeriodRepository {
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(PeriodModel period) async {}
  @override
  Future<void> update(PeriodModel period) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeSubjectRepo implements SubjectRepository {
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(SubjectModel subject) async {}
  @override
  Future<void> update(SubjectModel subject) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeHourRepo implements HourRepository {
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(HourModel hour) async {}
  @override
  Future<void> update(HourModel hour) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeClassRepo implements ClassRepository {
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(ClassModel classModel) async {}
  @override
  Future<void> update(ClassModel classModel) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeTeacherRepo implements TeacherRepository {
  @override
  Future<List<TeacherModel>> getAll() async => [];
  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async => [];
  @override
  Future<void> create(TeacherModel teacher) async {}
  @override
  Future<void> update(TeacherModel teacher) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeStudentRepo implements StudentRepository {
  @override
  Future<List<StudentModel>> getAllByClass(String classId) async => [];
  @override
  Future<void> create(StudentModel student) async {}
  @override
  Future<void> update(StudentModel student) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeSchoolRepo implements SchoolRepository {
  @override
  Future<List<SchoolModel>> getAll() async => [
        SchoolModel(id: '00000000-0000-0000-0000-000000000001', name: 'SMKN 11 Malang', plan: 'pro'),
      ];
  @override
  Future<SchoolModel?> validateActivationCode(String code) async => null;
  @override
  Future<SchoolModel> activateSchoolWithCode({
    required String currentSchoolId,
    required String activationCode,
  }) async =>
      SchoolModel(id: currentSchoolId, name: 'SMKN 11 Malang', plan: 'pro');
  @override
  Future<bool> updateSchoolPlan(String schoolId, String plan, String activationCode) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NoboxConfigModel Tests', () {
    test('Correctly parses from JSON with masked key and statuses', () {
      final json = {
        'has_api_key': true,
        'masked_api_key': '••••••••••••••••••••••••2709',
        'channel_id': '1',
        'account_id': '829936240919301',
        'is_active': true,
        'connection_status': 'connected',
        'last_tested_at': '2026-09-11T12:00:00.000Z',
      };

      final model = NoboxConfigModel.fromJson('school-smkn11', json);

      expect(model.schoolId, 'school-smkn11');
      expect(model.hasApiKey, isTrue);
      expect(model.maskedApiKey, '••••••••••••••••••••••••2709');
      expect(model.channelId, '1');
      expect(model.accountId, '829936240919301');
      expect(model.isActive, isTrue);
      expect(model.connectionStatus, 'connected');
      expect(model.isConnected, isTrue);
      expect(model.isFailed, isFalse);
      expect(model.isUntested, isFalse);
      expect(model.lastTestedAt, isNotNull);
    });

    test('Handles empty and untested defaults safely', () {
      final model = NoboxConfigModel(schoolId: 'school-smkn4');

      expect(model.hasApiKey, isFalse);
      expect(model.maskedApiKey, isNull);
      expect(model.isConnected, isFalse);
      expect(model.isUntested, isTrue);
    });
  });

  group('SettingsProvider NoBox Multi-Tenant Isolation Tests', () {
    late FakeNoboxService fakeNobox;
    late SettingsProvider settingsProvider;

    setUp(() {
      fakeNobox = FakeNoboxService();
      settingsProvider = SettingsProvider(
        settingsRepository: MockSettingsRepository(),
        noboxService: fakeNobox,
      );
    });

    test('Strict tenant isolation: SMKN 11 key is isolated from SMKN 4', () async {
      const smkn11Id = 'school-smkn11';
      const smkn4Id = 'school-smkn4';

      // 1. Save key for SMKN 11
      final save11 = await settingsProvider.saveNoboxApiKey(
        schoolId: smkn11Id,
        apiKey: 'Nobox-key-smkn11-malang-secret',
      );
      expect(save11, isTrue);
      expect(settingsProvider.noboxConfig?.schoolId, smkn11Id);
      expect(settingsProvider.noboxConfig?.hasApiKey, isTrue);
      expect(settingsProvider.noboxConfig?.maskedApiKey, contains('cret'));

      // 2. Switch to SMKN 4
      await settingsProvider.loadNoboxConfig(smkn4Id);
      expect(settingsProvider.noboxConfig?.schoolId, smkn4Id);
      expect(settingsProvider.noboxConfig?.hasApiKey, isFalse);
      expect(settingsProvider.noboxConfig?.maskedApiKey, isNull);

      // 3. Save separate key for SMKN 4
      final save4 = await settingsProvider.saveNoboxApiKey(
        schoolId: smkn4Id,
        apiKey: 'Nobox-key-smkn4-malang-unique',
      );
      expect(save4, isTrue);
      expect(settingsProvider.noboxConfig?.schoolId, smkn4Id);
      expect(settingsProvider.noboxConfig?.maskedApiKey, contains('ique'));

      // 4. Switch back to SMKN 11 and verify SMKN 11 credential was preserved and isolated
      await settingsProvider.loadNoboxConfig(smkn11Id);
      expect(settingsProvider.noboxConfig?.schoolId, smkn11Id);
      expect(settingsProvider.noboxConfig?.maskedApiKey, contains('cret'));
      expect(settingsProvider.noboxConfig?.maskedApiKey, isNot(contains('ique')));
    });

    test('Testing connection updates status to connected for specific tenant', () async {
      const schoolId = 'school-test';
      await settingsProvider.saveNoboxApiKey(
        schoolId: schoolId,
        apiKey: 'test-api-key-1234',
      );

      expect(settingsProvider.noboxConfig?.isConnected, isFalse);

      final testResult = await settingsProvider.testNoboxConnection(schoolId);
      expect(testResult['success'], isTrue);
      expect(settingsProvider.noboxConfig?.isConnected, isTrue);
      expect(settingsProvider.noboxConfig?.connectionStatus, 'connected');
    });
  });

  group('AdminSettingsScreen NoBox UI Widget Tests', () {
    testWidgets('Renders Integrasi Notifikasi Orang Tua card with Show/Hide toggle and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeNobox = FakeNoboxService();
      const testSchoolId = '00000000-0000-0000-0000-000000000001';

      final authRepo = FakeAuthRepo();
      authRepo.mockUser = UserModel(
        id: 'admin-id',
        email: 'admin@jurnal.com',
        fullName: 'Administrator',
        role: 'admin',
        schoolId: testSchoolId,
        schoolName: 'SMKN 11 Malang',
      );
      final authProvider = AuthProvider(authRepository: authRepo);
      await authProvider.login('admin@jurnal.com', 'password');

      final settingsProvider = SettingsProvider(
        settingsRepository: MockSettingsRepository(),
        noboxService: fakeNobox,
      );

      final masterProvider = MasterDataProvider(
        periodRepository: FakePeriodRepo(),
        subjectRepository: FakeSubjectRepo(),
        hourRepository: FakeHourRepo(),
        classRepository: FakeClassRepo(),
        teacherRepository: FakeTeacherRepo(),
        studentRepository: FakeStudentRepo(),
        schoolRepository: FakeSchoolRepo(),
      );

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) => MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
              ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
              ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
            ],
            child: const MaterialApp(
              home: AdminSettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Card title & description
      expect(find.text('Integrasi Notifikasi Orang Tua'), findsOneWidget);
      expect(find.textContaining('Gunakan NoBox.ai untuk mengirim notifikasi'), findsOneWidget);

      // Verify Label & Textfield
      expect(find.text('API Key NoBox.ai *'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2)); // Days + NoBox key

      // Verify Status indicator
      expect(find.text('Status: Belum Dikonfigurasi'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Tes Koneksi'), findsOneWidget);
      expect(find.text('Simpan API Key'), findsOneWidget);

      // Test entering an API key and saving
      final noboxKeyInput = find.widgetWithText(TextFormField, '').last;
      await tester.ensureVisible(noboxKeyInput);
      await tester.pumpAndSettle();
      await tester.enterText(noboxKeyInput, 'Nobox-test-key-smkn11');
      await tester.pumpAndSettle();

      // Tap Simpan API Key
      final simpanBtn = find.text('Simpan API Key');
      await tester.ensureVisible(simpanBtn);
      await tester.pumpAndSettle();
      await tester.tap(simpanBtn);
      await tester.pumpAndSettle();

      // Now verify status updated
      expect(find.text('Status: Belum Diuji'), findsOneWidget);
      expect(find.text('Ganti Key'), findsOneWidget);

      // Tap Tes Koneksi
      final testBtn = find.text('Tes Koneksi');
      await tester.ensureVisible(testBtn);
      await tester.pumpAndSettle();
      await tester.tap(testBtn);
      await tester.pumpAndSettle();

      // Now status should show Terhubung
      expect(find.text('Status: Terhubung'), findsOneWidget);
    });
  });
}
