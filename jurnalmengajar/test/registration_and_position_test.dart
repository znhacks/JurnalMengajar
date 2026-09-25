import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/screens/auth/register_screen.dart';

class FakeAuthRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

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
  Future<List<UserModel>> getAllUsersForSchool(String schoolId) async => [];
}

class FakePeriodRepo implements PeriodRepository {
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(PeriodModel model) async {}
  @override
  Future<void> update(PeriodModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeSubjectRepo implements SubjectRepository {
  List<SubjectModel> mockSubjects = [];
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async => mockSubjects;
  @override
  Future<void> create(SubjectModel model) async {}
  @override
  Future<void> update(SubjectModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeHourRepo implements HourRepository {
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(HourModel model) async {}
  @override
  Future<void> update(HourModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeClassRepo implements ClassRepository {
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(ClassModel model) async {}
  @override
  Future<void> update(ClassModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeTeacherRepo implements TeacherRepository {
  @override
  Future<List<TeacherModel>> getAll([String? schoolId]) async => [];
  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async => [];
  @override
  Future<void> create(TeacherModel model) async {}
  @override
  Future<void> update(TeacherModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeStudentRepo implements StudentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  Future<List<StudentModel>> getAllByClass(String classId) async => [];
  @override
  Future<void> create(StudentModel model) async {}
  @override
  Future<void> update(StudentModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required AuthProvider authProvider,
    required MasterDataProvider masterProvider,
    required ThemeProvider themeProvider,
    List<String>? initialSelectedSchools = const ['SMKN 11 Malang'],
    String? initialSchoolId = 'school-1',
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<MasterDataProvider>.value(value: masterProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 600;
          return ScreenUtilInit(
            designSize: isDesktop
                ? Size(constraints.maxWidth, constraints.maxHeight)
                : const Size(360, 690),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) => MaterialApp(
              home: RegisterScreen(
                initialSelectedSchools: initialSelectedSchools,
                initialSchoolId: initialSchoolId,
              ),
            ),
          );
        },
      ),
    );
  }

  group('RegisterScreen Jabatan Tests', () {
    testWidgets('Jabatan selector displays database subjects correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authProvider = AuthProvider(authRepository: FakeAuthRepo());
      final fakeSubjectRepo = FakeSubjectRepo();
      fakeSubjectRepo.mockSubjects = [
        SubjectModel(id: 's1', name: 'Matematika', isActive: true),
        SubjectModel(id: 's2', name: 'Bahasa Indonesia', isActive: true),
      ];
      final masterProvider = MasterDataProvider(
        periodRepository: FakePeriodRepo(),
        subjectRepository: fakeSubjectRepo,
        hourRepository: FakeHourRepo(),
        classRepository: FakeClassRepo(),
        teacherRepository: FakeTeacherRepo(),
        studentRepository: FakeStudentRepo(),
      );
      await masterProvider.loadAllData();
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(createTestWidget(
        authProvider: authProvider,
        masterProvider: masterProvider,
        themeProvider: themeProvider,
      ));
      await tester.pumpAndSettle();

      // Find the Jabatan field hint or label
      expect(find.text('JABATAN'), findsOneWidget);
      final fieldFinder = find.widgetWithText(TextFormField, 'Ketuk untuk memilih jabatan / guru mapel...');
      expect(fieldFinder, findsOneWidget);

      await tester.ensureVisible(fieldFinder);
      await tester.pumpAndSettle();

      // Tap the Jabatan field to open bottom sheet (AbsorbPointer absorbs tap to GestureDetector)
      await tester.tap(fieldFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify the bottom sheet title appears
      expect(find.text('Pilih Jabatan / Guru Mapel'), findsOneWidget);

      // Verify that database subjects are rendered and NOT empty
      expect(find.text('Mata pelajaran belum tersedia di database'), findsNothing);
      expect(find.text('Jabatan tidak ditemukan di daftar'), findsNothing);
      expect(find.text('Guru Matematika'), findsOneWidget);
      expect(find.text('Guru Bahasa Indonesia'), findsOneWidget);

      // Select 'Guru Matematika'
      await tester.tap(find.text('Guru Matematika'));
      await tester.pumpAndSettle();

      // Verify bottom sheet closed and value is populated in the form field
      expect(find.text('Pilih Jabatan / Guru Mapel'), findsNothing);
      expect(find.text('Guru Matematika'), findsOneWidget);
    });

    testWidgets('Jabatan selector allows searching and selecting custom position', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authProvider = AuthProvider(authRepository: FakeAuthRepo());
      final fakeSubjectRepo = FakeSubjectRepo();
      final masterProvider = MasterDataProvider(
        periodRepository: FakePeriodRepo(),
        subjectRepository: fakeSubjectRepo,
        hourRepository: FakeHourRepo(),
        classRepository: FakeClassRepo(),
        teacherRepository: FakeTeacherRepo(),
        studentRepository: FakeStudentRepo(),
      );
      final themeProvider = ThemeProvider();

      await tester.pumpWidget(createTestWidget(
        authProvider: authProvider,
        masterProvider: masterProvider,
        themeProvider: themeProvider,
      ));
      await tester.pumpAndSettle();

      final fieldFinder = find.widgetWithText(TextFormField, 'Ketuk untuk memilih jabatan / guru mapel...');
      await tester.ensureVisible(fieldFinder);
      await tester.pumpAndSettle();

      await tester.tap(fieldFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Type a custom position in the search field
      final searchFinder = find.widgetWithText(TextField, 'Cari mata pelajaran / jabatan...');
      expect(searchFinder, findsOneWidget);

      await tester.enterText(searchFinder, 'Guru Robotika');
      await tester.pumpAndSettle();

      // Verify the custom use option appears
      final customOption = find.text('Gunakan "Guru Robotika" sebagai jabatan');
      expect(customOption, findsOneWidget);

      // Tap the custom option
      await tester.tap(customOption);
      await tester.pumpAndSettle();

      // Verify the custom position is applied to the field
      expect(find.text('Guru Robotika'), findsOneWidget);
    });

    testWidgets('Jabatan selector includes custom school subjects if provided by master data', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authProvider = AuthProvider(authRepository: FakeAuthRepo());
      final fakeSubjectRepo = FakeSubjectRepo();
      fakeSubjectRepo.mockSubjects = [
        SubjectModel(id: 's1', name: 'Mekatronika', isActive: true),
      ];

      final masterProvider = MasterDataProvider(
        periodRepository: FakePeriodRepo(),
        subjectRepository: fakeSubjectRepo,
        hourRepository: FakeHourRepo(),
        classRepository: FakeClassRepo(),
        teacherRepository: FakeTeacherRepo(),
        studentRepository: FakeStudentRepo(),
      );
      await masterProvider.loadAllData();

      final themeProvider = ThemeProvider();

      await tester.pumpWidget(createTestWidget(
        authProvider: authProvider,
        masterProvider: masterProvider,
        themeProvider: themeProvider,
      ));
      await tester.pumpAndSettle();

      final fieldFinder = find.widgetWithText(TextFormField, 'Ketuk untuk memilih jabatan / guru mapel...');
      await tester.ensureVisible(fieldFinder);
      await tester.pumpAndSettle();

      await tester.tap(fieldFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify 'Guru Mekatronika' from school subjects is displayed
      expect(find.text('Guru Mekatronika'), findsOneWidget);

      await tester.tap(find.text('Guru Mekatronika'));
      await tester.pumpAndSettle();

      expect(find.text('Guru Mekatronika'), findsOneWidget);
    });

    testWidgets('Jabatan selector is hidden until school is verified, showing verification notice', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final authProvider = AuthProvider(authRepository: FakeAuthRepo());
      final fakeSubjectRepo = FakeSubjectRepo();
      fakeSubjectRepo.mockSubjects = [
        SubjectModel(id: 's1', name: 'Matematika', isActive: true),
      ];

      final masterProvider = MasterDataProvider(
        periodRepository: FakePeriodRepo(),
        subjectRepository: fakeSubjectRepo,
        hourRepository: FakeHourRepo(),
        classRepository: FakeClassRepo(),
        teacherRepository: FakeTeacherRepo(),
        studentRepository: FakeStudentRepo(),
      );
      await masterProvider.loadAllData();

      final themeProvider = ThemeProvider();

      // Pump widget with NO school verified (empty initialSelectedSchools)
      await tester.pumpWidget(createTestWidget(
        authProvider: authProvider,
        masterProvider: masterProvider,
        themeProvider: themeProvider,
        initialSelectedSchools: [],
        initialSchoolId: null,
      ));
      await tester.pumpAndSettle();

      // Verify that the prompt notice is visible
      expect(
        find.text('Masukkan dan verifikasi Kode Sekolah di atas terlebih dahulu untuk menampilkan pilihan jabatan / mata pelajaran sekolah.'),
        findsOneWidget,
      );

      // Verify that the interactive Jabatan field is NOT displayed
      expect(
        find.widgetWithText(TextFormField, 'Ketuk untuk memilih jabatan / guru mapel...'),
        findsNothing,
      );
    });
  });
}
