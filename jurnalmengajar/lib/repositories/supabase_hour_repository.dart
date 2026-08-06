import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/hour_model.dart';
import 'hour_repository.dart';

const _uuid = Uuid();

class SupabaseHourRepository implements HourRepository {
  final SupabaseClient _supabase;

  SupabaseHourRepository(this._supabase);

  @override
  Future<List<HourModel>> getAll([String? schoolId]) async {
    try {
      var query = _supabase.from('lesson_hours').select();
      if (schoolId != null && schoolId.isNotEmpty) {
        query = query.eq('school_id', schoolId);
      }
      final response = await query.order('teaching_hour', ascending: true);

      return (response as List)
          .map((json) => HourModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> create(HourModel model) async {
    try {
      final payload = model.toJson();
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('lesson_hours').insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah jam pelajaran: $e');
    }
  }

  @override
  Future<void> update(HourModel model) async {
    try {
      await _supabase
          .from('lesson_hours')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui jam pelajaran: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('lesson_hours').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus jam pelajaran: $e');
    }
  }
}
