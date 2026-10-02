import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnalmengajar/models/schedule_model.dart';
import 'package:jurnalmengajar/providers/schedule_provider.dart';
import 'package:jurnalmengajar/repositories/schedule_repository.dart';

class MockFastScheduleRepository implements ScheduleRepository {
  List<ScheduleModel> schedules;
  int getAllCalls = 0;
  int getSchedulesForTeacherCalls = 0;
  int deleteCalls = 0;
  int deleteMultipleCalls = 0;

  MockFastScheduleRepository(this.schedules);

  @override
  Future<List<ScheduleModel>> getAll([String? schoolId]) async {
    getAllCalls++;
    if (schoolId == null || schoolId.isEmpty) return List.from(schedules);
    return schedules.where((s) => s.schoolId == schoolId).toList();
  }

  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, {DateTime? date}) async {
    getSchedulesForTeacherCalls++;
    return schedules.where((s) {
      if (s.teacherId != teacherId) return false;
      if (date != null) {
        return s.date.year == date.year &&
            s.date.month == date.month &&
            s.date.day == date.day;
      }
      return true;
    }).toList();
  }

  @override
  Future<void> create(ScheduleModel model) async {
    schedules.add(model);
  }

  @override
  Future<void> createMultiple(List<ScheduleModel> models) async {
    schedules.addAll(models);
  }

  @override
  Future<void> update(ScheduleModel model) async {
    final idx = schedules.indexWhere((s) => s.id == model.id);
    if (idx != -1) schedules[idx] = model;
  }

  @override
  Future<void> delete(String id) async {
    deleteCalls++;
    schedules.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    deleteMultipleCalls++;
    schedules.removeWhere((s) => ids.contains(s.id));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const schoolA = 'school-alpha-uuid';
  const schoolB = 'school-beta-uuid';
  const teacherId = 'teacher-101';
  final date1 = DateTime(2027, 2, 10);
  final date2 = DateTime(2027, 2, 11);

  final initialSchedules = [
    ScheduleModel(
      id: 'sc-1',
      periodId: 'p1',
      teacherId: teacherId,
      classId: 'c1',
      subjectId: 's1',
      date: date1,
      teachingHour: 1,
      isActive: true,
      schoolId: schoolA,
    ),
    ScheduleModel(
      id: 'sc-2',
      periodId: 'p1',
      teacherId: teacherId,
      classId: 'c1',
      subjectId: 's1',
      date: date1,
      teachingHour: 2,
      isActive: true,
      schoolId: schoolA,
    ),
    ScheduleModel(
      id: 'sc-3',
      periodId: 'p1',
      teacherId: teacherId,
      classId: 'c2',
      subjectId: 's2',
      date: date2,
      teachingHour: 1,
      isActive: true,
      schoolId: schoolA,
    ),
    // Belongs to School B (must NEVER bleed into School A)
    ScheduleModel(
      id: 'sc-b-1',
      periodId: 'p1',
      teacherId: teacherId,
      classId: 'c-b-1',
      subjectId: 's-b-1',
      date: date1,
      teachingHour: 1,
      isActive: true,
      schoolId: schoolB,
    ),
  ];

  test('loadAllSchedules loads once and does NOT re-trigger network or spinner on subsequent opens', () async {
    final repo = MockFastScheduleRepository(List.from(initialSchedules));
    final provider = ScheduleProvider(scheduleRepository: repo);

    // First load
    await provider.loadAllSchedules(schoolA);
    expect(repo.getAllCalls, equals(1));
    expect(provider.schedules.length, equals(3));
    expect(provider.isAllSchedulesLoaded, isTrue);
    expect(provider.isLoading, isFalse);

    // Opening screen again: subsequent call to loadAllSchedules with same school
    await provider.loadAllSchedules(schoolA);
    expect(repo.getAllCalls, equals(1), reason: 'Must NOT make redundant network call');
    expect(provider.isLoading, isFalse);

    // Force refresh still allows refreshing
    await provider.refreshAllSchedules(schoolA);
    expect(repo.getAllCalls, equals(2));
  });

  test('Strict tenant isolation: School B data NEVER leaks into School A', () async {
    final repo = MockFastScheduleRepository(List.from(initialSchedules));
    final provider = ScheduleProvider(scheduleRepository: repo);

    await provider.loadAllSchedules(schoolA);
    expect(provider.schedules.every((s) => s.schoolId == schoolA), isTrue);
    expect(provider.schedules.any((s) => s.schoolId == schoolB), isFalse);

    // Switch to School B
    provider.setSchoolId(schoolB);
    expect(provider.schedules.isEmpty, isTrue, reason: 'Old school state must be purged immediately');

    await provider.loadAllSchedules(schoolB);
    expect(provider.schedules.length, equals(1));
    expect(provider.schedules.every((s) => s.schoolId == schoolB), isTrue);
  });

  test('Fast and optimistic single delete: removes instantly without reloading all schedules', () async {
    final repo = MockFastScheduleRepository(List.from(initialSchedules));
    final provider = ScheduleProvider(scheduleRepository: repo);

    await provider.loadAllSchedules(schoolA);
    await provider.loadTeacherSchedules(teacherId, date1);

    expect(provider.schedules.length, equals(3));
    expect(provider.teacherSchedulesForSelectedDate.length, equals(2));

    final callsBefore = repo.getAllCalls;
    final success = await provider.deleteSchedule('sc-1');

    expect(success, isTrue);
    expect(provider.schedules.any((s) => s.id == 'sc-1'), isFalse);
    expect(provider.teacherSchedulesForSelectedDate.any((s) => s.id == 'sc-1'), isFalse);
    expect(provider.cachedTeacherSchedules.any((s) => s.id == 'sc-1'), isFalse);
    expect(repo.deleteCalls, equals(1));
    expect(repo.getAllCalls, equals(callsBefore), reason: 'Delete should NOT trigger a slow reloadAllSchedules');
  });

  test('Fast and optimistic multiple delete: removes all selected items instantly', () async {
    final repo = MockFastScheduleRepository(List.from(initialSchedules));
    final provider = ScheduleProvider(scheduleRepository: repo);

    await provider.loadAllSchedules(schoolA);
    await provider.loadTeacherSchedules(teacherId, date1);

    final callsBefore = repo.getAllCalls;
    final success = await provider.deleteMultipleSchedules(['sc-1', 'sc-2']);

    expect(success, isTrue);
    expect(provider.schedules.length, equals(1)); // only sc-3 remains
    expect(provider.schedules.first.id, equals('sc-3'));
    expect(provider.teacherSchedulesForSelectedDate.isEmpty, isTrue);
    expect(repo.deleteMultipleCalls, equals(1));
    expect(repo.getAllCalls, equals(callsBefore));
  });

  test('Changing date on calendar updates teacherSchedulesForSelectedDate instantly in 0ms', () async {
    final repo = MockFastScheduleRepository(List.from(initialSchedules));
    final provider = ScheduleProvider(scheduleRepository: repo);

    await provider.loadAllSchedules(schoolA);
    await provider.loadTeacherSchedules(teacherId, date1);

    expect(provider.teacherSchedulesForSelectedDate.length, equals(2));

    // Change to date 2
    final teacherCallsBefore = repo.getSchedulesForTeacherCalls;
    await provider.loadTeacherSchedules(teacherId, date2);

    expect(provider.teacherSchedulesForSelectedDate.length, equals(1));
    expect(provider.teacherSchedulesForSelectedDate.first.id, equals('sc-3'));
    expect(repo.getSchedulesForTeacherCalls, equals(teacherCallsBefore), reason: 'Zero network calls when date changes');
  });
}
