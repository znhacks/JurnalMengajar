import '../hour_repository.dart';
import '../../models/hour_model.dart';
import 'mock_database.dart';

class MockHourRepository implements HourRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<List<HourModel>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final sortedList = List<HourModel>.from(_db.hours);
    sortedList.sort((a, b) => a.teachingHour.compareTo(b.teachingHour));
    return sortedList;
  }

  @override
  Future<void> create(HourModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 'h_${DateTime.now().millisecondsSinceEpoch}';
    _db.hours.add(model.copyWith(id: id));
  }

  @override
  Future<void> update(HourModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.hours.indexWhere((h) => h.id == model.id);
    if (index != -1) {
      _db.hours[index] = model;
    } else {
      throw Exception('Jam pelajaran tidak ditemukan!');
    }
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.hours.removeWhere((h) => h.id == id);
  }
}
