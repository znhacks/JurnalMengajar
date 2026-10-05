import '../models/class_model.dart';
import '../models/journal_model.dart';
import '../models/student_model.dart';

/// Holds parsed absence student names from a journal note
class JournalAbsenceInfo {
  final List<String> sickStudentNames;
  final List<String> permissionStudentNames;
  final List<String> alphaStudentNames;

  JournalAbsenceInfo({
    required this.sickStudentNames,
    required this.permissionStudentNames,
    required this.alphaStudentNames,
  });

  /// Robust parser for absences stored in journal notes
  factory JournalAbsenceInfo.fromJournal(JournalModel journal) {
    final List<String> sick = [];
    final List<String> perm = [];
    final List<String> alpha = [];

    final note = journal.note ?? '';
    if (note.isNotEmpty) {
      final lines = note.split('\n');
      for (final rawLine in lines) {
        final line = rawLine.trim();
        final lower = line.toLowerCase();
        if (lower.startsWith('sakit')) {
          final colonIndex = line.indexOf(':');
          if (colonIndex != -1 && colonIndex < line.length - 1) {
            final namesPart = line.substring(colonIndex + 1).trim();
            if (namesPart.isNotEmpty) {
              sick.addAll(
                namesPart
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty),
              );
            }
          }
        } else if (lower.startsWith('izin')) {
          final colonIndex = line.indexOf(':');
          if (colonIndex != -1 && colonIndex < line.length - 1) {
            final namesPart = line.substring(colonIndex + 1).trim();
            if (namesPart.isNotEmpty) {
              perm.addAll(
                namesPart
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty),
              );
            }
          }
        } else if (lower.startsWith('alfa') || lower.startsWith('alpa')) {
          final colonIndex = line.indexOf(':');
          if (colonIndex != -1 && colonIndex < line.length - 1) {
            final namesPart = line.substring(colonIndex + 1).trim();
            if (namesPart.isNotEmpty) {
              alpha.addAll(
                namesPart
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty),
              );
            }
          }
        }
      }
    }

    return JournalAbsenceInfo(
      sickStudentNames: sick,
      permissionStudentNames: perm,
      alphaStudentNames: alpha,
    );
  }
}

/// A specific absence event record for a student
class StudentAbsenceRecord {
  final DateTime date;
  final String subjectName;
  final String teacherName;
  final int teachingHour;
  final String status; // 'Sakit', 'Izin', 'Alfa'
  final String journalId;

  StudentAbsenceRecord({
    required this.date,
    required this.subjectName,
    required this.teacherName,
    required this.teachingHour,
    required this.status,
    required this.journalId,
  });
}

/// Aggregated attendance summary for an individual student in a class
class StudentAttendanceSummary {
  final StudentModel student;
  int presentCount;
  int sickCount;
  int permissionCount;
  int alphaCount;
  final List<StudentAbsenceRecord> records;

  StudentAttendanceSummary({
    required this.student,
    this.presentCount = 0,
    this.sickCount = 0,
    this.permissionCount = 0,
    this.alphaCount = 0,
    List<StudentAbsenceRecord>? records,
  }) : records = records ?? [];

  int get totalMeetings => presentCount + sickCount + permissionCount + alphaCount;

  double get attendancePercentage =>
      totalMeetings > 0 ? (presentCount / totalMeetings) * 100.0 : 100.0;

  String get performanceLabel {
    final rate = attendancePercentage;
    if (rate >= 95.0) return 'Sangat Baik';
    if (rate >= 85.0) return 'Baik';
    if (rate >= 75.0) return 'Cukup';
    return 'Perlu Perhatian';
  }
}

/// Aggregated attendance summary for a whole class
class ClassAttendanceSummary {
  final ClassModel classModel;
  final int totalStudents;
  final int totalMeetings;
  final int totalPresent;
  final int totalSick;
  final int totalPermission;
  final int totalAlpha;
  final int totalPossibleAttendances;

  ClassAttendanceSummary({
    required this.classModel,
    required this.totalStudents,
    required this.totalMeetings,
    required this.totalPresent,
    required this.totalSick,
    required this.totalPermission,
    required this.totalAlpha,
    required this.totalPossibleAttendances,
  });

  double get attendanceRate =>
      totalPossibleAttendances > 0
          ? (totalPresent / totalPossibleAttendances) * 100.0
          : 100.0;

  String get performanceLabel {
    final rate = attendanceRate;
    if (rate >= 95.0) return 'Sangat Baik';
    if (rate >= 85.0) return 'Baik';
    if (rate >= 75.0) return 'Cukup';
    return 'Perlu Perhatian';
  }
}
