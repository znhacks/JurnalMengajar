import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/holiday_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/holiday_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/providers/settings_provider.dart';
import 'package:jurnalmengajar/repositories/mock/mock_settings_repository.dart';
import 'package:jurnalmengajar/services/nobox_service.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/screens/admin/dashboard_screen.dart';

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

class FakeWarningLetterRepo implements WarningLetterRepository {
  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async => [];
  @override
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId, [String? schoolId]) async => [];
  @override
  Future<void> create(WarningLetterModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> markAsRead(String id) async {}
  @override
  Future<void> update(WarningLetterModel model) async {}
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
  @override
  Future<void> loadSchedules([String? schoolId]) async {}
}

class MockJournalProvider extends JournalProvider {
  final List<JournalModel> _mockJournals;
  MockJournalProvider(this._mockJournals) : super(journalRepository: FakeJournalRepo());
  @override
  List<JournalModel> get journals => _mockJournals;
  @override
  Future<void> loadAllJournals([String? schoolId]) async {}
}

class MockHolidayProvider extends HolidayProvider {
  final List<HolidayModel> _mockHolidays;
  MockHolidayProvider(this._mockHolidays);
  @override
  List<HolidayModel> get holidays => _mockHolidays;
  @override
  HolidayModel? getHolidayForDate(DateTime date) => null;
  @override
  Future<void> loadHolidays([String? schoolId]) async {}
}

class MockMasterDataProvider extends MasterDataProvider {
  final List<TeacherModel> _mockTeachers;
  final List<ClassModel> _mockClasses;
  final List<SubjectModel> _mockSubjects;

  MockMasterDataProvider({
    required List<TeacherModel> teachers,
    required List<ClassModel> classes,
    required List<SubjectModel> subjects,
  })  : _mockTeachers = teachers,
        _mockClasses = classes,
        _mockSubjects = subjects,
        super(
          periodRepository: FakePeriodRepo(),
          subjectRepository: FakeSubjectRepo(),
          hourRepository: FakeHourRepo(),
          classRepository: FakeClassRepo(),
          teacherRepository: FakeTeacherRepo(),
          studentRepository: FakeStudentRepo(),
        );

  @override
  List<TeacherModel> get teachers => _mockTeachers;
  @override
  List<ClassModel> get classes => _mockClasses;
  @override
  List<SubjectModel> get subjects => _mockSubjects;
  @override
  Future<void> loadAllData([String? schoolId]) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('id_ID', null);
  });

  final testUser = UserModel(
    id: 'admin-1',
    email: 'admin@test.com',
    fullName: 'Admin Test',
    role: 'admin',
    status: 'approved',
    schoolId: 'school-1',
  );

  final testTeacher = TeacherModel(
    id: 'teacher-1',
    name: 'Heru Sudjatmiko, M.Pd',
    position: 'Guru',
    address: 'Jl. Sekolah',
    phoneNumber: '08123456789',
    email: 'heru@test.com',
  );

  final testClass = ClassModel(
    id: 'c-1',
    name: 'XII RPL 2 - Beta',
    periodId: 'p-1',
    studentCount: 30,
  );

  final testSubject = SubjectModel(
    id: 'sub-1',
    name: 'Matematika',
    isActive: true,
  );

  testWidgets('When journal is rejected, schedule item displays red clock icon instead of checkmark', (tester) async {
    const screenSize = Size(1024, 768);
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final today = DateTime.now();

    final schedule1 = ScheduleModel(
      id: 's-1',
      teacherId: 'teacher-1',
      classId: 'c-1',
      subjectId: 'sub-1',
      periodId: 'p-1',
      date: today,
      teachingHour: 1,
      schoolId: 'school-1',
      isActive: true,
    );

    // Rejected journal for schedule1
    final rejectedJournal = JournalModel(
      id: 'j-1',
      teacherId: 'teacher-1',
      scheduleId: 's-1',
      classId: 'c-1',
      subjectId: 'sub-1',
      date: today,
      teachingHour: 1,
      material: 'Matematika',
      status: 'rejected',
      teacherAttendanceStatus: 'izin',
    );

    final authRepo = FakeAuthRepo()..mockUser = testUser;
    final authProvider = AuthProvider(authRepository: authRepo);
    final themeProvider = ThemeProvider();
    final masterProvider = MockMasterDataProvider(
      teachers: [testTeacher],
      classes: [testClass],
      subjects: [testSubject],
    );
    final scheduleProvider = MockScheduleProvider([schedule1]);
    final journalProvider = MockJournalProvider([rejectedJournal]);
    final holidayProvider = MockHolidayProvider([]);
    final warningLetterProvider = WarningLetterProvider(warningLetterRepository: FakeWarningLetterRepo());
    final settingsProvider = SettingsProvider(settingsRepository: MockSettingsRepository(), noboxService: NoboxService());

    final router = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/journal/:id',
          builder: (context, state) => Scaffold(
            body: Text('Detail Jurnal ${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/admin/schedule/:id',
          builder: (context, state) => Scaffold(
            body: Text('Detail Jadwal ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
          ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
          ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
          ChangeNotifierProvider<HolidayProvider>.value(value: holidayProvider),
          ChangeNotifierProvider<WarningLetterProvider>.value(value: warningLetterProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
        ],
        child: ScreenUtilInit(
          designSize: const Size(1024, 768),
          minTextAdapt: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify schedule title exists
    expect(find.textContaining('XII RPL 2 - Beta • Matematika'), findsWidgets);

    // Because journal is rejected, it should show Icons.access_time_filled_rounded (red clock icon), NOT checkmark!
    expect(find.byIcon(Icons.access_time_filled_rounded), findsWidgets);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    // Tapping on the schedule item should still open the rejected journal detail
    await tester.tap(find.textContaining('XII RPL 2 - Beta • Matematika').first);
    await tester.pumpAndSettle();

    expect(find.text('Detail Jurnal j-1'), findsOneWidget);
  });

  testWidgets('When journal is approved or pending, schedule item displays blue checkmark icon', (tester) async {
    const screenSize = Size(1024, 768);
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final today = DateTime.now();

    final schedule1 = ScheduleModel(
      id: 's-1',
      teacherId: 'teacher-1',
      classId: 'c-1',
      subjectId: 'sub-1',
      periodId: 'p-1',
      date: today,
      teachingHour: 1,
      schoolId: 'school-1',
      isActive: true,
    );

    // Approved journal for schedule1
    final approvedJournal = JournalModel(
      id: 'j-1',
      teacherId: 'teacher-1',
      scheduleId: 's-1',
      classId: 'c-1',
      subjectId: 'sub-1',
      date: today,
      teachingHour: 1,
      material: 'Matematika',
      status: 'verified',
    );

    final authRepo = FakeAuthRepo()..mockUser = testUser;
    final authProvider = AuthProvider(authRepository: authRepo);
    final themeProvider = ThemeProvider();
    final masterProvider = MockMasterDataProvider(
      teachers: [testTeacher],
      classes: [testClass],
      subjects: [testSubject],
    );
    final scheduleProvider = MockScheduleProvider([schedule1]);
    final journalProvider = MockJournalProvider([approvedJournal]);
    final holidayProvider = MockHolidayProvider([]);
    final warningLetterProvider = WarningLetterProvider(warningLetterRepository: FakeWarningLetterRepo());
    final settingsProvider2 = SettingsProvider(settingsRepository: MockSettingsRepository(), noboxService: NoboxService());

    final router = GoRouter(
      initialLocation: '/admin/dashboard',
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
          ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
          ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
          ChangeNotifierProvider<HolidayProvider>.value(value: holidayProvider),
          ChangeNotifierProvider<WarningLetterProvider>.value(value: warningLetterProvider),
          ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider2),
        ],
        child: ScreenUtilInit(
          designSize: const Size(1024, 768),
          minTextAdapt: true,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify blue checkmark icon is displayed
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
