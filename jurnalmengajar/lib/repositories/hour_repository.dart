import '../models/hour_model.dart';

abstract class HourRepository {
  Future<List<HourModel>> getAll([String? schoolId]);
  Future<void> create(HourModel model);
  Future<void> update(HourModel model);
  Future<void> delete(String id);
  Future<void> deleteMultiple(List<String> ids);
}
