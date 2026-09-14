import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';

void main() {
  group('Teacher Punctuality & Statistics Calculation Tests', () {
    final teacher1 = TeacherModel(
      id: 't-1',
      name: 'Pak Budi',
      position: 'Guru Matematika',
      address: '',
      phoneNumber: '',
      email: 'budi@sekolah.sch.id',
    );

    final teacher2 = TeacherModel(
      id: 't-2',
      name: 'Bu Siti',
      position: 'Guru Bahasa Inggris',
      address: '',
      phoneNumber: '',
      email: 'siti@sekolah.sch.id',
    );

    test('Journal submitted on the same day as teaching session is classified as ON-TIME', () {
      final teachDate = DateTime(2026, 9, 1);
      final submitDate = DateTime(2026, 9, 1, 14, 30); // Same day, afternoon

      final journal = JournalModel(
        id: 'j-1',
        scheduleId: 's-1',
        date: teachDate,
        teachingHour: 1,
        classId: 'c-1',
        subjectId: 'sub-1',
        teacherId: teacher1.id,
        material: 'Aljabar',
        status: 'verified',
        createdAt: submitDate,
      );

      final teachDay = DateTime(journal.date.year, journal.date.month, journal.date.day);
      final submitDay = DateTime(journal.createdAt!.year, journal.createdAt!.month, journal.createdAt!.day);
      final diff = submitDay.difference(teachDay).inDays;

      expect(diff <= 0, isTrue); // On time
    });

    test('Journal submitted 3 days after teaching session is classified as LATE by 3 days', () {
      final teachDate = DateTime(2026, 9, 1);
      final submitDate = DateTime(2026, 9, 4, 10, 0); // 3 days later

      final journal = JournalModel(
        id: 'j-2',
        scheduleId: 's-2',
        date: teachDate,
        teachingHour: 1,
        classId: 'c-1',
        subjectId: 'sub-1',
        teacherId: teacher2.id,
        material: 'Reading Comprehension',
        status: 'pending',
        createdAt: submitDate,
      );

      final teachDay = DateTime(journal.date.year, journal.date.month, journal.date.day);
      final submitDay = DateTime(journal.createdAt!.year, journal.createdAt!.month, journal.createdAt!.day);
      final diff = submitDay.difference(teachDay).inDays;

      expect(diff > 0, isTrue); // Late
      expect(diff, equals(3));
    });

    test('Accurately ranks teacher with 100% on-time ahead of teacher with late submissions', () {
      // Teacher 1: 5 journals on time, 0 late
      final t1Journals = List.generate(
        5,
        (i) => JournalModel(
          id: 'j1-$i',
          scheduleId: 's1-$i',
          date: DateTime(2026, 9, 1 + i),
          teachingHour: 1,
          classId: 'c-1',
          subjectId: 'sub-1',
          teacherId: teacher1.id,
          material: 'Materi $i',
          status: 'verified',
          createdAt: DateTime(2026, 9, 1 + i, 12, 0), // same day
        ),
      );

      // Teacher 2: 2 journals on time, 3 journals late
      final t2Journals = [
        JournalModel(
          id: 'j2-1',
          scheduleId: 's2-1',
          date: DateTime(2026, 9, 1),
          teachingHour: 1,
          classId: 'c-1',
          subjectId: 'sub-2',
          teacherId: teacher2.id,
          material: 'Materi 1',
          status: 'verified',
          createdAt: DateTime(2026, 9, 1, 12, 0), // on time
        ),
        JournalModel(
          id: 'j2-2',
          scheduleId: 's2-2',
          date: DateTime(2026, 9, 2),
          teachingHour: 1,
          classId: 'c-1',
          subjectId: 'sub-2',
          teacherId: teacher2.id,
          material: 'Materi 2',
          status: 'verified',
          createdAt: DateTime(2026, 9, 2, 12, 0), // on time
        ),
        JournalModel(
          id: 'j2-3',
          scheduleId: 's2-3',
          date: DateTime(2026, 9, 3),
          teachingHour: 1,
          classId: 'c-1',
          subjectId: 'sub-2',
          teacherId: teacher2.id,
          material: 'Materi 3',
          status: 'verified',
          createdAt: DateTime(2026, 9, 8, 12, 0), // 5 days late
        ),
        JournalModel(
          id: 'j2-4',
          scheduleId: 's2-4',
          date: DateTime(2026, 9, 4),
          teachingHour: 1,
          classId: 'c-1',
          subjectId: 'sub-2',
          teacherId: teacher2.id,
          material: 'Materi 4',
          status: 'verified',
          createdAt: DateTime(2026, 9, 10, 12, 0), // 6 days late
        ),
        JournalModel(
          id: 'j2-5',
          scheduleId: 's2-5',
          date: DateTime(2026, 9, 5),
          teachingHour: 1,
          classId: 'c-1',
          subjectId: 'sub-2',
          teacherId: teacher2.id,
          material: 'Materi 5',
          status: 'verified',
          createdAt: DateTime(2026, 9, 9, 12, 0), // 4 days late
        ),
      ];

      // Calculate on-time rate for T1
      int t1OnTime = 0;
      for (final j in t1Journals) {
        final d = DateTime(j.createdAt!.year, j.createdAt!.month, j.createdAt!.day)
            .difference(DateTime(j.date.year, j.date.month, j.date.day))
            .inDays;
        if (d <= 0) t1OnTime++;
      }
      final double t1Rate = (t1OnTime / t1Journals.length) * 100.0;

      // Calculate on-time rate for T2
      int t2OnTime = 0;
      int t2Late = 0;
      int t2LateDays = 0;
      for (final j in t2Journals) {
        final d = DateTime(j.createdAt!.year, j.createdAt!.month, j.createdAt!.day)
            .difference(DateTime(j.date.year, j.date.month, j.date.day))
            .inDays;
        if (d <= 0) {
          t2OnTime++;
        } else {
          t2Late++;
          t2LateDays += d;
        }
      }
      final double t2Rate = (t2OnTime / t2Journals.length) * 100.0;
      final double t2AvgLate = t2LateDays / t2Late;

      expect(t1Rate, equals(100.0));
      expect(t2Rate, equals(40.0));
      expect(t2Late, equals(3));
      expect(t2AvgLate, equals(5.0)); // (5 + 6 + 4) / 3 = 5.0
      expect(t1Rate > t2Rate, isTrue);
    });
  });
}
