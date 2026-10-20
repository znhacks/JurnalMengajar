import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/student_academic_history_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SchoolScopedTeacherRepo
    implements TeacherRepository, SchoolScopedTeacherRepository {
  String? deactivatedId;
  String? deactivatedSchoolId;
  bool legacyDeleteCalled = false;
  String? reloadedSchoolId;

  @override
  Future<List<TeacherModel>> getAll() async => [];

  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async {
    reloadedSchoolId = schoolId;
    return [];
  }

  @override
  Future<void> create(TeacherModel model) async {}

  @override
  Future<void> update(TeacherModel model) async {}

  @override
  Future<void> delete(String id) async {
    legacyDeleteCalled = true;
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    legacyDeleteCalled = true;
  }

  @override
  Future<void> deactivate(String id, String schoolId) async {
    deactivatedId = id;
    deactivatedSchoolId = schoolId;
  }

  @override
  Future<void> deactivateMultiple(List<String> ids, String schoolId) async {
    deactivatedId = ids.join(',');
    deactivatedSchoolId = schoolId;
  }
}

class _LegacyTeacherRepo implements TeacherRepository {
  bool deleteCalled = false;

  @override
  Future<List<TeacherModel>> getAll() async => [];

  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async => [];

  @override
  Future<void> create(TeacherModel model) async {}

  @override
  Future<void> update(TeacherModel model) async {}

  @override
  Future<void> delete(String id) async {
    deleteCalled = true;
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    deleteCalled = true;
  }
}

class _EmptyPeriodRepo implements PeriodRepository {
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(PeriodModel model) async {}
  @override
  Future<void> update(PeriodModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _EmptySubjectRepo implements SubjectRepository {
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(SubjectModel model) async {}
  @override
  Future<void> update(SubjectModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _EmptyHourRepo implements HourRepository {
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(HourModel model) async {}
  @override
  Future<void> update(HourModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _EmptyClassRepo implements ClassRepository {
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(ClassModel model) async {}
  @override
  Future<void> update(ClassModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class _EmptyStudentRepo implements StudentRepository {
  @override
  Future<List<StudentModel>> getAllByClass(String classId) async => [];
  @override
  Future<void> create(StudentModel model) async {}
  @override
  Future<void> update(StudentModel model) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
  @override
  Future<List<StudentAcademicHistoryModel>> getStudentHistories(
    String studentId,
  ) async => [];
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

MasterDataProvider _buildProvider(TeacherRepository teacherRepository) {
  return MasterDataProvider(
    periodRepository: _EmptyPeriodRepo(),
    subjectRepository: _EmptySubjectRepo(),
    hourRepository: _EmptyHourRepo(),
    classRepository: _EmptyClassRepo(),
    teacherRepository: teacherRepository,
    studentRepository: _EmptyStudentRepo(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('teacher deactivation is scoped to the active school', () async {
    final teacherRepo = _SchoolScopedTeacherRepo();
    final provider = _buildProvider(teacherRepo);

    await provider.loadAllData('school-A');
    final success = await provider.deleteTeacher('teacher-1');

    expect(success, isTrue);
    expect(teacherRepo.deactivatedId, 'teacher-1');
    expect(teacherRepo.deactivatedSchoolId, 'school-A');
    expect(teacherRepo.legacyDeleteCalled, isFalse);
    expect(teacherRepo.reloadedSchoolId, 'school-A');
  });

  test('bulk teacher deactivation uses the active school', () async {
    final teacherRepo = _SchoolScopedTeacherRepo();
    final provider = _buildProvider(teacherRepo);

    await provider.loadAllData('school-B');
    final success = await provider.deleteMultipleTeachers([
      'teacher-1',
      'teacher-2',
    ]);

    expect(success, isTrue);
    expect(teacherRepo.deactivatedId, 'teacher-1,teacher-2');
    expect(teacherRepo.deactivatedSchoolId, 'school-B');
    expect(teacherRepo.legacyDeleteCalled, isFalse);
  });

  test('legacy repositories still work through the fallback', () async {
    final teacherRepo = _LegacyTeacherRepo();
    final provider = _buildProvider(teacherRepo);

    await provider.loadAllData('school-C');
    final success = await provider.deleteTeacher('teacher-1');

    expect(success, isTrue);
    expect(teacherRepo.deleteCalled, isTrue);
  });

  test('deactivation without an active school is rejected', () async {
    final teacherRepo = _SchoolScopedTeacherRepo();
    final provider = _buildProvider(teacherRepo);

    final success = await provider.deleteTeacher('teacher-1');

    expect(success, isFalse);
    expect(provider.errorMessage, contains('Sekolah aktif'));
    expect(teacherRepo.deactivatedId, isNull);
    expect(teacherRepo.legacyDeleteCalled, isFalse);
  });
}
