import '../models/period_model.dart';

abstract class PeriodRepository {
  Future<List<PeriodModel>> getAll();
  Future<void> create(PeriodModel model);
  Future<void> update(PeriodModel model);
  Future<void> delete(String id);
}
