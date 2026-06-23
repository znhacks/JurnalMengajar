import '../models/class_model.dart';

abstract class ClassRepository {
  Future<List<ClassModel>> getAll();
  Future<void> create(ClassModel model);
  Future<void> update(ClassModel model);
  Future<void> delete(String id);
}
