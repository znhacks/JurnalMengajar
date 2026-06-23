import '../class_repository.dart';
import '../../models/class_model.dart';
import 'mock_database.dart';

class MockClassRepository implements ClassRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<List<ClassModel>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_db.classes);
  }

  @override
  Future<void> create(ClassModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 'c_${DateTime.now().millisecondsSinceEpoch}';
    _db.classes.add(model.copyWith(id: id));
  }

  @override
  Future<void> update(ClassModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.classes.indexWhere((c) => c.id == model.id);
    if (index != -1) {
      _db.classes[index] = model;
    } else {
      throw Exception('Kelas tidak ditemukan!');
    }
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.classes.removeWhere((c) => c.id == id);
  }
}
