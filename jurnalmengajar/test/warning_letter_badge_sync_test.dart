import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/utils/warning_letter_grouper.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';

void main() {
  group('Warning Letter Badge Sync & Grouping Tests', () {
    test('Synchronizes sidebar badge count with Perlu Diisi count when 2 warnings fall on same day (27 items -> 26 cards)', () {
      final List<WarningLetterModel> warnings = [];

      // Create 25 warnings on 25 unique dates in Oct/Nov 2026
      for (int i = 1; i <= 25; i++) {
        final day = i.toString().padLeft(2, '0');
        warnings.add(
          WarningLetterModel(
            id: 'warn-$i',
            teacherId: 'teacher-1',
            schoolId: 'smkn11',
            scheduleId: 'sched-$i',
            reason: 'Terlambat mengisi jurnal mengajar pada tanggal $day Okt 2026 untuk kelas: XII RPL 1.',
            issuedAt: DateTime(2026, 10, i),
            status: 'unread',
          ),
        );
      }

      // Add 2 warnings on the SAME date (e.g. 2 Nov 2026) for different classes/schedules
      warnings.add(
        WarningLetterModel(
          id: 'warn-26-a',
          teacherId: 'teacher-1',
          schoolId: 'smkn11',
          scheduleId: 'sched-26-a',
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal 2 Nov 2026 untuk kelas: XI RPL 1 (Mapel: Matematika, Jam ke-1- 3).',
          issuedAt: DateTime(2026, 11, 2, 8),
          status: 'unread',
        ),
      );
      warnings.add(
        WarningLetterModel(
          id: 'warn-26-b',
          teacherId: 'teacher-1',
          schoolId: 'smkn11',
          scheduleId: 'sched-26-b',
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal 2 Nov 2026 untuk kelas: XII RPL 2 (Mapel: Matematika, Jam ke-8- 11).',
          issuedAt: DateTime(2026, 11, 2, 14),
          status: 'unread',
        ),
      );

      // Verify raw count is 27
      expect(warnings.length, 27);

      // Test Drawer calculation
      final drawerBadgeCount = WarningLetterGrouper.countPendingGroups(
        warnings: warnings,
        activeSchoolId: 'smkn11',
      );

      // Test Screen grouping result
      final screenResult = WarningLetterGrouper.groupWarnings(
        warnings: warnings,
        activeSchoolId: 'smkn11',
      );

      // Both drawer and screen MUST match exactly 26
      expect(drawerBadgeCount, 26);
      expect(screenResult.pendingCount, 26);
      expect(drawerBadgeCount, equals(screenResult.pendingCount));
      expect(screenResult.sortedGroups.length, 26);

      // On 2026-11-02, there should be 2 grouped warnings
      final nov2Group = screenResult.groupedMap['2026-11-02'];
      expect(nov2Group, isNotNull);
      expect(nov2Group!.length, 2);
    });

    test('Confirmed (read) warnings reduce pending count on both sidebar and screen identically', () {
      final List<WarningLetterModel> warnings = [
        WarningLetterModel(
          id: 'warn-1',
          teacherId: 'teacher-1',
          schoolId: 'smkn11',
          scheduleId: 'sched-1',
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal 1 Nov 2026 untuk kelas: X RPL 1.',
          issuedAt: DateTime(2026, 11, 1),
          status: 'read', // Confirmed!
        ),
        WarningLetterModel(
          id: 'warn-2',
          teacherId: 'teacher-1',
          schoolId: 'smkn11',
          scheduleId: 'sched-2',
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal 2 Nov 2026 untuk kelas: XI RPL 1.',
          issuedAt: DateTime(2026, 11, 2),
          status: 'unread',
        ),
      ];

      final drawerBadge = WarningLetterGrouper.countPendingGroups(
        warnings: warnings,
        activeSchoolId: 'smkn11',
      );
      final screenResult = WarningLetterGrouper.groupWarnings(
        warnings: warnings,
        activeSchoolId: 'smkn11',
      );

      expect(drawerBadge, 1);
      expect(screenResult.pendingCount, 1);
      expect(screenResult.completedCount, 1);
      expect(screenResult.sortedGroups.length, 2);
    });

    test('Filters out corrupt warnings (Kelas--) and strictly respects school tenant isolation', () {
      final List<WarningLetterModel> warnings = [
        WarningLetterModel(
          id: 'warn-valid',
          teacherId: 'teacher-1',
          schoolId: 'smkn11',
          scheduleId: 'sched-1',
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal 1 Nov 2026 untuk kelas: X RPL 1.',
          issuedAt: DateTime(2026, 11, 1),
          status: 'unread',
        ),
        WarningLetterModel(
          id: 'warn-corrupt',
          teacherId: 'teacher-1',
          schoolId: 'smkn11',
          scheduleId: 'sched-2',
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal 2 Nov 2026 untuk kelas: Kelas--.',
          issuedAt: DateTime(2026, 11, 2),
          status: 'unread',
        ),
        WarningLetterModel(
          id: 'warn-other-school',
          teacherId: 'teacher-1',
          schoolId: 'other-school',
          scheduleId: 'sched-3',
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal 3 Nov 2026 untuk kelas: XII RPL 1.',
          issuedAt: DateTime(2026, 11, 3),
          status: 'unread',
        ),
      ];

      final drawerBadge = WarningLetterGrouper.countPendingGroups(
        warnings: warnings,
        activeSchoolId: 'smkn11',
      );
      final screenResult = WarningLetterGrouper.groupWarnings(
        warnings: warnings,
        activeSchoolId: 'smkn11',
      );

      expect(drawerBadge, 1);
      expect(screenResult.pendingCount, 1);
      expect(screenResult.schoolWarnings.length, 1);
      expect(screenResult.schoolWarnings.first.id, 'warn-valid');
    });

    test('extractWarningDate correctly uses cached schedule date if available', () {
      final schedule = ScheduleModel(
        id: 'sched-cached',
        teacherId: 'teacher-1',
        classId: 'class-1',
        subjectId: 'sub-1',
        periodId: 'per-1',
        date: DateTime(2026, 9, 15),
        teachingHour: 1,
        isActive: true,
      );

      final warning = WarningLetterModel(
        id: 'warn-1',
        teacherId: 'teacher-1',
        schoolId: 'smkn11',
        scheduleId: 'sched-cached',
        reason: 'Terlambat mengisi jurnal mengajar...',
        issuedAt: DateTime(2026, 9, 20),
        status: 'unread',
      );

      final extractedDate = WarningLetterGrouper.extractWarningDate(warning, [schedule]);
      expect(extractedDate, DateTime(2026, 9, 15));
    });
  });
}

