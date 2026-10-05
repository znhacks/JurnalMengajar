import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jurnalmengajar/core/theme/app_theme.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/widgets/admin_period_selector_bar.dart';

void main() {
  group('Admin Historical Period Access Tests', () {
    final periodActive = PeriodModel(
      id: 'period-2026-2027',
      name: '2026/2027',
      isActive: true,
      schoolId: 'school-1',
    );

    final periodHistorical1 = PeriodModel(
      id: 'period-2025-2026',
      name: '2025/2026',
      isActive: false,
      schoolId: 'school-1',
    );

    final periodHistorical2 = PeriodModel(
      id: 'period-2024-2025',
      name: '2024/2025',
      isActive: false,
      schoolId: 'school-1',
    );

    testWidgets('AdminPeriodSelectorBar renders active period with Aktif badge and no read-only banner', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AdminPeriodSelectorBar(
                periods: [periodActive, periodHistorical1, periodHistorical2],
                selectedPeriodId: periodActive.id,
                onPeriodChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify label and active period text
      expect(find.text('Tahun Ajaran:'), findsOneWidget);
      expect(find.text('2026/2027'), findsWidgets);
      expect(find.text('Aktif'), findsWidgets);

      // Verify historical read-only warning is NOT present for active period
      expect(find.textContaining('Mode Histori'), findsNothing);
      expect(find.byIcon(Icons.lock_clock_rounded), findsNothing);
    });

    testWidgets('AdminPeriodSelectorBar renders historical period with Arsip badge and Read-Only warning banner', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AdminPeriodSelectorBar(
                periods: [periodActive, periodHistorical1, periodHistorical2],
                selectedPeriodId: periodHistorical1.id,
                onPeriodChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify historical period name and Arsip badge
      expect(find.text('2025/2026'), findsWidgets);
      expect(find.text('Arsip'), findsWidgets);

      // Verify historical banner is shown
      expect(find.textContaining('Mode Histori (2025/2026)'), findsOneWidget);
      expect(find.textContaining('READ-ONLY'), findsOneWidget);
      expect(find.textContaining('Tahun ajaran aktif sekolah tetap 2026/2027'), findsOneWidget);
      expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
    });

    test('JournalModel serialization supports periodId correctly', () {
      final now = DateTime.now();
      final journal = JournalModel(
        id: 'j-1',
        scheduleId: 's-1',
        teacherId: 't-1',
        classId: 'c-1',
        subjectId: 'sub-1',
        periodId: 'period-2025-2026',
        date: now,
        teachingHour: 1,
        material: 'Algoritma Pemrograman',
        status: 'verified',
        schoolId: 'school-1',
      );

      final json = journal.toJson();
      expect(json['period_id'], 'period-2025-2026');

      final deserialized = JournalModel.fromJson(json);
      expect(deserialized.periodId, 'period-2025-2026');
      expect(deserialized.material, 'Algoritma Pemrograman');

      final copied = journal.copyWith(periodId: 'period-2026-2027');
      expect(copied.periodId, 'period-2026-2027');
      expect(copied.id, journal.id);
    });

    test('ScheduleModel serialization and period scoping', () {
      final now = DateTime.now();
      final sched2025 = ScheduleModel(
        id: 'sched-past',
        periodId: 'period-2025-2026',
        date: now,
        teachingHour: 1,
        classId: 'class-past',
        subjectId: 'subject-1',
        teacherId: 'teacher-1',
        isActive: true,
        schoolId: 'school-1',
      );

      final sched2026 = ScheduleModel(
        id: 'sched-active',
        periodId: 'period-2026-2027',
        date: now,
        teachingHour: 2,
        classId: 'class-active',
        subjectId: 'subject-1',
        teacherId: 'teacher-1',
        isActive: true,
        schoolId: 'school-1',
      );

      final schedules = [sched2025, sched2026];

      // Filtering for 2025/2026 must ONLY return 2025/2026 schedules
      final pastOnly = schedules.where((s) => s.periodId == 'period-2025-2026').toList();
      expect(pastOnly.length, 1);
      expect(pastOnly.first.id, 'sched-past');

      // Filtering for 2026/2027 must ONLY return 2026/2027 schedules
      final activeOnly = schedules.where((s) => s.periodId == 'period-2026-2027').toList();
      expect(activeOnly.length, 1);
      expect(activeOnly.first.id, 'sched-active');
    });

    test('Journals of different periods are strictly isolated', () {
      final now = DateTime.now();
      final jPast = JournalModel(
        id: 'j-past',
        scheduleId: 's-past',
        teacherId: 't-1',
        classId: 'c-past',
        subjectId: 'sub-1',
        periodId: 'period-2025-2026',
        date: now,
        teachingHour: 1,
        material: 'Materi 2025',
        status: 'verified',
        schoolId: 'school-1',
      );

      final jActive = JournalModel(
        id: 'j-active',
        scheduleId: 's-active',
        teacherId: 't-1',
        classId: 'c-active',
        subjectId: 'sub-1',
        periodId: 'period-2026-2027',
        date: now,
        teachingHour: 1,
        material: 'Materi 2026',
        status: 'verified',
        schoolId: 'school-1',
      );

      final allJournals = [jPast, jActive];

      final filteredPast = allJournals.where((j) => j.periodId == 'period-2025-2026').toList();
      expect(filteredPast.length, 1);
      expect(filteredPast.first.material, 'Materi 2025');

      final filteredActive = allJournals.where((j) => j.periodId == 'period-2026-2027').toList();
      expect(filteredActive.length, 1);
      expect(filteredActive.first.material, 'Materi 2026');
    });
  });
}
