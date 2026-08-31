import '../models/school_model.dart';

abstract class SchoolRepository {
  Future<List<SchoolModel>> getAll();
  Future<SchoolModel?> validateActivationCode(String code);
  Future<bool> updateSchoolPlan(String schoolId, String plan, String activationCode);
}
