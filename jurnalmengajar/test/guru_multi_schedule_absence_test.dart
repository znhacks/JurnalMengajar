import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
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
import 'package:jurnalmengajar/screens/guru/form_jurnal_screen.dart';

class FakeAuthRepo implements AuthRepository {
  @override
  Future<UserModel?> getCurrentUser() async => null;
  @override
  Future<UserModel> login(String email, String password) async => throw UnimplementedError();
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

class FakePeriodRepo implements PeriodRepository {
  @override Future<List<PeriodModel>> getAll([String? schoolId]) async => [];
  @override Future<void> create(PeriodModel period) async {}
  @override Future<void> update(PeriodModel period) async {}
  @override Future<void> delete(String id) async {}
  @override Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeSubjectRepo implements SubjectRepository {
  @override Future<List<SubjectModel>> getAll([String? schoolId]) async => [];
  @override Future<void> create(SubjectModel subject) async {}
  @override Future<void> update(SubjectModel subject) async {}
  @override Future<void> delete(String id) async {}
  @override Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeHourRepo implements HourRepository {
  @override Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override Future<void> create(HourModel hour) async {}
  @override Future<void> update(HourModel hour) async {}
  @override Future<void> delete(String id) async {}
  @override Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeClassRepo implements ClassRepository {
  @override Future<List<ClassModel>> getAll([String? schoolId]) async => [];
  @override Future<void> create(ClassModel classModel) async {}
  @override Future<void> update(ClassModel classModel) async {}
  @override Future<void> delete(String id) async {}
  @override Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeTeacherRepo implements TeacherRepository {
  @override Future<List<TeacherModel>> getAll() async => [];
  @override Future<List<TeacherModel>> getAllForSchool(String schoolId) async => [];
  @override Future<void> create(TeacherModel teacher) async {}
  @override Future<void> update(TeacherModel teacher) async {}
  @override Future<void> delete(String id) async {}
  @override Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeStudentRepo implements StudentRepository {
  @override Future<List<StudentModel>> getAllByClass(String classId) async => [];
  @override Future<void> create(StudentModel student) async {}
  @override Future<void> update(StudentModel student) async {}
  @override Future<void> delete(String id) async {}
  @override Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeJournalRepo implements JournalRepository {
  final List<JournalModel> journals = [];
  @override Future<List<JournalModel>> getAll([String? schoolId]) async => List.from(journals);
  @override Future<List<JournalModel>> getJournalsForTeacher(String teacherId) async =>
      journals.where((j) => j.teacherId == teacherId).toList();
  @override Future<JournalModel?> getJournalForSchedule(String scheduleId, {DateTime? date}) async => null;
  @override Future<void> create(JournalModel journal) async => journals.add(journal);
  @override Future<void> update(JournalModel journal) async {
    final idx = journals.indexWhere((j) => j.id == journal.id);
    if (idx != -1) journals[idx] = journal;
  }
  @override Future<void> delete(String id) async => journals.removeWhere((j) => j.id == id);
  @override Future<void> deleteMultiple(List<String> ids) async => journals.removeWhere((j) => ids.contains(j.id));
  @override Future<void> verifyJournal(String journalId, String status, {String? rejectionNote}) async {
    final idx = journals.indexWhere((j) => j.id == journalId);
    if (idx != -1) {
      journals[idx] = journals[idx].copyWith(status: status, rejectionNote: rejectionNote);
    }
  }
}

class FakeScheduleRepo implements ScheduleRepository {
  @override Future<List<ScheduleModel>> getAll([String? schoolId]) async => [];
  @override Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, {DateTime? date}) async => [];
  @override Future<void> create(ScheduleModel schedule) async {}
  @override Future<void> createMultiple(List<ScheduleModel> models) async {}
  @override Future<void> update(ScheduleModel schedule) async {}
  @override Future<void> delete(String id) async {}
  @override Future<void> deleteMultiple(List<String> ids) async {}
}

class MockScheduleProvider extends ScheduleProvider {
  final List<ScheduleModel> _mockSchedules;
  MockScheduleProvider(this._mockSchedules) : super(scheduleRepository: FakeScheduleRepo());
  @override
  List<ScheduleModel> get cachedTeacherSchedules => _mockSchedules;
  @override
  List<ScheduleModel> get teacherSchedulesForSelectedDate => _mockSchedules;
  @override
  Future<void> loadTeacherSchedules(String teacherId, DateTime date, {bool forceRefresh = false}) async {}
}

class MockJournalProvider extends JournalProvider {
  final FakeJournalRepo _fakeRepo;
  MockJournalProvider(List<JournalModel> initialJournals, [FakeJournalRepo? repo])
      : _fakeRepo = repo ?? FakeJournalRepo(),
        super(journalRepository: repo ?? FakeJournalRepo()) {
    _fakeRepo.journals.addAll(initialJournals);
  }
  @override
  List<JournalModel> get teacherJournals => _fakeRepo.journals;
  @override
  List<JournalModel> get journals => _fakeRepo.journals;
  @override
  Future<void> loadTeacherJournals(String teacherId) async {}
  @override
  Future<void> loadAllJournals([String? schoolId]) async {}
  @override
  Future<JournalModel?> getJournalForSchedule(String scheduleId, {DateTime? date}) async {
    try {
      return _fakeRepo.journals.firstWhere((j) {
        if (date != null) {
          return j.scheduleId == scheduleId &&
              j.date.year == date.year &&
              j.date.month == date.month &&
              j.date.day == date.day;
        }
        return j.scheduleId == scheduleId;
      });
    } catch (_) {
      return null;
    }
  }
  @override
  Future<bool> createJournal(JournalModel model, {List<Uint8List>? imageBytesList, List<String>? imageNamesList}) async {
    final newId = model.id.isEmpty ? 'j_${_fakeRepo.journals.length + 1}' : model.id;
    _fakeRepo.journals.add(model.copyWith(id: newId));
    return true;
  }
  @override
  Future<bool> updateJournal(JournalModel model, {List<Uint8List>? imageBytesList, List<String>? imageNamesList}) async {
    final idx = _fakeRepo.journals.indexWhere((j) => j.id == model.id);
    if (idx != -1) {
      _fakeRepo.journals[idx] = model;
    } else {
      _fakeRepo.journals.add(model);
    }
    return true;
  }
}

class MockAuthProvider extends AuthProvider {
  final UserModel? _mockUser;
  MockAuthProvider(this._mockUser) : super(authRepository: FakeAuthRepo());
  @override
  UserModel? get currentUser => _mockUser;
  @override
  String? get activeSchoolId => _mockUser?.schoolId;
}

class MockMasterDataProvider extends MasterDataProvider {
  final List<ClassModel> _mockClasses;
  final List<SubjectModel> _mockSubjects;
  final List<TeacherModel> _mockTeachers;
  MockMasterDataProvider({
    required List<ClassModel> classes,
    required List<SubjectModel> subjects,
    required List<TeacherModel> teachers,
  })  : _mockClasses = classes,
        _mockSubjects = subjects,
        _mockTeachers = teachers,
        super(
          periodRepository: FakePeriodRepo(),
          subjectRepository: FakeSubjectRepo(),
          hourRepository: FakeHourRepo(),
          classRepository: FakeClassRepo(),
          teacherRepository: FakeTeacherRepo(),
          studentRepository: FakeStudentRepo(),
        );

  @override
  List<ClassModel> get classes => _mockClasses;
  @override
  List<SubjectModel> get subjects => _mockSubjects;
  @override
  List<TeacherModel> get teachers => _mockTeachers;
  @override
  Future<void> loadStudentsForClass(String classId) async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('FormJurnalScreen displays grouped schedule count (2 jadwal) instead of 11 raw hours', (tester) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final user = UserModel(
      id: 'u1',
      fullName: 'Guru Test',
      email: 'guru@test.com',
      role: 'guru',
      schoolId: 'sch1',
    );

    final teachers = [
      TeacherModel(id: 't1', name: 'Guru Test', email: 'guru@test.com', position: 'Guru', address: '', phoneNumber: ''),
    ];

    final classes = [
      ClassModel(id: 'c1', name: 'VII-A', periodId: 'p1', studentCount: 30),
      ClassModel(id: 'c2', name: 'VIII-B', periodId: 'p1', studentCount: 30),
    ];

    final subjects = [
      SubjectModel(id: 's1', name: 'IPA', isActive: true),
      SubjectModel(id: 's2', name: 'Matematika', isActive: true),
    ];

    // Create 11 flat schedules representing 2 teaching sessions/blocks today:
    // Session 1: Class 1, Subject 1 -> Hours 1, 2, 3, 4 (4 schedules)
    // Session 2: Class 2, Subject 2 -> Hours 5, 6, 7, 8, 9, 10, 11 (7 schedules)
    final schedules = <ScheduleModel>[];
    for (int h = 1; h <= 4; h++) {
      schedules.add(
        ScheduleModel(
          id: 'sched_s1_h$h',
          teacherId: 't1',
          classId: 'c1',
          subjectId: 's1',
          periodId: 'p1',
          teachingHour: h,
          date: today,
          isActive: true,
          schoolId: 'sch1',
        ),
      );
    }
    for (int h = 5; h <= 11; h++) {
      schedules.add(
        ScheduleModel(
          id: 'sched_s2_h$h',
          teacherId: 't1',
          classId: 'c2',
          subjectId: 's2',
          periodId: 'p1',
          teachingHour: h,
          date: today,
          isActive: true,
          schoolId: 'sch1',
        ),
      );
    }

    final authProvider = MockAuthProvider(user);
    final masterProvider = MockMasterDataProvider(classes: classes, subjects: subjects, teachers: teachers);
    final scheduleProvider = MockScheduleProvider(schedules);
    final journalProvider = MockJournalProvider([]);

    final origOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!details.toString().contains('overflowed by')) {
        origOnError?.call(details);
      }
    };
    addTearDown(() {
      FlutterError.onError = origOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
          ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
          ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => MaterialApp(
            home: FormJurnalScreen(
              scheduleId: 'sched_s1_h1',
              dateStr: todayStr,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Select 'Izin' status card by finding 'Surat Izin'
    final izinCard = find.text('Surat Izin');
    expect(izinCard, findsOneWidget);
    await tester.tap(izinCard);
    await tester.pumpAndSettle();

    // Verify checkbox displays '(2 jadwal)' and NOT '11 jadwal'
    expect(find.textContaining('(2 jadwal)'), findsOneWidget);
    expect(find.textContaining('11 jadwal'), findsNothing);
  });

  testWidgets('Checking "Terapkan surat ini untuk semua jadwal hari ini" in revision mode updates/creates absence for the other schedule session', (tester) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final user = UserModel(
      id: 'u1',
      fullName: 'Guru Test',
      email: 'guru@test.com',
      role: 'guru',
      schoolId: 'sch1',
    );

    final teachers = [
      TeacherModel(id: 't1', name: 'Guru Test', email: 'guru@test.com', position: 'Guru', address: '', phoneNumber: ''),
    ];

    final classes = [
      ClassModel(id: 'c1', name: 'VII-A', periodId: 'p1', studentCount: 30),
      ClassModel(id: 'c2', name: 'VIII-B', periodId: 'p1', studentCount: 30),
    ];

    final subjects = [
      SubjectModel(id: 's1', name: 'IPA', isActive: true),
      SubjectModel(id: 's2', name: 'Matematika', isActive: true),
    ];

    final schedules = <ScheduleModel>[
      ScheduleModel(
        id: 'sched_s1_h1',
        teacherId: 't1',
        classId: 'c1',
        subjectId: 's1',
        periodId: 'p1',
        teachingHour: 1,
        date: today,
        isActive: true,
        schoolId: 'sch1',
      ),
      ScheduleModel(
        id: 'sched_s2_h5',
        teacherId: 't1',
        classId: 'c2',
        subjectId: 's2',
        periodId: 'p1',
        teachingHour: 5,
        date: today,
        isActive: true,
        schoolId: 'sch1',
      ),
    ];

    // Existing rejected journal for sched_s1_h1
    final initialJournal = JournalModel(
      id: 'j_existing_1',
      scheduleId: 'sched_s1_h1',
      date: today,
      teachingHour: 1,
      classId: 'c1',
      subjectId: 's1',
      teacherId: 't1',
      material: 'Revisi materi',
      status: 'rejected',
      attachmentUrl: 'https://example.com/surat.jpg',
      teacherAttendanceStatus: 'izin',
    );

    final authProvider = MockAuthProvider(user);
    final masterProvider = MockMasterDataProvider(classes: classes, subjects: subjects, teachers: teachers);
    final scheduleProvider = MockScheduleProvider(schedules);
    final journalProvider = MockJournalProvider([initialJournal]);

    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    final origOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!details.toString().contains('overflowed by')) {
        origOnError?.call(details);
      }
    };
    addTearDown(() {
      FlutterError.onError = origOnError;
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/form',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/form',
          builder: (context, state) => FormJurnalScreen(
            scheduleId: 'sched_s1_h1',
            journalId: 'j_existing_1',
            dateStr: todayStr,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
          ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
          ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (context, child) => MaterialApp.router(
            routerConfig: router,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify it is in revision mode
    expect(find.text('Kirim Revisi Jurnal'), findsOneWidget);

    // Tap the checkbox to apply to all schedules today
    final checkbox = find.byType(CheckboxListTile);
    expect(checkbox, findsOneWidget);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    // Tap Kirim Revisi Jurnal
    final submitBtn = find.text('Kirim Revisi Jurnal');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify both schedules now have pending journals
    expect(journalProvider.teacherJournals.length, 2);
    final s1Journal = journalProvider.teacherJournals.firstWhere((j) => j.scheduleId == 'sched_s1_h1');
    final s2Journal = journalProvider.teacherJournals.firstWhere((j) => j.scheduleId == 'sched_s2_h5');

    expect(s1Journal.status, 'pending');
    expect(s1Journal.teacherAttendanceStatus, 'izin');

    expect(s2Journal.status, 'pending');
    expect(s2Journal.teacherAttendanceStatus, 'izin');
    expect(s2Journal.attachmentUrl, 'https://example.com/surat.jpg');
  });

  test('When one absence journal is rejected, all other absence journals for the same teacher on that day are automatically rejected', () async {
    final today = DateTime.now();

    final journal1 = JournalModel(
      id: 'j_absence_1',
      scheduleId: 'sched_1',
      date: today,
      teachingHour: 1,
      classId: 'c1',
      subjectId: 's1',
      teacherId: 't1',
      material: '[GURU IZIN] Surat Izin / Dispensasi',
      status: 'pending',
      teacherAttendanceStatus: 'izin',
    );

    final journal2 = JournalModel(
      id: 'j_absence_2',
      scheduleId: 'sched_2',
      date: today,
      teachingHour: 5,
      classId: 'c2',
      subjectId: 's2',
      teacherId: 't1',
      material: '[GURU IZIN] Surat Izin / Dispensasi',
      status: 'pending',
      teacherAttendanceStatus: 'izin',
    );

    final fakeRepo = FakeJournalRepo();
    fakeRepo.journals.addAll([journal1, journal2]);
    final journalProvider = JournalProvider(journalRepository: fakeRepo);
    await journalProvider.loadTeacherJournals('t1');

    // Admin rejects journal 1
    final success = await journalProvider.verifyJournal(
      'j_absence_1',
      'rejected',
      rejectionNote: 'Foto surat buram',
      teacherId: 't1',
    );

    expect(success, isTrue);

    // Both journal 1 and journal 2 must now be rejected with the same rejection note
    final updatedJ1 = fakeRepo.journals.firstWhere((j) => j.id == 'j_absence_1');
    final updatedJ2 = fakeRepo.journals.firstWhere((j) => j.id == 'j_absence_2');

    expect(updatedJ1.status, 'rejected');
    expect(updatedJ1.rejectionNote, 'Foto surat buram');

    expect(updatedJ2.status, 'rejected');
    expect(updatedJ2.rejectionNote, 'Foto surat buram');
  });
}
