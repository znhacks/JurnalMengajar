import '../subject_repository.dart';
import '../../models/subject_model.dart';
import 'mock_database.dart';

class MockSubjectRepository implements SubjectRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<List<SubjectModel>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_db.subjects);
  }

  @override
  Future<void> create(SubjectModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 's_${DateTime.now().millisecondsSinceEpoch}';
    _db.subjects.add(model.copyWith(id: id));
  }

  @override
  Future<void> update(SubjectModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.subjects.indexWhere((s) => s.id == model.id);
    if (index != -1) {
      _db.subjects[index] = model;
    } else {
      throw Exception('Mata pelajaran tidak ditemukan!');
    }
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.subjects.removeWhere((s) => s.id == id);
  }
}
