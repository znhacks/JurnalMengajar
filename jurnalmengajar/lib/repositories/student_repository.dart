import '../models/student_model.dart';

abstract class StudentRepository {
  Future<List<StudentModel>> getAllByClass(String classId);
  Future<void> create(StudentModel model);
  Future<void> update(StudentModel model);
  Future<void> delete(String id);
}
