import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/core/services/cache_service.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/school_model.dart';
import 'package:jurnalmengajar/models/journal_model.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/providers/journal_provider.dart';
import 'package:jurnalmengajar/providers/teacher_leave_provider.dart';
import 'package:jurnalmengajar/providers/holiday_provider.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:jurnalmengajar/repositories/school_repository.dart';
import 'package:jurnalmengajar/repositories/journal_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';

class MockPeriodRepo implements PeriodRepository {
  List<PeriodModel> list = [];
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async =>
      list.where((p) => schoolId == null || p.schoolId == schoolId).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSubjectRepo implements SubjectRepository {
  List<SubjectModel> list = [];
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async =>
      list.where((s) => schoolId == null || s.schoolId == schoolId).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHourRepo implements HourRepository {
  List<HourModel> list = [];
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async =>
      list.where((h) => schoolId == null || h.schoolId == schoolId).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockClassRepo implements ClassRepository {
  List<ClassModel> list = [];
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async =>
      list.where((c) => schoolId == null || c.schoolId == schoolId).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTeacherRepo implements TeacherRepository {
  List<TeacherModel> list = [];
  @override
  Future<List<TeacherModel>> getAll() async => [];
  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async => list;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSchoolRepo implements SchoolRepository {
  List<SchoolModel> list = [];
  int getAllCount = 0;
  @override
  Future<List<SchoolModel>> getAll() async {
    getAllCount++;
    return list;
  }
  @override
  Future<SchoolModel?> getById(String id) async =>
      list.where((s) => s.id == id).firstOrNull;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockJournalRepo implements JournalRepository {
  List<JournalModel> list = [];
  @override
  Future<List<JournalModel>> getAll([String? schoolId]) async =>
      list.where((j) => schoolId == null || j.schoolId == schoolId).toList();
  @override
  Future<List<JournalModel>> getJournalsForTeacher(String teacherId) async =>
      list.where((j) => j.teacherId == teacherId).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStudentRepo implements StudentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheService().init();
  });

  group('Weak Signal & Tenant Isolation Tests', () {
    const schoolA = 'school-aaa-111';
    const schoolB = 'school-bbb-222';

    test('MasterDataProvider: loads instantly from cache and maintains strict tenant isolation', () async {
      // 1. Pre-seed cache for school A
      await CacheService().save('classes_$schoolA', [
        {'id': 'c1', 'name': 'Kelas X-A', 'school_id': schoolA},
      ]);
      await CacheService().save('subjects_$schoolA', [
        {'id': 's1', 'name': 'Matematika', 'school_id': schoolA, 'is_active': true},
      ]);
      await CacheService().save('teachers_$schoolA', [
        {'id': 't1', 'name': 'Guru A', 'position': 'Guru', 'school_id': schoolA, 'email': 'guru@a.com', 'address': '', 'phone_number': ''},
      ]);

      final mockPeriod = MockPeriodRepo();
      final mockSubject = MockSubjectRepo()
        ..list = [
          SubjectModel(id: 's1', name: 'Matematika', schoolId: schoolA, isActive: true),
        ];
      final mockHour = MockHourRepo();
      final mockClass = MockClassRepo()
        ..list = [
          ClassModel(id: 'c1', name: 'Kelas X-A', periodId: 'p1', studentCount: 30, schoolId: schoolA),
        ];
      final mockTeacher = MockTeacherRepo()
        ..list = [
          TeacherModel(id: 't1', name: 'Guru A', position: 'Guru', email: 'guru@a.com', address: '', phoneNumber: ''),
        ];
      final mockSchool = MockSchoolRepo()
        ..list = [
          SchoolModel(id: schoolA, name: 'Sekolah A', plan: 'pro'),
          SchoolModel(id: schoolB, name: 'Sekolah B (Foreign)', plan: 'ultra'),
        ];
      final mockStudent = MockStudentRepo();

      final provider = MasterDataProvider(
        periodRepository: mockPeriod,
        subjectRepository: mockSubject,
        hourRepository: mockHour,
        classRepository: mockClass,
        teacherRepository: mockTeacher,
        studentRepository: mockStudent,
        schoolRepository: mockSchool,
      );

      // Load school A data
      await provider.loadAllData(schoolA);

      // Verify that data loaded belongs STRICTLY to school A
      expect(provider.isLoading, isFalse);
      expect(provider.classes.length, 1);
      expect(provider.classes.first.schoolId, schoolA);
      expect(provider.subjects.length, 1);
      expect(provider.teachers.length, 1);

      // Verify schoolRepository.getAll() was NOT called in loadAllData to prevent downloading all foreign schools
      expect(mockSchool.getAllCount, 0);

      // Verify that school state only holds school A, never school B
      expect(provider.schools.length, 1);
      expect(provider.schools.first.id, schoolA);
      expect(provider.schools.first.name, 'Sekolah A');
    });

    test('JournalProvider: strictly isolates journals between school A and school B', () async {
      final mockRepo = MockJournalRepo()
        ..list = [
          JournalModel(
            id: 'j-1',
            scheduleId: 'sc-1',
            teacherId: 't-1',
            classId: 'c-1',
            subjectId: 's-1',
            material: 'Materi A',
            status: 'verified',
            date: DateTime.now(),
            teachingHour: 1,
            schoolId: schoolA,
          ),
          JournalModel(
            id: 'j-2',
            scheduleId: 'sc-2',
            teacherId: 't-1',
            classId: 'c-2',
            subjectId: 's-2',
            material: 'Materi B',
            status: 'verified',
            date: DateTime.now(),
            teachingHour: 2,
            schoolId: schoolB,
          ),
        ];

      final provider = JournalProvider(journalRepository: mockRepo);
      provider.setSchoolId(schoolA);
      await provider.loadTeacherJournals('t-1');

      // Only journals for schoolA should be in provider
      expect(provider.teacherJournals.length, 1);
      expect(provider.teacherJournals.first.id, 'j-1');
      expect(provider.teacherJournals.first.schoolId, schoolA);

      // Switch to school B
      provider.setSchoolId(schoolB);
      await provider.loadTeacherJournals('t-1');

      expect(provider.teacherJournals.length, 1);
      expect(provider.teacherJournals.first.id, 'j-2');
      expect(provider.teacherJournals.first.schoolId, schoolB);
    });

    test('TeacherLeaveProvider: null or empty schoolId returns empty list without calling schools.limit(1)', () async {
      final provider = TeacherLeaveProvider();
      await provider.loadLeaves(null);

      expect(provider.leaves, isEmpty);
      expect(provider.isLoading, isFalse);

      await provider.loadLeaves('');
      expect(provider.leaves, isEmpty);
      expect(provider.isLoading, isFalse);
    });

    test('HolidayProvider: null or empty schoolId returns empty list without calling schools.limit(1)', () async {
      final provider = HolidayProvider();
      await provider.loadHolidays(null);

      expect(provider.holidays, isEmpty);
      expect(provider.isLoading, isFalse);

      await provider.loadHolidays('');
      expect(provider.holidays, isEmpty);
      expect(provider.isLoading, isFalse);
    });
  });
}
