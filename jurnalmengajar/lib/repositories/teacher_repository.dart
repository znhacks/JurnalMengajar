import '../models/teacher_model.dart';

abstract class TeacherRepository {
  Future<List<TeacherModel>> getAll();
  Future<List<TeacherModel>> getAllForSchool(String schoolId);
  Future<void> create(TeacherModel model);
  Future<void> update(TeacherModel model);
  Future<void> delete(String id);
  Future<void> deleteMultiple(List<String> ids);
}

/// Optional capability for repositories that support deactivating a teacher
/// only in one school while keeping the account and historical data intact.
abstract class SchoolScopedTeacherRepository {
  Future<void> deactivate(String id, String schoolId);
  Future<void> deactivateMultiple(List<String> ids, String schoolId);
}
