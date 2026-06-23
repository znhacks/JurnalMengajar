import '../models/journal_model.dart';

abstract class JournalRepository {
  Future<List<JournalModel>> getAll();
  Future<List<JournalModel>> getJournalsForTeacher(String teacherId);
  Future<JournalModel?> getJournalForSchedule(String scheduleId);
  Future<void> create(JournalModel model);
  Future<void> update(JournalModel model);
  Future<void> delete(String id);
  Future<void> verifyJournal(String journalId, String status);
}
