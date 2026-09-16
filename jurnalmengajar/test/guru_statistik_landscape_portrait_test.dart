import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';
import 'package:jurnalmengajar/screens/guru/statistik_screen.dart';

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

class FakeJournalRepo implements JournalRepository {
  @override
  Future<List<JournalModel>> getAll([String? schoolId]) async => [];
  @override
  Future<List<JournalModel>> getJournalsForTeacher(String teacherId) async => [];
  @override
  Future<JournalModel?> getJournalForSchedule(String scheduleId, {DateTime? date}) async => null;
  @override
  Future<void> create(JournalModel journal) async {}
  @override
  Future<void> update(JournalModel journal) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
  @override
  Future<void> verifyJournal(String journalId, String status, {String? rejectionNote}) async {}
}

class FakeScheduleRepo implements ScheduleRepository {
  @override
  Future<List<ScheduleModel>> getAll([String? schoolId]) async => [];
  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, {DateTime? date}) async => [];
  @override
  Future<void> create(ScheduleModel schedule) async {}
  @override
  Future<void> createMultiple(List<ScheduleModel> models) async {}
  @override
  Future<void> update(ScheduleModel schedule) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class MockScheduleProvider extends ScheduleProvider {
  final List<ScheduleModel> _mockSchedules;
  MockScheduleProvider(this._mockSchedules) : super(scheduleRepository: FakeScheduleRepo());
  @override
  List<ScheduleModel> get cachedTeacherSchedules => _mockSchedules;
}

class MockJournalProvider extends JournalProvider {
  final List<JournalModel> _mockJournals;
  MockJournalProvider(this._mockJournals) : super(journalRepository: FakeJournalRepo());
  @override
  List<JournalModel> get teacherJournals => _mockJournals;
}

class MockMasterDataProvider extends MasterDataProvider {
  final List<ClassModel> _mockClasses;
  MockMasterDataProvider(this._mockClasses)
      : super(
          periodRepository: FakePeriodRepo(),
          subjectRepository: FakeSubjectRepo(),
          hourRepository: FakeHourRepo(),
          classRepository: FakeClassRepo(),
          teacherRepository: FakeTeacherRepo(),
          studentRepository: FakeStudentRepo(),
        );
  @override
  List<ClassModel> get classes => _mockClasses;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testUser = UserModel(
    id: 'teacher-1',
    email: 'guru@test.com',
    fullName: 'Guru Test',
    role: 'guru',
    status: 'approved',
    schoolId: 'school-1',
  );

  final testClasses = [
    ClassModel(id: 'cls-1', name: 'X RPL 1', periodId: 'p-1', studentCount: 30),
  ];

  final now = DateTime.now();
  final testSchedules = [
    ScheduleModel(
      id: 'sch-1',
      periodId: 'p-1',
      date: DateTime(now.year, now.month, 10),
      teachingHour: 1,
      classId: 'cls-1',
      subjectId: 'sub-1',
      teacherId: 'teacher-1',
      isActive: true,
    ),
  ];

  final testJournals = [
    JournalModel(
      id: 'j-1',
      scheduleId: 'sch-1',
      teacherId: 'teacher-1',
      classId: 'cls-1',
      subjectId: 'sub-1',
      date: DateTime(now.year, now.month, 10),
      teachingHour: 1,
      material: 'Flutter UI',
      sickCount: 1,
      permissionCount: 1,
      alphaCount: 1,
      status: 'verified',
      createdAt: now,
    ),
  ];

  Widget buildTestApp({required Size screenSize}) {
    final authRepo = FakeAuthRepo();
    authRepo.mockUser = testUser;
    final authProvider = AuthProvider(authRepository: authRepo);
    final themeProvider = ThemeProvider();
    final masterProvider = MockMasterDataProvider(testClasses);
    final scheduleProvider = MockScheduleProvider(testSchedules);
    final journalProvider = MockJournalProvider(testJournals);

    final isLandscape = screenSize.width > screenSize.height;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
        ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
        ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
      ],
      child: ScreenUtilInit(
        designSize: isLandscape ? const Size(1024, 768) : const Size(360, 690),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(size: screenSize),
            child: const GuruStatistikScreen(),
          ),
        ),
      ),
    );
  }

  group('Guru Statistik Screen - Orientation Tests (Portrait & Landscape)', () {
    testWidgets('Renders Status Verifikasi Jurnal and Ketidakhadiran in Portrait with original natural height', (tester) async {
      const portraitSize = Size(390, 844);
      tester.view.physicalSize = portraitSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(screenSize: portraitSize));
      await tester.pumpAndSettle();

      // Find titles
      expect(find.text('Status Verifikasi Jurnal'), findsOneWidget);
      expect(find.text('Distribusi Ketidakhadiran Siswa'), findsOneWidget);

      // Verify labels inside
      expect(find.text('Sakit'), findsOneWidget);
      expect(find.text('Izin'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);

      // Verify absence card in portrait renders properly without forced enlargement
      final sakitFinder = find.ancestor(
        of: find.text('Sakit'),
        matching: find.byType(Container),
      ).first;
      final portraitBox = tester.getSize(sakitFinder);
      expect(portraitBox.height, greaterThanOrEqualTo(45.0));
    });

    testWidgets('Renders in Landscape mode with heightened card (>= 64.0) and wide width', (tester) async {
      const landscapeSize = Size(844, 390);
      tester.view.physicalSize = landscapeSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(screenSize: landscapeSize));
      await tester.pumpAndSettle();

      // Verify titles and cards exist without overflow
      expect(find.text('Status Verifikasi Jurnal'), findsOneWidget);
      expect(find.text('Distribusi Ketidakhadiran Siswa'), findsOneWidget);
      expect(find.text('Sakit'), findsOneWidget);
      expect(find.text('Izin'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);

      // Verify absence card in landscape is heightened (>= 64.0) and wide width
      final sakitFinder = find.ancestor(
        of: find.text('Sakit'),
        matching: find.byType(Container),
      ).first;
      final landscapeBox = tester.getSize(sakitFinder);
      expect(landscapeBox.height, greaterThanOrEqualTo(64.0));
      // In landscape (width 844), length is significantly wider than portrait
      expect(landscapeBox.width, greaterThan(150.0));
    });
  });
}
