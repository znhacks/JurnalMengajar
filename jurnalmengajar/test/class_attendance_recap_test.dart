import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/models/class_attendance_recap_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';

void main() {
  group('JournalAbsenceInfo Parser Tests', () {
    test('Parses absent student names accurately from structured journal notes', () {
      final journal = JournalModel(
        id: 'j1',
        scheduleId: 's1',
        date: DateTime(2026, 10, 5),
        teachingHour: 1,
        classId: 'c1',
        subjectId: 'sub1',
        teacherId: 't1',
        material: 'Matematika Dasar',
        status: 'approved',
        sickCount: 3,
        permissionCount: 1,
        alphaCount: 1,
        note:
            'Keterangan Absensi:\n'
            'Sakit (3 siswa): Aditya Pratama, Ahmad Fauzi, Candra Kirana\n'
            'Izin (1 siswa): Bella Safira\n'
            'Alfa (1 siswa): Budi Santoso\n\n'
            'Catatan Pembelajaran:\nMateri selesai sampai latihan 4.',
      );

      final absence = JournalAbsenceInfo.fromJournal(journal);

      expect(absence.sickStudentNames, equals(['Aditya Pratama', 'Ahmad Fauzi', 'Candra Kirana']));
      expect(absence.permissionStudentNames, equals(['Bella Safira']));
      expect(absence.alphaStudentNames, equals(['Budi Santoso']));
    });

    test('Parses without errors when note is empty or without absences', () {
      final journal = JournalModel(
        id: 'j2',
        scheduleId: 's1',
        date: DateTime(2026, 10, 5),
        teachingHour: 1,
        classId: 'c1',
        subjectId: 'sub1',
        teacherId: 't1',
        material: 'Materi Lengkap',
        status: 'approved',
        sickCount: 0,
        permissionCount: 0,
        alphaCount: 0,
        note: null,
      );

      final absence = JournalAbsenceInfo.fromJournal(journal);

      expect(absence.sickStudentNames, isEmpty);
      expect(absence.permissionStudentNames, isEmpty);
      expect(absence.alphaStudentNames, isEmpty);
    });
  });

  group('StudentAttendanceSummary & ClassAttendanceSummary Calculations', () {
    test('Calculates student attendance percentage correctly', () {
      final student = StudentModel(
        id: 'st1',
        name: 'Ahmad Fauzi',
        nis: '1001',
        gender: 'L',
        classId: 'c1',
      );

      final summary = StudentAttendanceSummary(
        student: student,
        presentCount: 18,
        sickCount: 1,
        permissionCount: 1,
        alphaCount: 0,
      );

      expect(summary.totalMeetings, equals(20));
      // 18 / 20 = 90.0%
      expect(summary.attendancePercentage, equals(90.0));
      expect(summary.performanceLabel, equals('Baik'));
    });

    test('Calculates 100% when student is never absent', () {
      final student = StudentModel(
        id: 'st2',
        name: 'Siti Aminah',
        nis: '1002',
        gender: 'P',
        classId: 'c1',
      );

      final summary = StudentAttendanceSummary(
        student: student,
        presentCount: 25,
        sickCount: 0,
        permissionCount: 0,
        alphaCount: 0,
      );

      expect(summary.totalMeetings, equals(25));
      expect(summary.attendancePercentage, equals(100.0));
      expect(summary.performanceLabel, equals('Sangat Baik'));
    });

    test('Calculates ClassAttendanceSummary metrics and rates correctly', () {
      final classModel = ClassModel(
        id: 'c1',
        name: 'X PPLG 1',
        periodId: 'p1',
        studentCount: 30,
      );

      // 10 meetings, 30 students = 300 possible student-sessions
      // Absences: 6 total (3 sick, 2 perm, 1 alpha) -> Present = 294
      final classSummary = ClassAttendanceSummary(
        classModel: classModel,
        totalStudents: 30,
        totalMeetings: 10,
        totalPossibleAttendances: 300,
        totalPresent: 294,
        totalSick: 3,
        totalPermission: 2,
        totalAlpha: 1,
      );

      // 294 / 300 * 100 = 98.0%
      expect(classSummary.attendanceRate, equals(98.0));
      expect(classSummary.performanceLabel, equals('Sangat Baik'));
    });
  });
}
