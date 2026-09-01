import '../models/teacher_model.dart';

abstract class TeacherRepository {
  Future<List<TeacherModel>> getAll();
  Future<List<TeacherModel>> getAllForSchool(String schoolId);
  Future<void> create(TeacherModel model);
  Future<void> update(TeacherModel model);
  Future<void> delete(String id);
  Future<void> deleteMultiple(List<String> ids);
}
