import '../models/schedule_model.dart';

abstract class ScheduleRepository {
  Future<List<ScheduleModel>> getAll();
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, DateTime date);
  Future<void> create(ScheduleModel model);
  Future<void> update(ScheduleModel model);
  Future<void> delete(String id);
}
