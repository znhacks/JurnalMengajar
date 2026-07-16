import '../models/warning_letter_model.dart';

abstract class WarningLetterRepository {
  Future<List<WarningLetterModel>> getAll();
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId);
  Future<void> create(WarningLetterModel model);
  Future<void> markAsRead(String id);
  Future<void> update(WarningLetterModel model);
  Future<void> delete(String id);
}
