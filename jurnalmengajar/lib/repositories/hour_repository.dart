import '../models/hour_model.dart';

abstract class HourRepository {
  Future<List<HourModel>> getAll();
  Future<void> create(HourModel model);
  Future<void> update(HourModel model);
  Future<void> delete(String id);
}
