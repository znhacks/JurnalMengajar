import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/user_school_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/widgets/school_switcher_modal.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<UserModel?> getCurrentUser() async {
    return UserModel(
      id: 'guru-1',
      email: 'guru@test.com',
      fullName: 'Guru Test',
      role: 'guru',
      schoolId: 'school-1',
      schoolName: 'SMKN 11 Malang',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestAuthProvider extends AuthProvider {
  final List<UserSchoolModel> _mockMemberships;
  final String _mockActiveSchoolId;
  final String _mockActiveRole;

  String? switchedSchoolId;
  String? switchedSchoolName;
  String? switchedRole;

  _TestAuthProvider({
    required List<UserSchoolModel> memberships,
    required String activeSchoolId,
    required String activeRole,
  })  : _mockMemberships = memberships,
        _mockActiveSchoolId = activeSchoolId,
        _mockActiveRole = activeRole,
        super(authRepository: _FakeAuthRepo());

  @override
  List<UserSchoolModel> get userMemberships => _mockMemberships;

  @override
  String? get activeSchoolId => _mockActiveSchoolId;

  @override
  String get activeRole => _mockActiveRole;

  @override
  bool get isAdminAsli => false;

  @override
  bool get isAdminCadangan => true;

  @override
  Future<void> switchActiveSchool(String schoolId, String schoolName, String role) async {
    switchedSchoolId = schoolId;
    switchedSchoolName = schoolName;
    switchedRole = role;
  }
}

class _FakeJournalRepo implements JournalRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScheduleRepo implements ScheduleRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWarningRepo implements WarningLetterRepository {
  @override
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId, [String? schoolId]) async => [];
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

  Widget buildTestModal({
    required Size screenSize,
    bool isDark = false,
    _TestAuthProvider? authProvider,
  }) {
    final provider = authProvider ??
        _TestAuthProvider(
          activeSchoolId: 'school-1',
          activeRole: 'guru',
          memberships: [
            UserSchoolModel(
              id: 'mem-1',
              userId: 'guru-1',
              schoolId: 'school-1',
              role: 'admin',
              schoolName: 'SMKN 11 Malang',
              status: 'active',
            ),
            UserSchoolModel(
              id: 'mem-2',
              userId: 'guru-1',
              schoolId: 'school-1',
              role: 'guru',
              schoolName: 'SMKN 11 Malang',
              status: 'active',
            ),
            UserSchoolModel(
              id: 'mem-3',
              userId: 'guru-1',
              schoolId: 'school-2',
              role: 'guru',
              schoolName: 'SMKN 4 Malang',
              status: 'requested_exit',
            ),
          ],
        );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: provider),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<ScheduleProvider>(
          create: (_) => ScheduleProvider(scheduleRepository: _FakeScheduleRepo()),
        ),
        ChangeNotifierProvider<JournalProvider>(
          create: (_) => JournalProvider(journalRepository: _FakeJournalRepo()),
        ),
        ChangeNotifierProvider<WarningLetterProvider>(
          create: (_) => WarningLetterProvider(warningLetterRepository: _FakeWarningRepo()),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 690),
        minTextAdapt: true,
        builder: (context, _) => MaterialApp(
          theme: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(size: screenSize),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: SchoolSwitcherModal(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('SchoolSwitcherModal renders without overflow on 360px screen with requested_exit', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestModal(screenSize: const Size(360, 800)));
    await tester.pumpAndSettle();

    // Verify school names are rendered
    expect(find.text('SMKN 11 Malang'), findsNWidgets(2));
    expect(find.text('SMKN 4 Malang'), findsOneWidget);

    // Verify requested_exit badge is rendered cleanly
    expect(find.text('MENUNGGU PERSETUJUAN ADMIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SchoolSwitcherModal renders without overflow on compact 320px screen in Dark Mode', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestModal(screenSize: const Size(320, 640), isDark: true));
    await tester.pumpAndSettle();

    expect(find.text('MENUNGGU PERSETUJUAN ADMIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SchoolSwitcherModal allows switching to school with requested_exit status', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testAuth = _TestAuthProvider(
      activeSchoolId: 'school-1',
      activeRole: 'guru',
      memberships: [
        UserSchoolModel(
          id: 'mem-1',
          userId: 'guru-1',
          schoolId: 'school-1',
          role: 'guru',
          schoolName: 'SMKN 11 Malang',
          status: 'active',
        ),
        UserSchoolModel(
          id: 'mem-2',
          userId: 'guru-1',
          schoolId: 'school-2',
          role: 'guru',
          schoolName: 'SMKN 4 Malang',
          status: 'requested_exit',
        ),
      ],
    );

    await tester.pumpWidget(buildTestModal(
      screenSize: const Size(360, 800),
      authProvider: testAuth,
    ));
    await tester.pumpAndSettle();

    // Tap on SMKN 4 Malang which is in requested_exit state
    await tester.tap(find.text('SMKN 4 Malang'));
    await tester.pumpAndSettle();

    // Verify it switched successfully to school-2 (SMKN 4 Malang)
    expect(testAuth.switchedSchoolId, equals('school-2'));
    expect(testAuth.switchedSchoolName, equals('SMKN 4 Malang'));
    expect(testAuth.switchedRole, equals('guru'));
  });
}
