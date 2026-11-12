import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/school_model.dart';
import 'package:jurnalmengajar/models/student_academic_history_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/user_school_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/providers/settings_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/mock/mock_settings_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';
import 'package:jurnalmengajar/repositories/school_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/screens/admin/settings_screen.dart';
import 'package:jurnalmengajar/screens/guru/profil_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<UserModel?> getCurrentUser() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePeriodRepo implements PeriodRepository {
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

class _FakeSubjectRepo implements SubjectRepository {
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

class _FakeHourRepo implements HourRepository {
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

class _FakeClassRepo implements ClassRepository {
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

class _FakeTeacherRepo implements TeacherRepository {
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

class _FakeStudentRepo implements StudentRepository {
  @override
  Future<List<StudentAcademicHistoryModel>> getStudentHistories(
    String studentId,
  ) async => [];
  @override
  Future<Map<String, dynamic>> processPromotions({
    required String schoolId,
    required String sourcePeriodId,
    required String sourceClassId,
    String? targetPeriodId,
    String? targetClassId,
    required List<Map<String, dynamic>> items,
    DateTime? transferDate,
  }) async => {'success': true};
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

class _FakeSchoolRepo implements SchoolRepository {
  @override
  Future<List<SchoolModel>> getAll() async => [];
  @override
  Future<SchoolModel?> getById(String id) async => null;
  @override
  Future<SchoolModel?> validateActivationCode(String code) async => null;
  @override
  Future<SchoolModel?> validateTeacherJoinCode(String code) async => null;
  @override
  Future<SchoolModel> activateSchoolWithCode({
    required String currentSchoolId,
    required String activationCode,
  }) async => SchoolModel(id: currentSchoolId, name: 'SMKN 11 Malang');
  @override
  Future<bool> updateSchoolPlan(
    String schoolId,
    String plan,
    String activationCode,
  ) async => true;
}

class _FakeScheduleRepo implements ScheduleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeJournalRepo implements JournalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWarningRepo implements WarningLetterRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthProvider extends AuthProvider {
  final UserModel _user;
  final SchoolModel _school;
  final List<UserSchoolModel> _memberships;
  final String _role;

  _TestAuthProvider({
    required UserModel user,
    required SchoolModel school,
    required List<UserSchoolModel> memberships,
    required String role,
  }) : _user = user,
       _school = school,
       _memberships = memberships,
       _role = role,
       super(authRepository: _FakeAuthRepo());

  @override
  UserModel? get currentUser => _user;

  @override
  SchoolModel? get activeSchool => _school;

  @override
  String? get activeSchoolId => _school.id;

  @override
  String get activeSchoolName => _school.name;

  @override
  String get activeRole => _role;

  @override
  List<UserSchoolModel> get userMemberships => _memberships;

  @override
  Future<void> loadUserMemberships() async {}

  @override
  Future<void> fetchActiveSchoolDetails() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleSchool = SchoolModel(
    id: 'school-1',
    name: 'SMKN 11 Malang',
    governmentHeader: 'PEMERINTAH PROVINSI JAWA TIMUR',
    departmentHeader: 'DINAS PENDIDIKAN',
    address: 'Jl. Pelabuhan Bakahuni No.1, Bakalankrajan, Sukun, Malang',
    postalCode: '65148',
    phone: '0341-801395',
    email: 'info@smkn11malang.sch.id',
    website: 'http://smkn11malang.sch.id',
    npsn: '20533814',
  );

  final sampleMemberships = [
    UserSchoolModel(
      id: 'mem-1',
      userId: 'user-1',
      schoolId: 'school-1',
      role: 'admin',
      schoolName: 'SMKN 11 Malang',
      status: 'active',
    ),
    UserSchoolModel(
      id: 'mem-2',
      userId: 'user-1',
      schoolId: 'school-1',
      role: 'guru',
      schoolName: 'SMKN 11 Malang',
      status: 'active',
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  MasterDataProvider createMasterProvider() => MasterDataProvider(
    periodRepository: _FakePeriodRepo(),
    subjectRepository: _FakeSubjectRepo(),
    hourRepository: _FakeHourRepo(),
    classRepository: _FakeClassRepo(),
    teacherRepository: _FakeTeacherRepo(),
    studentRepository: _FakeStudentRepo(),
    schoolRepository: _FakeSchoolRepo(),
  );

  testWidgets(
    'GuruProfilScreen renders active school detail without redundant labels and merges postal code into address',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = _TestAuthProvider(
        user: UserModel(
          id: 'user-1',
          email: 'guru@smkn11malang.sch.id',
          fullName: 'Guru Test',
          role: 'guru',
          schoolId: 'school-1',
          schoolName: 'SMKN 11 Malang',
        ),
        school: sampleSchool,
        memberships: sampleMemberships,
        role: 'guru',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(),
            ),
            ChangeNotifierProvider<MasterDataProvider>(
              create: (_) => createMasterProvider(),
            ),
            ChangeNotifierProvider<ScheduleProvider>(
              create: (_) =>
                  ScheduleProvider(scheduleRepository: _FakeScheduleRepo()),
            ),
            ChangeNotifierProvider<JournalProvider>(
              create: (_) =>
                  JournalProvider(journalRepository: _FakeJournalRepo()),
            ),
            ChangeNotifierProvider<WarningLetterProvider>(
              create: (_) => WarningLetterProvider(
                warningLetterRepository: _FakeWarningRepo(),
              ),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              home: const GuruProfilScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PEMERINTAH PROVINSI JAWA TIMUR'), findsOneWidget);
      expect(find.text('DINAS PENDIDIKAN'), findsOneWidget);
      expect(find.text('SMKN 11 Malang'), findsWidgets);

      // Kode pos digabung ke bagian belakang alamat
      expect(
        find.text(
          'Jl. Pelabuhan Bakahuni No.1, Bakalankrajan, Sukun, Malang, 65148',
        ),
        findsOneWidget,
      );

      // Label tambahan di depan ikon dihilangkan
      expect(find.text('Alamat: '), findsNothing);
      expect(find.text('Kode Pos: '), findsNothing);
      expect(find.text('Telepon: '), findsNothing);
      expect(find.text('Email: '), findsNothing);
      expect(find.text('Website: '), findsNothing);

      // Ikon kode pos terpisah tidak lagi ditampilkan
      expect(find.byIcon(Icons.local_post_office_outlined), findsNothing);

      // Informasi kontak tetap tampil bersih bersama ikon
      expect(find.text('0341-801395'), findsOneWidget);
      expect(find.text('info@smkn11malang.sch.id'), findsOneWidget);
      expect(find.text('http://smkn11malang.sch.id'), findsOneWidget);
      expect(find.text('NPSN: '), findsOneWidget);
      expect(find.text('20533814'), findsOneWidget);
    },
  );

  testWidgets(
    'AdminSettingsScreen renders Identitas Sekolah & Kop Surat editor populated from activeSchool',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = _TestAuthProvider(
        user: UserModel(
          id: 'user-1',
          email: 'admin@smkn11malang.sch.id',
          fullName: 'Admin Test',
          role: 'admin',
          schoolId: 'school-1',
          schoolName: 'SMKN 11 Malang',
        ),
        school: sampleSchool,
        memberships: sampleMemberships,
        role: 'admin',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => SettingsProvider(
                settingsRepository: MockSettingsRepository(),
              ),
            ),
            ChangeNotifierProvider<MasterDataProvider>(
              create: (_) => createMasterProvider(),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              home: const AdminSettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Identitas Sekolah'), findsOneWidget);
      expect(find.text('Pemerintah Daerah / Instansi'), findsOneWidget);
      expect(find.text('Dinas Terkait'), findsOneWidget);
      expect(find.text('PEMERINTAH PROVINSI JAWA TIMUR'), findsOneWidget);
      expect(find.text('DINAS PENDIDIKAN'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.controller.text == '65148',
        ),
        findsOneWidget,
      );
      expect(find.text('Simpan'), findsWidgets);
    },
  );

  testWidgets(
    'AdminSettingsScreen renders Identitas Sekolah form cleanly on 375x812 phone without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final authProvider = _TestAuthProvider(
        user: UserModel(
          id: 'user-1',
          email: 'admin@smkn11malang.sch.id',
          fullName: 'Admin Test',
          role: 'admin',
          schoolId: 'school-1',
          schoolName: 'SMKN 11 Malang',
        ),
        school: sampleSchool,
        memberships: sampleMemberships,
        role: 'admin',
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<SettingsProvider>(
              create: (_) => SettingsProvider(
                settingsRepository: MockSettingsRepository(),
              ),
            ),
            ChangeNotifierProvider<MasterDataProvider>(
              create: (_) => createMasterProvider(),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            builder: (context, _) => MaterialApp(
              theme: AppTheme.lightTheme,
              home: const AdminSettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Identitas Sekolah'), findsOneWidget);
      expect(find.text('Kode Pos'), findsOneWidget);
      expect(find.text('Telepon'), findsOneWidget);
      expect(find.text('NPSN'), findsOneWidget);
      expect(find.text('NSS'), findsOneWidget);
    },
  );
}
