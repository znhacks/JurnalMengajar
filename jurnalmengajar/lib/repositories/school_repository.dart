import '../models/school_model.dart';

abstract class SchoolRepository {
  Future<List<SchoolModel>> getAll();
}
