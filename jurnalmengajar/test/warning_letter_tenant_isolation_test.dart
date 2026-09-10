import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/models/warning_letter_model.dart';
import 'package:jurnalmengajar/providers/warning_letter_provider.dart';
import 'package:jurnalmengajar/repositories/warning_letter_repository.dart';

class MockWarningLetterRepository implements WarningLetterRepository {
  List<WarningLetterModel> database = [];
  int delayMs = 0;

  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (schoolId != null && schoolId.isNotEmpty) {
      return database.where((w) => w.schoolId == schoolId).toList();
    }
    return List.from(database);
  }

  @override
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId, [String? schoolId]) async {
    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    var list = database.where((w) => w.teacherId == teacherId);
    if (schoolId != null && schoolId.isNotEmpty) {
      list = list.where((w) => w.schoolId == schoolId);
    }
    return list.toList();
  }

  @override
  Future<void> create(WarningLetterModel model) async {
    database.add(model);
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

void main() {
  group('Warning Letter Multi-Tenant Isolation Tests', () {
    const smkn4Id = 'd01a867e-3b3c-4a37-9bde-bbb0995b2d24';
    const smkn11Id = '00000000-0000-0000-0000-000000000001';
    const teacherId = 'teacher-123';

    late MockWarningLetterRepository mockRepo;
    late WarningLetterProvider provider;

    setUp(() {
      mockRepo = MockWarningLetterRepository();
      mockRepo.database = [
        WarningLetterModel(
          id: 'sp-smkn4-1',
          teacherId: teacherId,
          scheduleId: 'sched-4-1',
          issuedAt: DateTime(2026, 8, 1),
          reason: 'Terlambat SMKN 4',
          status: 'unread',
          schoolId: smkn4Id,
        ),
        WarningLetterModel(
          id: 'sp-smkn11-1',
          teacherId: teacherId,
          scheduleId: 'sched-11-1',
          issuedAt: DateTime(2026, 8, 2),
          reason: 'Terlambat SMKN 11',
          status: 'unread',
          schoolId: smkn11Id,
        ),
        WarningLetterModel(
          id: 'sp-smkn11-2',
          teacherId: teacherId,
          scheduleId: 'sched-11-2',
          issuedAt: DateTime(2026, 8, 3),
          reason: 'Terlambat SMKN 11 Kelas X',
          status: 'read',
          schoolId: smkn11Id,
        ),
      ];
      provider = WarningLetterProvider(warningLetterRepository: mockRepo);
    });

    test('WarningLetterModel correctly parses and serializes schoolId', () {
      final json = {
        'id': 'sp-1',
        'teacher_id': 't-1',
        'schedule_id': 's-1',
        'issued_at': '2026-08-01T10:00:00Z',
        'reason': 'Test',
        'status': 'unread',
        'school_id': smkn4Id,
      };

      final model = WarningLetterModel.fromJson(json);
      expect(model.schoolId, equals(smkn4Id));
      expect(model.toJson()['school_id'], equals(smkn4Id));
    });

    test('loadTeacherWarningLetters in SMKN 4 Malang ONLY returns SMKN 4 warnings (SMKN 11 excluded)', () async {
      await provider.loadTeacherWarningLetters(teacherId, smkn4Id);

      expect(provider.warningLetters.length, equals(1));
      expect(provider.warningLetters.first.id, equals('sp-smkn4-1'));
      expect(provider.warningLetters.first.schoolId, equals(smkn4Id));
      expect(provider.warningLetters.any((w) => w.schoolId == smkn11Id), isFalse);
    });

    test('loadTeacherWarningLetters in SMKN 11 Malang ONLY returns SMKN 11 warnings (SMKN 4 excluded)', () async {
      await provider.loadTeacherWarningLetters(teacherId, smkn11Id);

      expect(provider.warningLetters.length, equals(2));
      expect(provider.warningLetters.every((w) => w.schoolId == smkn11Id), isTrue);
      expect(provider.warningLetters.any((w) => w.schoolId == smkn4Id), isFalse);
    });

    test('clearCache immediately wipes warning letters and resets school state on school switch', () async {
      await provider.loadTeacherWarningLetters(teacherId, smkn11Id);
      expect(provider.warningLetters.isNotEmpty, isTrue);

      provider.clearCache();

      expect(provider.warningLetters.isEmpty, isTrue);
      expect(provider.currentSchoolId, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('Race condition guard: slow request for School A is discarded when switching to School B', () async {
      mockRepo.delayMs = 50;

      // Start slow request for SMKN 11
      final futureA = provider.loadTeacherWarningLetters(teacherId, smkn11Id);

      // User switches to SMKN 4 immediately
      provider.clearCache();
      mockRepo.delayMs = 0;
      final futureB = provider.loadTeacherWarningLetters(teacherId, smkn4Id);

      await Future.wait([futureA, futureB]);

      // State MUST be SMKN 4, stale SMKN 11 response must NOT overwrite
      expect(provider.currentSchoolId, equals(smkn4Id));
      expect(provider.warningLetters.length, equals(1));
      expect(provider.warningLetters.first.schoolId, equals(smkn4Id));
    });

    test('Admin loadAllWarningLetters strictly filters by active school', () async {
      await provider.loadAllWarningLetters(smkn4Id);
      expect(provider.warningLetters.length, equals(1));
      expect(provider.warningLetters.first.schoolId, equals(smkn4Id));

      await provider.loadAllWarningLetters(smkn11Id);
      expect(provider.warningLetters.length, equals(2));
      expect(provider.warningLetters.every((w) => w.schoolId == smkn11Id), isTrue);
    });
  });
}
