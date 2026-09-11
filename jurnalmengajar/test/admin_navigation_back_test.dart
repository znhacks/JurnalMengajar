import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/widgets/admin_drawer.dart';
import 'package:jurnalmengajar/widgets/web_navigation_shortcut_wrapper.dart';
import 'package:jurnalmengajar/screens/admin/admin_jurnal_list_screen.dart';
import 'package:jurnalmengajar/screens/admin/master/subject_screen.dart';
import 'package:jurnalmengajar/screens/admin/master/hour_screen.dart';
import 'package:jurnalmengajar/screens/admin/master/class_screen.dart';
import 'package:jurnalmengajar/screens/admin/master/teacher_screen.dart';
import 'package:jurnalmengajar/screens/admin/master/user_screen.dart';
import 'package:jurnalmengajar/screens/admin/master/period_screen.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';

// ── Mock Repositories ──────────────────────────────────────────────
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  AuthProvider createAdminAuth() {
    final repo = FakeAuthRepo();
    repo.mockUser = UserModel(
      id: 'admin-1',
      email: 'admin@test.com',
      fullName: 'Admin Test',
      role: 'admin',
      status: 'approved',
      schoolId: 'school-1',
    );
    return AuthProvider(authRepository: repo);
  }

  MasterDataProvider createMasterData() {
    return MasterDataProvider(
      periodRepository: FakePeriodRepo(),
      subjectRepository: FakeSubjectRepo(),
      hourRepository: FakeHourRepo(),
      classRepository: FakeClassRepo(),
      teacherRepository: FakeTeacherRepo(),
      studentRepository: FakeStudentRepo(),
    );
  }

  JournalProvider createJournalProvider() {
    return JournalProvider(journalRepository: FakeJournalRepo());
  }

  ScheduleProvider createScheduleProvider() {
    return ScheduleProvider(scheduleRepository: FakeScheduleRepo());
  }

  Widget createTestApp({
    required Widget child,
    AuthProvider? auth,
    MasterDataProvider? master,
    JournalProvider? journal,
    ScheduleProvider? schedule,
  }) {
    final router = GoRouter(
      initialLocation: '/test-screen',
      routes: [
        GoRoute(
          path: '/test-screen',
          builder: (context, state) => child,
        ),
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const Scaffold(body: Text('Admin Dashboard')),
        ),
      ],
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth ?? createAdminAuth()),
        ChangeNotifierProvider<MasterDataProvider>.value(value: master ?? createMasterData()),
        ChangeNotifierProvider<JournalProvider>.value(value: journal ?? createJournalProvider()),
        ChangeNotifierProvider<ScheduleProvider>.value(value: schedule ?? createScheduleProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<WarningLetterProvider>(
          create: (_) => WarningLetterProvider(warningLetterRepository: FakeWarningLetterRepo()),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, _) => MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
  }

  group('Admin Navigation & Back Button Tests', () {
    testWidgets('AdminDrawer pushes routes for modules and goes to dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/admin/dashboard',
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => Scaffold(
              drawer: const AdminDrawer(currentRoute: '/admin/dashboard'),
              body: const Text('Dashboard Screen'),
            ),
          ),
          GoRoute(
            path: '/admin/journals',
            builder: (context, state) => const Text('Journals Screen'),
          ),
          GoRoute(
            path: '/admin/master-data/subjects',
            builder: (context, state) => const Text('Subjects Screen'),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: createAdminAuth()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<WarningLetterProvider>(
              create: (_) => WarningLetterProvider(warningLetterRepository: FakeWarningLetterRepo()),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Verify drawer items exist
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Jurnal Mengajar'), findsOneWidget);

      // Tap Jurnal Mengajar
      await tester.tap(find.text('Jurnal Mengajar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Verify router stack now contains Journals Screen and canPop is true
      expect(find.text('Journals Screen'), findsOneWidget);
      expect(router.canPop(), isTrue);

      // Pop back to dashboard
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Dashboard Screen'), findsOneWidget);
    });

    testWidgets('WebNavigationShortcutWrapper ESC dismisses dialog before page pop', (tester) async {
      final router = GoRouter(
        initialLocation: '/admin/journals',
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const Text('Dashboard'),
          ),
          GoRoute(
            path: '/admin/journals',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Konfirmasi'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dCtx).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Buka Dialog'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: createAdminAuth()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => MaterialApp.router(
              routerConfig: router,
              builder: (ctx, child) => WebNavigationShortcutWrapper(
                router: router,
                child: child ?? const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi'), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Dialog should be dismissed, and page should STILL be on journals, not navigated to dashboard
      expect(find.text('Konfirmasi'), findsNothing);
      expect(find.text('Buka Dialog'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
    });

    testWidgets('Admin screens render Back button with arrow_back_rounded & tooltip "Kembali"', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. AdminJurnalListScreen
      await tester.pumpWidget(createTestApp(child: const AdminJurnalListScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);

      // 2. MasterSubjectScreen
      await tester.pumpWidget(createTestApp(child: const MasterSubjectScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);

      // 3. MasterHourScreen
      await tester.pumpWidget(createTestApp(child: const MasterHourScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);

      // 4. MasterClassScreen
      await tester.pumpWidget(createTestApp(child: const MasterClassScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);

      // 5. MasterTeacherScreen
      await tester.pumpWidget(createTestApp(child: const MasterTeacherScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);

      // 6. MasterUserScreen
      await tester.pumpWidget(createTestApp(child: const MasterUserScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);

      // 7. MasterPeriodScreen
      await tester.pumpWidget(createTestApp(child: const MasterPeriodScreen()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);
    });

    testWidgets('Back button pops navigation stack correctly when history exists', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/admin/dashboard',
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push('/admin/master-data/subjects'),
                  child: const Text('Go to Subjects'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/admin/master-data/subjects',
            builder: (context, state) => const MasterSubjectScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: createAdminAuth()),
            ChangeNotifierProvider<MasterDataProvider>.value(value: createMasterData()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<WarningLetterProvider>(
              create: (_) => WarningLetterProvider(warningLetterRepository: FakeWarningLetterRepo()),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Go to subjects screen via push
      await tester.tap(find.text('Go to Subjects'));
      await tester.pumpAndSettle();

      expect(find.text('Master Pelajaran'), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);

      // Tap Back button
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      // Should return to dashboard
      expect(find.text('Go to Subjects'), findsOneWidget);
      expect(find.text('Master Pelajaran'), findsNothing);
    });

    testWidgets('Back button safely falls back to /admin/dashboard when canPop is false', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/admin/master-data/subjects',
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const Scaffold(
              body: Text('Admin Dashboard Fallback Target'),
            ),
          ),
          GoRoute(
            path: '/admin/master-data/subjects',
            builder: (context, state) => const MasterSubjectScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: createAdminAuth()),
            ChangeNotifierProvider<MasterDataProvider>.value(value: createMasterData()),
            ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<WarningLetterProvider>(
              create: (_) => WarningLetterProvider(warningLetterRepository: FakeWarningLetterRepo()),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, _) => MaterialApp.router(
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Master Pelajaran'), findsOneWidget);
      expect(router.canPop(), isFalse);

      // Tap Back button - canPop is false, triggers context.go('/admin/dashboard')
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('Admin Dashboard Fallback Target'), findsOneWidget);
    });
  });
}
