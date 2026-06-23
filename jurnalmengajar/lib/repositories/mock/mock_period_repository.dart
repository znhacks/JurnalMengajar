import '../period_repository.dart';
import '../../models/period_model.dart';
import 'mock_database.dart';

class MockPeriodRepository implements PeriodRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<List<PeriodModel>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_db.periods);
  }

  @override
  Future<void> create(PeriodModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 'p_${DateTime.now().millisecondsSinceEpoch}';
    final newModel = model.copyWith(id: id);
    
    // If the new period is active, deactivate others
    if (newModel.isActive) {
      for (int i = 0; i < _db.periods.length; i++) {
        _db.periods[i] = _db.periods[i].copyWith(isActive: false);
      }
    }
    
    _db.periods.add(newModel);
  }

  @override
  Future<void> update(PeriodModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.periods.indexWhere((p) => p.id == model.id);
    if (index != -1) {
      // If the updated period is active, deactivate others
      if (model.isActive) {
        for (int i = 0; i < _db.periods.length; i++) {
          if (_db.periods[i].id != model.id) {
            _db.periods[i] = _db.periods[i].copyWith(isActive: false);
          }
        }
      }
      _db.periods[index] = model;
    } else {
      throw Exception('Periode tidak ditemukan!');
    }
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.periods.removeWhere((p) => p.id == id);
  }
}
