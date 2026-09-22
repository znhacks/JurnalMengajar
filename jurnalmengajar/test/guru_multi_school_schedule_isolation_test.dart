import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';

class MockMultiSchoolScheduleRepository implements ScheduleRepository {
  final List<ScheduleModel> allSchedules;

  MockMultiSchoolScheduleRepository(this.allSchedules);

  @override
  Future<List<ScheduleModel>> getAll([String? schoolId]) async {
    if (schoolId == null || schoolId.isEmpty) return allSchedules;
    return allSchedules.where((s) => s.schoolId == schoolId).toList();
  }

  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, {DateTime? date}) async {
    return allSchedules.where((s) => s.teacherId == teacherId).toList();
  }

  @override
  Future<void> create(ScheduleModel model) async {}

  @override
  Future<void> update(ScheduleModel model) async {}

  @override
  Future<void> delete(String id) async {}


  @override
  Future<void> createMultiple(List<ScheduleModel> models) async {}

  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class MockMultiSchoolJournalRepository implements JournalRepository {
  final List<JournalModel> allJournals;

  MockMultiSchoolJournalRepository(this.allJournals);

  @override
  Future<List<JournalModel>> getAll([String? schoolId]) async {
    if (schoolId == null || schoolId.isEmpty) return allJournals;
    return allJournals.where((j) => j.schoolId == schoolId).toList();
  }

  @override
  Future<List<JournalModel>> getJournalsForTeacher(String teacherId) async {
    return allJournals.where((j) => j.teacherId == teacherId).toList();
  }

  @override
  Future<void> create(JournalModel model) async {}

  @override
  Future<void> update(JournalModel model) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteMultiple(List<String> ids) async {}

  @override
  Future<void> verifyJournal(String journalId, String status, {String? rejectionNote}) async {}


  @override
  Future<JournalModel?> getJournalForSchedule(String scheduleId, {DateTime? date}) async => null;


}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const String school11 = '00000000-0000-0000-0000-000000000001'; // SMKN 11 Malang
  const String school4 = 'd01a867e-3b3c-4a37-9bde-bbb0995b2d24'; // SMKN 4 Malang
  const String teacherId = 'teacher-123';
  final testDate = DateTime(2026, 9, 21);

  final mockSchedules = [
    // SMKN 11 schedules
    ScheduleModel(
      id: 's-11-1',
      periodId: 'p1',
      teacherId: teacherId,
      classId: 'c-11-1',
      subjectId: 'sub-11-1',
      date: testDate,
      teachingHour: 1,
      isActive: true,
      schoolId: school11,
    ),
    ScheduleModel(
      id: 's-11-2',
      periodId: 'p1',
      teacherId: teacherId,
      classId: 'c-11-1',
      subjectId: 'sub-11-1',
      date: testDate,
      teachingHour: 2,
      isActive: true,
      schoolId: school11,
    ),
  ];

  final mockJournals = [
    // SMKN 11 journal
    JournalModel(
      id: 'j-11-1',
      scheduleId: 's-11-1',
      teacherId: teacherId,
      classId: 'c-11-1',
      subjectId: 'sub-11-1',
      date: testDate,
      teachingHour: 1,
      material: 'Materi SMK 11',
      status: 'pending',
      schoolId: school11,
    ),
  ];

  group('Multi-School Teacher Schedule Isolation', () {
    test('When active school is SMKN 4 (no schedules), SMKN 11 schedules must NOT appear', () async {
      final scheduleRepo = MockMultiSchoolScheduleRepository(mockSchedules);
      final scheduleProvider = ScheduleProvider(scheduleRepository: scheduleRepo);

      // Load schedules in context of SMKN 4 Malang
      scheduleProvider.setSchoolId(school4);
      await scheduleProvider.loadTeacherSchedules(teacherId, testDate);

      // In SMKN 4, teacher has no schedules
      expect(scheduleProvider.cachedTeacherSchedules.isEmpty, isTrue,
          reason: 'SMKN 4 should have 0 cached schedules');
      expect(scheduleProvider.teacherSchedulesForSelectedDate.isEmpty, isTrue,
          reason: 'SMKN 4 should have 0 schedules for selected date');
    });

    test('When active school switches to SMKN 11, SMKN 11 schedules appear correctly', () async {
      final scheduleRepo = MockMultiSchoolScheduleRepository(mockSchedules);
      final scheduleProvider = ScheduleProvider(scheduleRepository: scheduleRepo);

      // Load in SMKN 4 first
      scheduleProvider.setSchoolId(school4);
      await scheduleProvider.loadTeacherSchedules(teacherId, testDate);
      expect(scheduleProvider.cachedTeacherSchedules.isEmpty, isTrue);

      // Now switch to SMKN 11
      scheduleProvider.setSchoolId(school11);
      await scheduleProvider.loadTeacherSchedules(teacherId, testDate);
      expect(scheduleProvider.cachedTeacherSchedules.length, equals(2));
      expect(scheduleProvider.teacherSchedulesForSelectedDate.length, equals(2));
      expect(
        scheduleProvider.cachedTeacherSchedules.every((s) => s.schoolId == school11),
        isTrue,
      );
    });
  });

  group('Multi-School Teacher Journal Isolation', () {
    test('When active school is SMKN 4 (no journals), SMKN 11 journals must NOT appear', () async {
      final journalRepo = MockMultiSchoolJournalRepository(mockJournals);
      final journalProvider = JournalProvider(journalRepository: journalRepo);

      // Load journals in context of SMKN 4 Malang
      journalProvider.setSchoolId(school4);
      await journalProvider.loadTeacherJournals(teacherId);

      // In SMKN 4, teacher has no journals
      expect(journalProvider.teacherJournals.isEmpty, isTrue,
          reason: 'SMKN 4 should have 0 journals');
    });

    test('When active school switches to SMKN 11, SMKN 11 journals appear correctly', () async {
      final journalRepo = MockMultiSchoolJournalRepository(mockJournals);
      final journalProvider = JournalProvider(journalRepository: journalRepo);

      // Load in SMKN 4 first
      journalProvider.setSchoolId(school4);
      await journalProvider.loadTeacherJournals(teacherId);
      expect(journalProvider.teacherJournals.isEmpty, isTrue);

      // Now switch to SMKN 11
      journalProvider.setSchoolId(school11);
      await journalProvider.loadTeacherJournals(teacherId);
      expect(journalProvider.teacherJournals.length, equals(1));
      expect(journalProvider.teacherJournals.first.schoolId, equals(school11));
    });
  });

  group('Multi-School Teacher Warning Letter Isolation', () {
    final mockWarnings = [
      WarningLetterModel(
        id: 'w-11-1',
        teacherId: teacherId,
        scheduleId: 's-11-1',
        issuedAt: testDate,
        reason: 'Terlambat mengisi jurnal mengajar pada tanggal 21 Sep 2026 untuk kelas: X RPL 1 (Mapel: Pemrograman, Jam ke-1).',
        status: 'unread',
        schoolId: school11,
      ),
    ];

    test('When active school is SMKN 4 (no warnings), SMKN 11 warning letters must NOT appear', () async {
      final warningRepo = MockMultiSchoolWarningLetterRepository(mockWarnings);
      final warningProvider = WarningLetterProvider(warningLetterRepository: warningRepo);

      await warningProvider.loadTeacherWarningLetters(teacherId, school4);

      expect(warningProvider.warningLetters.isEmpty, isTrue,
          reason: 'SMKN 4 should have 0 warning letters');
    });

    test('When active school switches to SMKN 11, SMKN 11 warnings appear correctly', () async {
      final warningRepo = MockMultiSchoolWarningLetterRepository(mockWarnings);
      final warningProvider = WarningLetterProvider(warningLetterRepository: warningRepo);

      // Load in SMKN 4 first
      await warningProvider.loadTeacherWarningLetters(teacherId, school4);
      expect(warningProvider.warningLetters.isEmpty, isTrue);

      // Switch to SMKN 11
      await warningProvider.loadTeacherWarningLetters(teacherId, school11);
      expect(warningProvider.warningLetters.length, equals(1));
      expect(warningProvider.warningLetters.first.schoolId, equals(school11));
    });
  });
}

class MockMultiSchoolWarningLetterRepository implements WarningLetterRepository {
  final List<WarningLetterModel> allWarnings;

  MockMultiSchoolWarningLetterRepository(this.allWarnings);

  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async {
    if (schoolId == null || schoolId.isEmpty) return allWarnings;
    return allWarnings.where((w) => w.schoolId == schoolId).toList();
  }

  @override
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId, [String? schoolId]) async {
    return allWarnings.where((w) {
      if (w.teacherId != teacherId) return false;
      if (schoolId != null && schoolId.isNotEmpty) {
        return w.schoolId == schoolId;
      }
      return true;
    }).toList();
  }

  @override
  Future<void> create(WarningLetterModel model) async {
    allWarnings.add(model);
  }

  @override
  Future<void> update(WarningLetterModel model) async {}

  @override
  Future<void> delete(String id) async {
    allWarnings.removeWhere((w) => w.id == id);
  }

  @override
  Future<void> markAsRead(String id) async {}
}
