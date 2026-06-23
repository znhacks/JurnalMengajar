import '../schedule_repository.dart';
import '../../models/schedule_model.dart';
import 'mock_database.dart';

class MockScheduleRepository implements ScheduleRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<List<ScheduleModel>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_db.schedules);
  }

  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _db.schedules.where((s) {
      final sameTeacher = s.teacherId == teacherId;
      final sameDate = s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day;
      return sameTeacher && sameDate;
    }).toList();
  }

  @override
  Future<void> create(ScheduleModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 'sc_${DateTime.now().millisecondsSinceEpoch}';
    _db.schedules.add(model.copyWith(id: id));
  }

  @override
  Future<void> update(ScheduleModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.schedules.indexWhere((s) => s.id == model.id);
    if (index != -1) {
      _db.schedules[index] = model;
    } else {
      throw Exception('Jadwal tidak ditemukan!');
    }
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.schedules.removeWhere((s) => s.id == id);
  }
}
