import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/widgets/class_realization_card.dart';

void main() {
  group('Realisasi Mengajar Per Kelas - Unit & Widget Tests', () {
    Widget buildTestWidget({
      required List<ClassModel> classes,
      required List<ScheduleModel> schedules,
      required List<JournalModel> journals,
      bool isLoading = false,
      String? errorMessage,
      String? selectedTeacherId,
      String? selectedTeacherName,
    }) {
      return ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) => MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClassRealizationCard(
                classes: classes,
                schedules: schedules,
                journals: journals,
                isLoading: isLoading,
                errorMessage: errorMessage,
                selectedTeacherId: selectedTeacherId,
                selectedTeacherName: selectedTeacherName,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('TEST 1 & 2: Renders accurate realization and target (0/8 and 1/11)', (tester) async {
      final classes = [
        ClassModel(id: 'cls-1', name: 'XI RPL 1', periodId: 'p-1', studentCount: 30),
        ClassModel(id: 'cls-2', name: 'XII RPL 1 - Beta', periodId: 'p-1', studentCount: 32),
      ];

      // 8 scheduled sessions for XI RPL 1
      final schedulesClass1 = List.generate(8, (i) => ScheduleModel(
        id: 's1-$i',
        periodId: 'p-1',
        date: DateTime(2026, 9, 1 + i),
        teachingHour: 1,
        classId: 'cls-1',
        subjectId: 'sub-1',
        teacherId: 't-1',
        isActive: true,
      ));

      // 11 scheduled sessions for XII RPL 1 - Beta
      final schedulesClass2 = List.generate(11, (i) => ScheduleModel(
        id: 's2-$i',
        periodId: 'p-1',
        date: DateTime(2026, 9, 1 + i),
        teachingHour: 2,
        classId: 'cls-2',
        subjectId: 'sub-2',
        teacherId: 't-2',
        isActive: true,
      ));

      // 1 filled journal for XII RPL 1 - Beta, 0 for XI RPL 1
      final journals = [
        JournalModel(
          id: 'j-1',
          scheduleId: 's2-0',
          date: DateTime(2026, 9, 1),
          teachingHour: 2,
          classId: 'cls-2',
          subjectId: 'sub-2',
          teacherId: 't-2',
          material: 'Flutter Architecture',
          status: 'verified',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(
        classes: classes,
        schedules: [...schedulesClass1, ...schedulesClass2],
        journals: journals,
      ));
      await tester.pumpAndSettle();

      // Verify title & badge
      expect(find.text('Realisasi Mengajar Per Kelas'), findsOneWidget);
      expect(find.text('2 Kelas'), findsOneWidget);

      // Verify Class 1: XI RPL 1 -> 0 / 8 Jurnal
      expect(find.text('XI RPL 1'), findsOneWidget);
      expect(find.text('0 / 8 Jurnal'), findsOneWidget);

      // Verify Class 2: XII RPL 1 - Beta -> 1 / 11 Jurnal
      expect(find.text('XII RPL 1 - Beta'), findsOneWidget);
      expect(find.text('1 / 11 Jurnal'), findsOneWidget);

      // Verify Progress Indicators
      final progressFinders = find.byType(LinearProgressIndicator);
      expect(progressFinders, findsNWidgets(2));

      final progress1 = tester.widget<LinearProgressIndicator>(progressFinders.at(0));
      expect(progress1.value, 0.0);

      final progress2 = tester.widget<LinearProgressIndicator>(progressFinders.at(1));
      expect((progress2.value! - (1 / 11)).abs() < 0.001, isTrue);
    });

    testWidgets('TEST 3: Full realization 11 / 11 Jurnal renders 100% progress', (tester) async {
      final classes = [
        ClassModel(id: 'cls-full', name: 'XII RPL 2 - Beta', periodId: 'p-1', studentCount: 30),
      ];

      final schedules = List.generate(11, (i) => ScheduleModel(
        id: 's-$i',
        periodId: 'p-1',
        date: DateTime(2026, 9, 1 + i),
        teachingHour: 1,
        classId: 'cls-full',
        subjectId: 'sub-1',
        teacherId: 't-1',
        isActive: true,
      ));

      final journals = List.generate(11, (i) => JournalModel(
        id: 'j-$i',
        scheduleId: 's-$i',
        date: DateTime(2026, 9, 1 + i),
        teachingHour: 1,
        classId: 'cls-full',
        subjectId: 'sub-1',
        teacherId: 't-1',
        material: 'Materi $i',
        status: 'verified',
      ));

      await tester.pumpWidget(buildTestWidget(
        classes: classes,
        schedules: schedules,
        journals: journals,
      ));
      await tester.pumpAndSettle();

      expect(find.text('XII RPL 2 - Beta'), findsOneWidget);
      expect(find.text('11 / 11 Jurnal'), findsOneWidget);

      final progress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progress.value, 1.0);
    });

    testWidgets('TEST 4: Division by zero safety: 0 scheduled sessions renders 0 / 0 Jurnal without crash', (tester) async {
      final classes = [
        ClassModel(id: 'cls-empty', name: 'X Tanpa Jadwal', periodId: 'p-1', studentCount: 25),
      ];

      await tester.pumpWidget(buildTestWidget(
        classes: classes,
        schedules: [],
        journals: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('X Tanpa Jadwal'), findsOneWidget);
      expect(find.text('0 / 0 Jurnal'), findsOneWidget);

      final progress = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(progress.value, 0.0);
    });

    testWidgets('TEST 5: Duplicate Prevention: Duplicate journal items in list do NOT inflate filled count', (tester) async {
      final classes = [
        ClassModel(id: 'cls-dup', name: 'XII RPL 1', periodId: 'p-1', studentCount: 30),
      ];

      final schedules = [
        ScheduleModel(
          id: 's-1',
          periodId: 'p-1',
          date: DateTime(2026, 9, 1),
          teachingHour: 1,
          classId: 'cls-dup',
          subjectId: 'sub-1',
          teacherId: 't-1',
          isActive: true,
        ),
      ];

      // Same journal record added multiple times (e.g. from join duplication)
      final duplicateJournals = [
        JournalModel(
          id: 'j-unique-1',
          scheduleId: 's-1',
          date: DateTime(2026, 9, 1),
          teachingHour: 1,
          classId: 'cls-dup',
          subjectId: 'sub-1',
          teacherId: 't-1',
          material: 'Test',
          status: 'verified',
        ),
        JournalModel(
          id: 'j-unique-1',
          scheduleId: 's-1',
          date: DateTime(2026, 9, 1),
          teachingHour: 1,
          classId: 'cls-dup',
          subjectId: 'sub-1',
          teacherId: 't-1',
          material: 'Test',
          status: 'verified',
        ),
      ];

      await tester.pumpWidget(buildTestWidget(
        classes: classes,
        schedules: schedules,
        journals: duplicateJournals,
      ));
      await tester.pumpAndSettle();

      // Must be 1 / 1 Jurnal, NOT 2 / 1
      expect(find.text('1 / 1 Jurnal'), findsOneWidget);
    });

    testWidgets('TEST 6: Multi-Tenant & Teacher Scoping: Only active school & selected teacher data counted', (tester) async {
      final classes = [
        ClassModel(id: 'cls-math', name: 'XI RPL 1', periodId: 'p-1', studentCount: 30),
      ];

      final schedules = [
        ScheduleModel(
          id: 's-t1',
          periodId: 'p-1',
          date: DateTime(2026, 9, 1),
          teachingHour: 1,
          classId: 'cls-math',
          subjectId: 'sub-1',
          teacherId: 'teacher-pak-heru',
          isActive: true,
        ),
        ScheduleModel(
          id: 's-t2',
          periodId: 'p-1',
          date: DateTime(2026, 9, 2),
          teachingHour: 1,
          classId: 'cls-math',
          subjectId: 'sub-2',
          teacherId: 'teacher-bu-siti',
          isActive: true,
        ),
      ];

      final journals = [
        JournalModel(
          id: 'j-t1',
          scheduleId: 's-t1',
          date: DateTime(2026, 9, 1),
          teachingHour: 1,
          classId: 'cls-math',
          subjectId: 'sub-1',
          teacherId: 'teacher-pak-heru',
          material: 'Matematika',
          status: 'verified',
        ),
        JournalModel(
          id: 'j-t2',
          scheduleId: 's-t2',
          date: DateTime(2026, 9, 2),
          teachingHour: 1,
          classId: 'cls-math',
          subjectId: 'sub-2',
          teacherId: 'teacher-bu-siti',
          material: 'Pemrograman Web',
          status: 'verified',
        ),
      ];

      // When Pak Heru is selected:
      await tester.pumpWidget(buildTestWidget(
        classes: classes,
        schedules: schedules,
        journals: journals,
        selectedTeacherId: 'teacher-pak-heru',
        selectedTeacherName: 'Pak Heru',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Realisasi Mengajar — Pak Heru'), findsOneWidget);
      // Only Pak Heru's 1 session and 1 journal counted for this class
      expect(find.text('1 / 1 Jurnal'), findsOneWidget);
    });

    testWidgets('TEST 7: Empty state displays "Belum ada data realisasi mengajar."', (tester) async {
      await tester.pumpWidget(buildTestWidget(
        classes: [],
        schedules: [],
        journals: [],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada data realisasi mengajar.'), findsOneWidget);
    });
  });
}
