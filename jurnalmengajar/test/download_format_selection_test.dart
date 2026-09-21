import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/screens/guru/download_jurnal_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthRepo implements AuthRepository {
  @override
  Future<UserModel?> getCurrentUser() async => null;
  @override
  Future<UserModel> login(String email, String password) async =>
      throw UnimplementedError();
  @override
  Future<UserModel> loginWithGoogle() async => throw UnimplementedError();
  @override
  Future<void> logout() async {}
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
  Future<void> updateUserRole(
    String userId,
    String role, [
    String? schoolId,
  ]) async {}
  @override
  Future<void> deleteAccount(String userId) async {}
  @override
  Future<void> requestExitFromSchool(
    String membershipId, {
    String? schoolId,
    String? role,
    String? userId,
  }) async {}
  @override
  Future<void> cancelExitRequest(
    String membershipId, {
    String? schoolId,
    String? role,
    String? userId,
  }) async {}
  @override
  Future<List<Map<String, dynamic>>> getPendingExitRequests(
    String schoolId,
  ) async => [];
  @override
  Future<List<UserModel>> getAllUsersForSchool(String schoolId) async => [];
  @override
  Future<void> approveExitRequest(String membershipId) async {}
  @override
  Future<void> rejectExitRequest(String membershipId) async {}
  @override
  Future<void> rejectJoinRequest(String userId, String schoolId) async {}
  @override
  Future<void> leaveSchool({
    required String schoolId,
    required String userId,
    String? membershipId,
  }) async {}
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
  final List<JournalModel> journals = [];
  @override
  Future<List<JournalModel>> getAll([String? schoolId]) async =>
      List.from(journals);
  @override
  Future<List<JournalModel>> getJournalsForTeacher(String teacherId) async =>
      journals.where((j) => j.teacherId == teacherId).toList();
  @override
  Future<JournalModel?> getJournalForSchedule(
    String scheduleId, {
    DateTime? date,
  }) async => null;
  @override
  Future<void> create(JournalModel journal) async => journals.add(journal);
  @override
  Future<void> update(JournalModel journal) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
  @override
  Future<void> verifyJournal(
    String journalId,
    String status, {
    String? rejectionNote,
  }) async {}
}

class FakeScheduleRepo implements ScheduleRepository {
  @override
  Future<List<ScheduleModel>> getAll([String? schoolId]) async => [];
  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(
    String teacherId, {
    DateTime? date,
  }) async => [];
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

class MockAuthProvider extends AuthProvider {
  final UserModel? _mockUser;
  MockAuthProvider(this._mockUser) : super(authRepository: FakeAuthRepo());
  @override
  UserModel? get currentUser => _mockUser;
  @override
  String? get activeSchoolId => _mockUser?.schoolId;
  @override
  String get activeSchoolName => _mockUser?.schoolName ?? 'SMK Negeri 1';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget() {
    final user = UserModel(
      id: 'teacher-1',
      email: 'guru@test.com',
      fullName: 'Guru Test',
      role: 'guru',
      schoolId: 'school-1',
      schoolName: 'SMK Negeri 1',
    );

    final teacher = TeacherModel(
      id: 'teacher-1',
      name: 'Guru Test',
      position: 'Guru Pengajar',
      address: '',
      phoneNumber: '',
      email: 'guru@test.com',
    );

    final journal = JournalModel(
      id: 'journal-1',
      teacherId: 'teacher-1',
      classId: 'class-1',
      subjectId: 'sub-1',
      scheduleId: 'sch-1',
      date: DateTime.now(),
      teachingHour: 1,
      material: 'Materi Test',
      status: 'verified',
      createdAt: DateTime.now(),
    );

    final authProvider = MockAuthProvider(user);

    final journalRepo = FakeJournalRepo();
    journalRepo.journals.add(journal);
    final journalProvider = JournalProvider(journalRepository: journalRepo);

    final masterProvider = MasterDataProvider(
      periodRepository: FakePeriodRepo(),
      subjectRepository: FakeSubjectRepo(),
      hourRepository: FakeHourRepo(),
      classRepository: FakeClassRepo(),
      teacherRepository: FakeTeacherRepo(),
      studentRepository: FakeStudentRepo(),
    );
    masterProvider.teachers.add(teacher);

    final scheduleProvider = ScheduleProvider(
      scheduleRepository: FakeScheduleRepo(),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
        ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
        ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GuruDownloadJurnalScreen(),
        ),
      ),
    );
  }

  group('GuruDownloadJurnalScreen Format Selection Tests', () {
    testWidgets(
      'standalone Ekspor Excel button is removed and Unduh button is present',
      (tester) async {
        final origOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          if (!details.toString().contains('overflowed by')) {
            origOnError?.call(details);
          }
        };
        addTearDown(() {
          FlutterError.onError = origOnError;
        });

        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Verify standalone 'Ekspor Excel (.xlsx)' button does NOT exist
        expect(find.text('Ekspor Excel (.xlsx)'), findsNothing);

        // Verify 'Unduh' button exists
        final unduhCetakFinder = find.text('Unduh');
        expect(unduhCetakFinder, findsOneWidget);

        // Verify 'Preview' button exists
        expect(find.text('Preview'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'tapping Unduh opens modal bottom sheet with PDF and Excel options',
      (tester) async {
        final origOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          if (!details.toString().contains('overflowed by')) {
            origOnError?.call(details);
          }
        };
        addTearDown(() {
          FlutterError.onError = origOnError;
        });

        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final unduhCetakFinder = find.text('Unduh');
        await tester.ensureVisible(unduhCetakFinder);
        await tester.tap(unduhCetakFinder);
        await tester.pumpAndSettle();

        // Modal bottom sheet should appear
        expect(find.text('Pilih Format Unduhan'), findsOneWidget);
        expect(find.text('Dokumen PDF (.pdf)'), findsOneWidget);
        expect(find.text('Spreadsheet Excel (.xlsx)'), findsOneWidget);
        expect(find.byIcon(Icons.picture_as_pdf_rounded), findsWidgets);
        expect(find.byIcon(Icons.table_view_rounded), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
