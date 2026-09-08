import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/hour_model.dart';
import '../core/utils/helper.dart';
import 'hour_repository.dart';

const _uuid = Uuid();

class SupabaseHourRepository implements HourRepository {
  final SupabaseClient _supabase;

  SupabaseHourRepository(this._supabase);

  @override
  Future<List<HourModel>> getAll([String? schoolId]) async {
    try {
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
      var query = _supabase.from('lesson_hours').select();
      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        query = query.eq('school_id', cleanSchoolId);
      }
      final response = await query.order('teaching_hour', ascending: true);

      final List<HourModel> list = [];
      for (final item in (response as List)) {
        try {
          if (item is Map<String, dynamic>) {
            list.add(HourModel.fromJson(item));
          } else if (item is Map) {
            list.add(HourModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
      return list;
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

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase.from('lesson_hours').delete().inFilter('id', ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa jam pelajaran: $e');
    }
  }
}
