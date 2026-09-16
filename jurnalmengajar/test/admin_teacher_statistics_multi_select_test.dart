import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
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
import 'package:jurnalmengajar/screens/admin/teacher_statistics_screen.dart';

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
  List<ScheduleModel> get schedules => _mockSchedules;
}

class MockJournalProvider extends JournalProvider {
  final List<JournalModel> _mockJournals;
  MockJournalProvider(this._mockJournals) : super(journalRepository: FakeJournalRepo());
  @override
  List<JournalModel> get journals => _mockJournals;
}

class MockMasterDataProvider extends MasterDataProvider {
  final List<TeacherModel> _mockTeachers;
  MockMasterDataProvider(this._mockTeachers)
      : super(
          periodRepository: FakePeriodRepo(),
          subjectRepository: FakeSubjectRepo(),
          hourRepository: FakeHourRepo(),
          classRepository: FakeClassRepo(),
          teacherRepository: FakeTeacherRepo(),
          studentRepository: FakeStudentRepo(),
        );
  @override
  List<TeacherModel> get teachers => _mockTeachers;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testUser = UserModel(
    id: 'admin-1',
    email: 'admin@test.com',
    fullName: 'Admin Test',
    role: 'admin',
    status: 'approved',
    schoolId: 'school-1',
  );

  final teacher1 = TeacherModel(
    id: 't-1',
    name: 'Guru Tepat Waktu',
    position: 'Guru Matematika',
    address: 'Jl. 1',
    phoneNumber: '0811',
    email: 't1@test.com',
  );

  final teacher2 = TeacherModel(
    id: 't-2',
    name: 'Guru Ada Telat',
    position: 'Guru Fisika',
    address: 'Jl. 2',
    phoneNumber: '0812',
    email: 't2@test.com',
  );

  final teacher3 = TeacherModel(
    id: 't-3',
    name: 'Guru Ada Tunggakan',
    position: 'Guru Kimia',
    address: 'Jl. 3',
    phoneNumber: '0813',
    email: 't3@test.com',
  );

  final now = DateTime.now();
  final pastDate = DateTime(now.year, now.month, now.day - 2);

  // Schedule for each
  final testSchedules = [
    ScheduleModel(
      id: 'sch-1',
      periodId: 'p-1',
      date: pastDate,
      teachingHour: 1,
      classId: 'cls-1',
      subjectId: 'sub-1',
      teacherId: 't-1',
      isActive: true,
    ),
    ScheduleModel(
      id: 'sch-2',
      periodId: 'p-1',
      date: pastDate,
      teachingHour: 1,
      classId: 'cls-1',
      subjectId: 'sub-2',
      teacherId: 't-2',
      isActive: true,
    ),
    ScheduleModel(
      id: 'sch-3',
      periodId: 'p-1',
      date: pastDate,
      teachingHour: 1,
      classId: 'cls-1',
      subjectId: 'sub-3',
      teacherId: 't-3',
      isActive: true,
    ),
  ];

  // Journals:
  // t-1 submitted on-time (diff 0)
  // t-2 submitted 2 days late (diff 2)
  // t-3 did NOT submit journal (unsubmitted)
  final testJournals = [
    JournalModel(
      id: 'j-1',
      scheduleId: 'sch-1',
      teacherId: 't-1',
      classId: 'cls-1',
      subjectId: 'sub-1',
      date: pastDate,
      teachingHour: 1,
      material: 'Matematika Aljabar',
      status: 'verified',
      createdAt: pastDate, // on-time
    ),
    JournalModel(
      id: 'j-2',
      scheduleId: 'sch-2',
      teacherId: 't-2',
      classId: 'cls-1',
      subjectId: 'sub-2',
      date: pastDate,
      teachingHour: 1,
      material: 'Fisika Gaya',
      status: 'verified',
      createdAt: pastDate.add(const Duration(days: 2)), // late by 2 days
    ),
  ];

  Widget buildTestApp() {
    final authRepo = FakeAuthRepo();
    authRepo.mockUser = testUser;
    final authProvider = AuthProvider(authRepository: authRepo);
    final themeProvider = ThemeProvider();
    final masterProvider = MockMasterDataProvider([teacher1, teacher2, teacher3]);
    final scheduleProvider = MockScheduleProvider(testSchedules);
    final journalProvider = MockJournalProvider(testJournals);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
        ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
        ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
      ],
      child: ScreenUtilInit(
        designSize: const Size(1200, 900),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AdminTeacherStatisticsScreen(),
        ),
      ),
    );
  }

  group('AdminTeacherStatisticsScreen - Multi-Select Category Filters', () {
    testWidgets('allows multi-selecting Ada Keterlambatan and Ada Tunggakan simultaneously', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final listFinder = find.byType(ListView);

      // Initially, Semua is active and all 3 teachers are visible in the list
      expect(find.descendant(of: listFinder, matching: find.text('Guru Tepat Waktu')), findsOneWidget);
      expect(find.descendant(of: listFinder, matching: find.text('Guru Ada Telat')), findsOneWidget);
      expect(find.descendant(of: listFinder, matching: find.text('Guru Ada Tunggakan')), findsOneWidget);

      // Tap "Ada Keterlambatan"
      final lateChipFinder = find.text('Ada Keterlambatan');
      expect(lateChipFinder, findsOneWidget);
      await tester.tap(lateChipFinder);
      await tester.pumpAndSettle();

      // Only Guru Ada Telat should be shown in the list
      expect(find.descendant(of: listFinder, matching: find.text('Guru Ada Telat')), findsOneWidget);
      expect(find.descendant(of: listFinder, matching: find.text('Guru Tepat Waktu')), findsNothing);
      expect(find.descendant(of: listFinder, matching: find.text('Guru Ada Tunggakan')), findsNothing);

      // Now MULTI-SELECT: Tap "Ada Tunggakan" as well
      final unsubmittedChipFinder = find.text('Ada Tunggakan');
      expect(unsubmittedChipFinder, findsOneWidget);
      await tester.tap(unsubmittedChipFinder);
      await tester.pumpAndSettle();

      // BOTH Guru Ada Telat AND Guru Ada Tunggakan should now be displayed in the list!
      expect(find.descendant(of: listFinder, matching: find.text('Guru Ada Telat')), findsOneWidget);
      expect(find.descendant(of: listFinder, matching: find.text('Guru Ada Tunggakan')), findsOneWidget);
      expect(find.descendant(of: listFinder, matching: find.text('Guru Tepat Waktu')), findsNothing);

      // Tapping "Semua" resets back to all teachers
      final semuaChipFinder = find.text('Semua (3)');
      expect(semuaChipFinder, findsOneWidget);
      await tester.tap(semuaChipFinder);
      await tester.pumpAndSettle();

      expect(find.descendant(of: listFinder, matching: find.text('Guru Tepat Waktu')), findsOneWidget);
      expect(find.descendant(of: listFinder, matching: find.text('Guru Ada Telat')), findsOneWidget);
      expect(find.descendant(of: listFinder, matching: find.text('Guru Ada Tunggakan')), findsOneWidget);
    });
  });
}
