import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/models/hour_model.dart';
import 'package:jurnalmengajar/models/period_model.dart';
import 'package:jurnalmengajar/models/school_model.dart';
import 'package:jurnalmengajar/models/student_academic_history_model.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/models/subject_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/providers/master_data_provider.dart';
import 'package:jurnalmengajar/repositories/class_repository.dart';
import 'package:jurnalmengajar/repositories/hour_repository.dart';
import 'package:jurnalmengajar/repositories/period_repository.dart';
import 'package:jurnalmengajar/repositories/school_repository.dart';
import 'package:jurnalmengajar/repositories/student_repository.dart';
import 'package:jurnalmengajar/repositories/subject_repository.dart';
import 'package:jurnalmengajar/repositories/teacher_repository.dart';

class InMemorySchoolConflictRepo implements SchoolRepository {
  final Map<String, SchoolModel> schools = {};
  final Map<String, List<String>> schoolMembers = {};

  InMemorySchoolConflictRepo() {
    // Active school (e.g., SMKN 11 Malang)
    schools['school-real'] = SchoolModel(
      id: 'school-real',
      name: 'SMKN 11 Malang',
      code: 'OLD-CODE',
      plan: 'free',
      status: 'active',
      maxTeachers: 30,
    );
    schoolMembers['school-real'] = ['user-admin-1', 'user-guru-1'];

    // Placeholder orphan voucher row created by external generator (no users, name empty)
    schools['placeholder-voucher'] = SchoolModel(
      id: 'placeholder-voucher',
      name: '',
      code: 'PRO-9999',
      plan: 'pro',
      status: 'active',
      maxTeachers: 50,
    );
    schoolMembers['placeholder-voucher'] = [];

    // Another school that legitimately has registered members
    schools['school-other'] = SchoolModel(
      id: 'school-other',
      name: 'SMKN 4 Malang',
      code: 'ENT-8888',
      plan: 'enterprise',
      status: 'active',
      maxTeachers: 999,
    );
    schoolMembers['school-other'] = ['user-admin-2'];
  }

  @override
  Future<List<SchoolModel>> getAll() async => schools.values.toList();

  @override
  Future<SchoolModel?> getById(String id) async => schools[id];

  @override
  Future<SchoolModel?> validateActivationCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    for (final s in schools.values) {
      if ((s.code?.toUpperCase() ?? '') == cleanCode && s.name.isNotEmpty) {
        return s;
      }
    }
    // If only found in empty placeholder, simulate fallback to tenant metadata
    for (final s in schools.values) {
      if ((s.code?.toUpperCase() ?? '') == cleanCode) {
        return SchoolModel(
          id: s.id,
          name: 'SMKN 11 Malang (from Tenant)',
          code: cleanCode,
          plan: 'pro',
          maxTeachers: 50,
        );
      }
    }
    return null;
  }

  @override
  Future<SchoolModel?> validateTeacherJoinCode(String code) async => null;

  @override
  Future<SchoolModel> activateSchoolWithCode({
    required String currentSchoolId,
    required String activationCode,
  }) async {
    final cleanCode = activationCode.trim().toUpperCase();
    final targetId = currentSchoolId;

    // Simulate conflict resolution as implemented in SupabaseSchoolRepository
    final conflictingKeys = schools.entries
        .where((e) =>
            (e.value.code?.toUpperCase() ?? '') == cleanCode &&
            e.key != targetId)
        .toList();

    for (final conflict in conflictingKeys) {
      final conflictId = conflict.key;
      final conflictMembers = schoolMembers[conflictId] ?? [];

      if (conflictMembers.isEmpty) {
        // Orphan placeholder: safely delete
        schools.remove(conflictId);
      } else {
        throw Exception(
          'Kode aktivasi "$cleanCode" sudah digunakan oleh sekolah lain (${conflict.value.name}).',
        );
      }
    }

    final existing = schools[targetId];
    final updated = SchoolModel(
      id: targetId,
      name: existing?.name ?? 'Sekolah',
      code: cleanCode,
      plan: cleanCode.contains('PRO') ? 'pro' : 'enterprise',
      status: 'active',
      maxTeachers: cleanCode.contains('PRO') ? 50 : 999,
    );
    schools[targetId] = updated;
    return updated;
  }

  @override
  Future<bool> updateSchoolPlan(
    String schoolId,
    String plan,
    String activationCode,
  ) async =>
      true;
}

class FakePeriodRepo implements PeriodRepository {
  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(PeriodModel period) async {}
  @override
  Future<void> update(PeriodModel period) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeSubjectRepo implements SubjectRepository {
  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(SubjectModel subject) async {}
  @override
  Future<void> update(SubjectModel subject) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeHourRepo implements HourRepository {
  @override
  Future<List<HourModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(HourModel hour) async {}
  @override
  Future<void> update(HourModel hour) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeClassRepo implements ClassRepository {
  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async => [];
  @override
  Future<void> create(ClassModel classModel) async {}
  @override
  Future<void> update(ClassModel classModel) async {}
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
  Future<void> create(TeacherModel teacher) async {}
  @override
  Future<void> update(TeacherModel teacher) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

class FakeStudentRepo implements StudentRepository {
  @override
  Future<List<StudentAcademicHistoryModel>> getStudentHistories(
    String studentId,
  ) async =>
      [];
  @override
  Future<Map<String, dynamic>> processPromotions({
    required String schoolId,
    required String sourcePeriodId,
    required String sourceClassId,
    String? targetPeriodId,
    String? targetClassId,
    required List<Map<String, dynamic>> items,
    DateTime? transferDate,
  }) async =>
      {'success': true};
  @override
  Future<List<StudentModel>> getAllByClass(String classId) async => [];
  @override
  Future<void> create(StudentModel student) async {}
  @override
  Future<void> update(StudentModel student) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> deleteMultiple(List<String> ids) async {}
}

void main() {
  group('School Activation Code Conflict & Unique Constraint Tests', () {
    late InMemorySchoolConflictRepo schoolRepo;
    late MasterDataProvider masterProvider;

    setUp(() {
      schoolRepo = InMemorySchoolConflictRepo();
      masterProvider = MasterDataProvider(
        periodRepository: FakePeriodRepo(),
        subjectRepository: FakeSubjectRepo(),
        hourRepository: FakeHourRepo(),
        classRepository: FakeClassRepo(),
        teacherRepository: FakeTeacherRepo(),
        studentRepository: FakeStudentRepo(),
        schoolRepository: schoolRepo,
      );
    });

    test('validateActivationCode prioritizes non-empty school name or tenant fallback', () async {
      final res = await masterProvider.validateActivationCode('PRO-9999');
      expect(res, isNotNull);
      expect(res!.name, isNotEmpty);
      expect(res.name, contains('SMKN 11 Malang'));
    });

    test('activateSchoolWithCode safely claims code when conflicting row is an orphan voucher placeholder', () async {
      // Before activation, placeholder-voucher holds PRO-9999
      expect(schoolRepo.schools.containsKey('placeholder-voucher'), isTrue);

      final updated = await masterProvider.activateSchoolWithCode(
        currentSchoolId: 'school-real',
        activationCode: 'PRO-9999',
      );

      // Successfully updated real school
      expect(updated.id, 'school-real');
      expect(updated.code, 'PRO-9999');
      expect(updated.plan, 'pro');
      expect(updated.maxTeachers, 50);

      // Orphan placeholder was cleaned up to release uniqueness constraint
      expect(schoolRepo.schools.containsKey('placeholder-voucher'), isFalse);
      expect(schoolRepo.schools['school-real']!.code, 'PRO-9999');
    });

    test('activateSchoolWithCode throws informative error when code is in use by another real school', () async {
      // ENT-8888 belongs to school-other which has registered members
      expect(
        () async => await masterProvider.activateSchoolWithCode(
          currentSchoolId: 'school-real',
          activationCode: 'ENT-8888',
        ),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('sudah digunakan oleh sekolah lain') &&
                e.toString().contains('SMKN 4 Malang'),
          ),
        ),
      );

      // school-other and school-real remain intact
      expect(schoolRepo.schools['school-other']!.code, 'ENT-8888');
      expect(schoolRepo.schools['school-real']!.code, 'OLD-CODE');
    });
  });
}
