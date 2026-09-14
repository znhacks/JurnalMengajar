import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/models/teacher_model.dart';
import 'package:jurnalmengajar/models/class_model.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';
import 'package:jurnalmengajar/core/utils/schedule_grouper.dart';

class InMemoryScheduleRepository implements ScheduleRepository {
  final List<ScheduleModel> _storage = [];

  @override
  Future<List<ScheduleModel>> getAll([String? schoolId]) async {
    if (schoolId != null && schoolId.isNotEmpty) {
      return _storage.where((s) => s.schoolId == schoolId).toList();
    }
    return List.from(_storage);
  }

  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, {DateTime? date}) async {
    return _storage.where((s) {
      final sameTeacher = s.teacherId == teacherId;
      if (date == null) return sameTeacher;
      return sameTeacher &&
          s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day;
    }).toList();
  }

  @override
  Future<void> create(ScheduleModel model) async {
    final id = model.id.isEmpty ? 'id_${_storage.length + 1}' : model.id;
    _storage.add(model.copyWith(id: id));
  }

  @override
  Future<void> createMultiple(List<ScheduleModel> models) async {
    for (int i = 0; i < models.length; i++) {
      final id = models[i].id.isEmpty ? 'id_${_storage.length + 1}' : models[i].id;
      _storage.add(models[i].copyWith(id: id));
    }
  }

  @override
  Future<void> update(ScheduleModel model) async {
    final idx = _storage.indexWhere((s) => s.id == model.id);
    if (idx != -1) {
      _storage[idx] = model;
    } else {
      throw Exception('Schedule not found');
    }
  }

  @override
  Future<void> delete(String id) async {
    _storage.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    _storage.removeWhere((s) => ids.contains(s.id));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Schedule Conflict Validation by Teacher & Class', () {
    late InMemoryScheduleRepository repository;
    late ScheduleProvider provider;

    final teacherA = TeacherModel(
      id: 'teacher-a-id',
      name: 'Kartika Mekar Kusumaningrum, S.Kom., Gr.',
      position: 'Guru RPL',
      address: 'Malang',
      phoneNumber: '08123456789',
      email: 'kartika@school.id',
    );

    final teacherB = TeacherModel(
      id: 'teacher-b-id',
      name: 'Heru Sudjatmiko, S.Pd.',
      position: 'Guru Matematika',
      address: 'Malang',
      phoneNumber: '08987654321',
      email: 'heru@school.id',
    );

    final class1 = ClassModel(
      id: 'class-1-id',
      name: 'XI RPL 1',
      periodId: 'period-1',
      studentCount: 30,
    );

    final class2 = ClassModel(
      id: 'class-2-id',
      name: 'XI RPL 2',
      periodId: 'period-1',
      studentCount: 32,
    );

    final teachers = [teacherA, teacherB];
    final classes = [class1, class2];

    const schoolA = '00000000-0000-0000-0000-000000000001'; // SMKN 11
    const schoolB = 'd01a867e-3b3c-4a37-9bde-bbb0995b2d24'; // SMKN 4

    setUp(() {
      repository = InMemoryScheduleRepository();
      provider = ScheduleProvider(scheduleRepository: repository);
    });

    test('TEST 1: Guru Berbeda, Jam Sama, Kelas Berbeda -> Berhasil Keduanya', () async {
      await provider.loadAllSchedules(schoolA);

      final date = DateTime(2026, 9, 14); // Senin

      // Jadwal Guru A: Senin, Jam 1, Kelas XI RPL 1
      final scheduleA = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      final createdA = await provider.createSchedule(scheduleA, teachers, classes);
      expect(createdA, isTrue);
      expect(provider.schedules.length, 1);

      // Jadwal Guru B: Senin, Jam 1, Kelas XI RPL 2
      final scheduleB = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class2.id,
        subjectId: 'sub-2',
        teacherId: teacherB.id,
        isActive: true,
        schoolId: schoolA,
      );
      final createdB = await provider.createSchedule(scheduleB, teachers, classes);
      expect(createdB, isTrue);
      expect(provider.schedules.length, 2);
    });

    test('TEST 2: Guru Sama, Jam Sama (di hari yang sama) -> TOLAK (Bentrok Guru)', () async {
      await provider.loadAllSchedules(schoolA);
      final date = DateTime(2026, 9, 14); // Senin

      // Jadwal Guru A: Senin, Jam 1, Kelas XI RPL 1
      final scheduleA1 = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      final ok1 = await provider.createSchedule(scheduleA1, teachers, classes);
      expect(ok1, isTrue);

      // Jadwal Guru A LAGI: Senin, Jam 1, Kelas XI RPL 2
      final scheduleA2 = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class2.id,
        subjectId: 'sub-2',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      final ok2 = await provider.createSchedule(scheduleA2, teachers, classes);
      expect(ok2, isFalse);
      expect(provider.errorMessage, contains('Kartika Mekar Kusumaningrum'));
      expect(provider.errorMessage, contains('Sudah memiliki jadwal'));
      expect(provider.errorMessage, contains('Jam ke-1'));
    });

    test('TEST 3: Guru Sama, Jam Berbeda (di hari yang sama) -> BOLEH', () async {
      await provider.loadAllSchedules(schoolA);
      final date = DateTime(2026, 9, 14); // Senin

      // Guru A: Senin, Jam 1
      final s1 = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      expect(await provider.createSchedule(s1, teachers, classes), isTrue);

      // Guru A: Senin, Jam 2
      final s2 = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: date,
        teachingHour: 2,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      expect(await provider.createSchedule(s2, teachers, classes), isTrue);
      expect(provider.schedules.length, 2);
    });

    test('TEST 4: Guru Sama, Hari Berbeda, Jam Sama -> BOLEH', () async {
      await provider.loadAllSchedules(schoolA);
      final dateMonday = DateTime(2026, 9, 14); // Senin
      final dateTuesday = DateTime(2026, 9, 15); // Selasa

      final sMonday = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: dateMonday,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      expect(await provider.createSchedule(sMonday, teachers, classes), isTrue);

      final sTuesday = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: dateTuesday,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      expect(await provider.createSchedule(sTuesday, teachers, classes), isTrue);
      expect(provider.schedules.length, 2);
    });

    test('TEST 5: Edit Jadwal Guru A tanpa ubah waktu -> Tidak bentrok dengan diri sendiri', () async {
      await provider.loadAllSchedules(schoolA);
      final date = DateTime(2026, 9, 14);

      final s = ScheduleModel(
        id: 's-original-1',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      await provider.createSchedule(s, teachers, classes);

      // Edit note / subject on the same schedule
      final updated = s.copyWith(note: 'Updated Catatan Baru');
      final ok = await provider.updateSchedule(updated, teachers, classes);
      expect(ok, isTrue);
    });

    test('TEST 6: Edit Jadwal ke Guru Berbeda pada jam yang sama di kelas berbeda -> BOLEH', () async {
      await provider.loadAllSchedules(schoolA);
      final date = DateTime(2026, 9, 14);

      // Guru A has Jam 1 in class 1
      final sA = ScheduleModel(
        id: 'sched-1',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      await provider.createSchedule(sA, teachers, classes);

      // Edit sched-1 to teacherB
      final updatedToB = sA.copyWith(teacherId: teacherB.id);
      final ok = await provider.updateSchedule(updatedToB, teachers, classes);
      expect(ok, isTrue);
    });

    test('TEST 7: Multi-Tenant: Guru Sama di Jam Sama tapi Sekolah Berbeda -> Tidak Bentrok', () async {
      final date = DateTime(2026, 9, 14);

      // Guru A in School A
      await provider.loadAllSchedules(schoolA);
      final sSchoolA = ScheduleModel(
        id: 's-smkn11',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      expect(await provider.createSchedule(sSchoolA, teachers, classes), isTrue);

      // Switch context to School B
      await provider.loadAllSchedules(schoolB);
      final sSchoolB = ScheduleModel(
        id: 's-smkn4',
        periodId: 'period-2',
        date: date,
        teachingHour: 1,
        classId: 'class-smkn4',
        subjectId: 'sub-2',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolB,
      );
      expect(await provider.createSchedule(sSchoolB, teachers, classes), isTrue);
      expect(provider.schedules.length, 1);
      expect(provider.schedules.first.schoolId, schoolB);
    });

    test('TEST 8: KELAS: Satu Kelas Tidak Boleh Memiliki Dua Guru Pada Jam Sama', () async {
      await provider.loadAllSchedules(schoolA);
      final date = DateTime(2026, 9, 14);

      // Guru A in Class 1 at Jam 1
      final sA = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-1',
        teacherId: teacherA.id,
        isActive: true,
        schoolId: schoolA,
      );
      expect(await provider.createSchedule(sA, teachers, classes), isTrue);

      // Guru B tries to teach the SAME Class 1 at Jam 1
      final sB = ScheduleModel(
        id: '',
        periodId: 'period-1',
        date: date,
        teachingHour: 1,
        classId: class1.id,
        subjectId: 'sub-2',
        teacherId: teacherB.id,
        isActive: true,
        schoolId: schoolA,
      );
      final ok = await provider.createSchedule(sB, teachers, classes);
      expect(ok, isFalse);
      expect(provider.errorMessage, contains('Kelas XI RPL 1'));
      expect(provider.errorMessage, contains('sudah memiliki jadwal'));
    });

    test('TEST 9: REFRESH: Setelah Jadwal Guru Berbeda Dibuat, Refresh Menyimpan Keduanya', () async {
      await provider.loadAllSchedules(schoolA);
      final date = DateTime(2026, 9, 14);

      // Create Guru A Jam 1 Class 1
      await provider.createSchedule(
        ScheduleModel(
          id: 's-1',
          periodId: 'period-1',
          date: date,
          teachingHour: 1,
          classId: class1.id,
          subjectId: 'sub-1',
          teacherId: teacherA.id,
          isActive: true,
          schoolId: schoolA,
        ),
        teachers,
        classes,
      );

      // Create Guru B Jam 1 Class 2
      await provider.createSchedule(
        ScheduleModel(
          id: 's-2',
          periodId: 'period-1',
          date: date,
          teachingHour: 1,
          classId: class2.id,
          subjectId: 'sub-2',
          teacherId: teacherB.id,
          isActive: true,
          schoolId: schoolA,
        ),
        teachers,
        classes,
      );

      // Refresh
      await provider.loadAllSchedules(schoolA);
      expect(provider.schedules.length, 2);
      expect(provider.schedules.any((s) => s.teacherId == teacherA.id && s.teachingHour == 1), isTrue);
      expect(provider.schedules.any((s) => s.teacherId == teacherB.id && s.teachingHour == 1), isTrue);
    });

    test('TEST 10: GROUPING: Menampilkan Guru A dan Guru B pada Jam Sama Tanpa Saling Menggantikan', () {
      final date = DateTime(2026, 9, 14);
      final allSchedules = [
        ScheduleModel(
          id: 's-1',
          periodId: 'period-1',
          date: date,
          teachingHour: 1,
          classId: class1.id,
          subjectId: 'sub-1',
          teacherId: teacherA.id,
          isActive: true,
          schoolId: schoolA,
        ),
        ScheduleModel(
          id: 's-2',
          periodId: 'period-1',
          date: date,
          teachingHour: 1,
          classId: class2.id,
          subjectId: 'sub-2',
          teacherId: teacherB.id,
          isActive: true,
          schoolId: schoolA,
        ),
      ];

      final grouped = groupMasterSchedules(allSchedules);
      expect(grouped.length, 2);

      final groupA = grouped.firstWhere((g) => g.teacherId == teacherA.id);
      final groupB = grouped.firstWhere((g) => g.teacherId == teacherB.id);

      expect(groupA.teachingHours, contains(1));
      expect(groupA.classId, class1.id);

      expect(groupB.teachingHours, contains(1));
      expect(groupB.classId, class2.id);
    });
  });
}
