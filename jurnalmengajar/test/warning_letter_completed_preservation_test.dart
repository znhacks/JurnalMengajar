import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/utils/helper.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/student_academic_history_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';

class MockWarningLetterRepository implements WarningLetterRepository {
  List<WarningLetterModel> database = [];

  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async {
    if (schoolId != null && schoolId.isNotEmpty) {
      return database.where((w) => w.schoolId == schoolId).toList();
    }
    return List.from(database);
  }

  @override
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId, [String? schoolId]) async {
    var list = database.where((w) => w.teacherId == teacherId);
    if (schoolId != null && schoolId.isNotEmpty) {
      list = list.where((w) => w.schoolId == schoolId);
    }
    return list.toList();
  }

  @override
  Future<void> create(WarningLetterModel model) async {
    database.add(model.copyWith(id: 'gen-${database.length + 1}'));
  }

  @override
  Future<void> delete(String id) async {
    database.removeWhere((w) => w.id == id);
  }

  @override
  Future<void> markAsRead(String id) async {
    final idx = database.indexWhere((w) => w.id == id);
    if (idx != -1) {
      database[idx] = database[idx].copyWith(status: 'read');
    }
  }

  @override
  Future<void> update(WarningLetterModel model) async {
    final idx = database.indexWhere((w) => w.id == model.id);
    if (idx != -1) {
      database[idx] = model;
    }
  }
}

class FakeClassRepo implements ClassRepository {
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async => [
        ClassModel(id: 'c1', name: 'X RPL 1', periodId: 'p1', studentCount: 30, schoolId: schoolId),
      ];
  @override
  Future<void> create(ClassModel c) async {}
  @override
  Future<void> update(ClassModel c) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeSubjectRepo implements SubjectRepository {
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async => [
        SubjectModel(id: 'sub1', name: 'Matematika', isActive: true, schoolId: schoolId),
      ];
  @override
  Future<void> create(SubjectModel s) async {}
  @override
  Future<void> update(SubjectModel s) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakePeriodRepo implements PeriodRepository {
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async => [
        PeriodModel(id: 'p1', name: '2026/2027 Ganjil', isActive: true, schoolId: schoolId ?? 'school-1'),
      ];
  @override
  Future<void> create(PeriodModel p) async {}
  @override
  Future<void> update(PeriodModel p) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeHourRepo implements HourRepository {
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(HourModel h) async {}
  @override
  Future<void> update(HourModel h) async {}
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
  Future<void> create(TeacherModel t) async {}
  @override
  Future<void> update(TeacherModel t) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeStudentRepo implements StudentRepository {
  @override
  Future<List<StudentModel>> getAllByClass(String classId) async => [];
  @override
  Future<void> create(StudentModel s) async {}
  @override
  Future<void> update(StudentModel s) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
  @override
  Future<List<StudentAcademicHistoryModel>> getStudentHistories(String studentId) async => [];
  @override
  Future<Map<String, dynamic>> processPromotions({
    required String schoolId,
    required String sourcePeriodId,
    required String sourceClassId,
    String? targetPeriodId,
    String? targetClassId,
    required List<Map<String, dynamic>> items,
    DateTime? transferDate,
  }) async => {'success': true};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Warning Letter Completed History Preservation Tests', () {
    const schoolId = 'school-1';
    const teacherId = 'teacher-1';

    late MockWarningLetterRepository mockRepo;
    late WarningLetterProvider warningProvider;
    late MasterDataProvider masterProvider;

    setUp(() async {
      mockRepo = MockWarningLetterRepository();
      warningProvider = WarningLetterProvider(warningLetterRepository: mockRepo);
      masterProvider = MasterDataProvider(
        classRepository: FakeClassRepo(),
        subjectRepository: FakeSubjectRepo(),
        periodRepository: FakePeriodRepo(),
        hourRepository: FakeHourRepo(),
        teacherRepository: FakeTeacherRepo(),
        studentRepository: FakeStudentRepo(),
      );

      // Populate master data without cache dependency
      await masterProvider.loadAllData(schoolId);
    });

    test('checkAndIssueWarnings does NOT delete confirmed (read) warning letter when journals are filled', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 7));
      final dateStr = AppHelper.formatDateShort(pastDate);

      // Existing warning that has been confirmed by teacher
      mockRepo.database = [
        WarningLetterModel(
          id: 'sp-confirmed-1',
          teacherId: teacherId,
          scheduleId: 'sched-1',
          issuedAt: DateTime.now().subtract(const Duration(days: 2)),
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal $dateStr untuk kelas: X RPL 1 (Mapel: Matematika, Jam ke-1 - 2).',
          status: 'read', // Confirmed / Selesai
          schoolId: schoolId,
        ),
      ];

      final schedule = ScheduleModel(
        id: 'sched-1',
        teacherId: teacherId,
        classId: 'c1',
        subjectId: 'sub1',
        periodId: 'p1',
        date: pastDate,
        teachingHour: 1,
        schoolId: schoolId,
        isActive: true,
      );

      // Teacher has already filled journal for this schedule
      final journal = JournalModel(
        id: 'j-1',
        scheduleId: 'sched-1',
        teacherId: teacherId,
        classId: 'c1',
        subjectId: 'sub1',
        date: pastDate,
        material: 'Aljabar',
        teachingHour: 1,
        status: 'approved',
        schoolId: schoolId,
      );

      // Relog/dashboard check runs
      await warningProvider.checkAndIssueWarnings(
        schedules: [schedule],
        journals: [journal],
        maxDays: 3,
        masterProvider: masterProvider,
      );

      // Warning letter MUST NOT be deleted
      expect(mockRepo.database.length, equals(1));
      expect(mockRepo.database.first.id, equals('sp-confirmed-1'));
      expect(mockRepo.database.first.status, equals('read'));
    });

    test('checkAndIssueWarnings does NOT delete unread warning letter even after journal is filled (preserves pending confirmation)', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 7));
      final dateStr = AppHelper.formatDateShort(pastDate);

      // Existing unread warning
      mockRepo.database = [
        WarningLetterModel(
          id: 'sp-unread-1',
          teacherId: teacherId,
          scheduleId: 'sched-1',
          issuedAt: DateTime.now().subtract(const Duration(days: 2)),
          reason: 'Terlambat mengisi jurnal mengajar pada tanggal $dateStr untuk kelas: X RPL 1 (Mapel: Matematika, Jam ke-1 - 2).',
          status: 'unread',
          schoolId: schoolId,
        ),
      ];

      final schedule = ScheduleModel(
        id: 'sched-1',
        teacherId: teacherId,
        classId: 'c1',
        subjectId: 'sub1',
        periodId: 'p1',
        date: pastDate,
        teachingHour: 1,
        schoolId: schoolId,
        isActive: true,
      );

      // Journal was just filled by teacher
      final journal = JournalModel(
        id: 'j-1',
        scheduleId: 'sched-1',
        teacherId: teacherId,
        classId: 'c1',
        subjectId: 'sub1',
        date: pastDate,
        material: 'Aljabar',
        teachingHour: 1,
        status: 'pending',
        schoolId: schoolId,
      );

      await warningProvider.checkAndIssueWarnings(
        schedules: [schedule],
        journals: [journal],
        maxDays: 3,
        masterProvider: masterProvider,
      );

      // Warning MUST remain in database so teacher can confirm it
      expect(mockRepo.database.length, equals(1));
      expect(mockRepo.database.first.id, equals('sp-unread-1'));
      expect(mockRepo.database.first.status, equals('unread'));
    });
  });
}
