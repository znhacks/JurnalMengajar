import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/providers/auth_provider.dart';
import 'package:jurnalmengajar/providers/theme_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/providers/teacher_leave_provider.dart';
import 'package:jurnalmengajar/repositories/auth_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';
import 'package:jurnalmengajar/models/user_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/widgets/admin_drawer.dart';
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

class _FakeWarningLetterRepo implements WarningLetterRepository {
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

  testWidgets('Admin sidebar shows red dot on menu text when action is pending', (tester) async {
    final fakeJournalRepo = _FakeJournalRepo();
    // Simulate a pending journal waiting for admin approval
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

    final warningProvider = WarningLetterProvider(warningLetterRepository: _FakeWarningLetterRepo());
    final leaveProvider = TeacherLeaveProvider();
    final themeProvider = ThemeProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<JournalProvider>.value(value: journalProvider),
          ChangeNotifierProvider<WarningLetterProvider>.value(value: warningProvider),
          ChangeNotifierProvider<TeacherLeaveProvider>.value(value: leaveProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, child) => MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              drawer: AdminDrawer(currentRoute: '/admin/dashboard'),
            ),
          ),
        ),
      ),
    );

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Verify Jurnal Mengajar is present
    expect(find.textContaining('Jurnal Mengajar'), findsOneWidget);

    // Verify red dot container exists inside the Jurnal Mengajar title
    final redDotFinder = find.byWidgetPredicate((widget) {
      if (widget is Container && widget.decoration is BoxDecoration) {
        final box = widget.decoration as BoxDecoration;
        return box.color == const Color(0xFFEF4444) && box.shape == BoxShape.circle;
      }
      return false;
    });

    expect(redDotFinder, findsWidgets);
  });
}
