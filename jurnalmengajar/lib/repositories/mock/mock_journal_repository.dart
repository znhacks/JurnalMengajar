import '../journal_repository.dart';
import '../../models/journal_model.dart';
import 'mock_database.dart';

class MockJournalRepository implements JournalRepository {
  final MockDatabase _db = MockDatabase();

  @override
  Future<List<JournalModel>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_db.journals);
  }

  @override
  Future<List<JournalModel>> getJournalsForTeacher(String teacherId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _db.journals.where((j) => j.teacherId == teacherId).toList();
  }

  @override
  Future<JournalModel?> getJournalForSchedule(String scheduleId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _db.journals.indexWhere((j) => j.scheduleId == scheduleId);
    if (index != -1) {
      return _db.journals[index];
    }
    return null;
  }

  @override
  Future<void> create(JournalModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final id = 'j_${DateTime.now().millisecondsSinceEpoch}';
    
    // Check if a journal already exists for this schedule
    final exists = _db.journals.any((j) => j.scheduleId == model.scheduleId);
    if (exists) {
      throw Exception('Jurnal untuk jadwal ini sudah dibuat!');
    }

    _db.journals.add(model.copyWith(id: id));
  }

  @override
  Future<void> update(JournalModel model) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.journals.indexWhere((j) => j.id == model.id);
    if (index != -1) {
      _db.journals[index] = model;
    } else {
      throw Exception('Jurnal tidak ditemukan!');
    }
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.journals.removeWhere((j) => j.id == id);
  }

  @override
  Future<void> verifyJournal(String journalId, String status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _db.journals.indexWhere((j) => j.id == journalId);
    if (index != -1) {
      _db.journals[index] = _db.journals[index].copyWith(status: status);
    } else {
      throw Exception('Jurnal tidak ditemukan!');
    }
  }
}
