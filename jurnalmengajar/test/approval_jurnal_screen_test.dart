import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/providers/teacher_leave_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/student_academic_history_model.dart';
import 'package:jurnalmengajar/screens/admin/approval_jurnal_screen.dart';
import 'package:jurnalmengajar/widgets/desktop_sidebar_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<UserModel?> getCurrentUser() async {
    return UserModel(
      id: 'test-admin',
      email: 'admin@test.com',
      fullName: 'Administrator',
      role: 'admin',
      schoolId: 'school-1',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeJournalRepo implements JournalRepository {
  List<JournalModel> journals = [];
  @override
  Future<List<JournalModel>> getAll([String? schoolId]) async => journals;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePeriodRepo implements PeriodRepository {
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSubjectRepo implements SubjectRepository {
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeHourRepo implements HourRepository {
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClassRepo implements ClassRepository {
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTeacherRepo implements TeacherRepository {
  @override
  Future<List<TeacherModel>> getAll() async => [];
  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStudentRepo implements StudentRepository {
  @override
  Future<List<StudentAcademicHistoryModel>> getStudentHistories(String studentId) async => [];
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeWarningLetterRepo implements WarningLetterRepository {
  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ApprovalJurnalScreen renders properly on desktop and mobile', (tester) async {
    final fakeJournalRepo = _FakeJournalRepo();
    fakeJournalRepo.journals = [
      JournalModel(
        id: 'j-1',
        scheduleId: 's-1',
        date: DateTime.now(),
        teachingHour: 1,
        material: 'Materi Test',
        status: 'pending',
        schoolId: 'school-1',
        teacherId: 't-1',
        classId: 'c-1',
        subjectId: 'sub-1',
      ),
    ];

    final authProvider = AuthProvider(
      authRepository: _FakeAuthRepo(),
      initialActiveSchoolId: 'school-1',
      initialActiveRole: 'admin',
    );
    final journalProvider = JournalProvider(journalRepository: fakeJournalRepo);
    await journalProvider.loadAllJournals('school-1');

    final masterProvider = MasterDataProvider(
      periodRepository: FakePeriodRepo(),
      subjectRepository: FakeSubjectRepo(),
      hourRepository: FakeHourRepo(),
      classRepository: FakeClassRepo(),
      teacherRepository: FakeTeacherRepo(),
      studentRepository: FakeStudentRepo(),
    );
    final warningProvider = WarningLetterProvider(warningLetterRepository: FakeWarningLetterRepo());
    final leaveProvider = TeacherLeaveProvider();
    final themeProvider = ThemeProvider();

    AppShell.forceDesktopWeb = true;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
          ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
          ChangeNotifierProvider<WarningLetterProvider>.value(value: warningProvider),
          ChangeNotifierProvider<TeacherLeaveProvider>.value(value: leaveProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: ScreenUtilInit(
          designSize: const Size(1440, 900),
          builder: (_, child) => MaterialApp(
            theme: AppTheme.darkTheme,
            home: const DesktopSidebarShell(
              currentRoute: '/admin/approvals',
              child: ApprovalJurnalScreen(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Persetujuan Jurnal'), findsWidgets);

    final checkboxFinder = find.byType(Checkbox).first;
    await tester.tap(checkboxFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('Jurnal Terpilih'), findsOneWidget);
  });
}
