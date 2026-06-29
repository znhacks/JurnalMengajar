import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_model.dart';
import 'schedule_repository.dart';
import '../core/constants/supabase_constants.dart';

const _uuid = Uuid();

class SupabaseScheduleRepository implements ScheduleRepository {
  final SupabaseClient _supabase;

  SupabaseScheduleRepository(this._supabase);

  @override
  Future<List<ScheduleModel>> getAll() async {
    try {
      final response = await _supabase
          .from(SupabaseConstants.tableSchedules)
          .select()
          .order(SupabaseConstants.fieldDate, ascending: true);

      return (response as List)
          .map((json) => ScheduleModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat jadwal mengajar: $e');
    }
  }

  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final nextDateStr = '${date.add(Duration(days: 1)).year}-${date.add(Duration(days: 1)).month.toString().padLeft(2, '0')}-${date.add(Duration(days: 1)).day.toString().padLeft(2, '0')}';
      
      final response = await _supabase
          .from(SupabaseConstants.tableSchedules)
          .select()
          .eq(SupabaseConstants.fieldTeacherId, teacherId)
          .gte(SupabaseConstants.fieldDate, dateStr)
          .lt(SupabaseConstants.fieldDate, nextDateStr)
          .order(SupabaseConstants.fieldDate, ascending: true);

      return (response as List)
          .map((json) => ScheduleModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat jadwal guru: $e');
    }
  }

  @override
  Future<void> create(ScheduleModel model) async {
    try {
      final payload = model.toJson();
      // Generate a UUID client-side if id is empty
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      await _supabase
          .from(SupabaseConstants.tableSchedules)
          .insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah jadwal: $e');
    }
  }

  @override
  Future<void> createMultiple(List<ScheduleModel> models) async {
    try {
      final payloads = models.map((model) {
        final payload = model.toJson();
        if ((payload['id'] as String?)?.isEmpty ?? true) {
          payload['id'] = _uuid.v4();
        }
        return payload;
      }).toList();
      await _supabase
          .from(SupabaseConstants.tableSchedules)
          .insert(payloads);
    } catch (e) {
      throw Exception('Gagal menambah beberapa jadwal: $e');
    }
  }

  @override
  Future<void> update(ScheduleModel model) async {
    try {
      await _supabase
          .from(SupabaseConstants.tableSchedules)
          .update(model.toJson())
          .eq(SupabaseConstants.fieldId, model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui jadwal: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase
          .from(SupabaseConstants.tableSchedules)
          .delete()
          .eq(SupabaseConstants.fieldId, id);
    } catch (e) {
      throw Exception('Gagal menghapus jadwal: $e');
    }
  }
}
