import '../models/subject_model.dart';

abstract class SubjectRepository {
  Future<List<SubjectModel>> getAll([String? schoolId]);
  Future<void> create(SubjectModel model);
  Future<void> update(SubjectModel model);
  Future<void> delete(String id);
  Future<void> deleteMultiple(List<String> ids);
}
