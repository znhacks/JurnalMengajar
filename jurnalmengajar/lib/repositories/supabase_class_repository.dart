import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/class_model.dart';
import '../core/utils/helper.dart';
import 'class_repository.dart';

const _uuid = Uuid();

class SupabaseClassRepository implements ClassRepository {
  final SupabaseClient _supabase;

  SupabaseClassRepository(this._supabase);

  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async {
    try {
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
      var query = _supabase.from('classes').select();
      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        query = query.eq('school_id', cleanSchoolId);
      }
      final response = await query.order('name', ascending: true);

      final List<ClassModel> list = [];
      for (final item in (response as List)) {
        try {
          if (item is Map<String, dynamic>) {
            list.add(ClassModel.fromJson(item));
          } else if (item is Map) {
            list.add(ClassModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> create(ClassModel model) async {
    try {
      final payload = model.toJson();
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('classes').insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah kelas: $e');
    }
  }

  @override
  Future<void> update(ClassModel model) async {
    try {
      await _supabase
          .from('classes')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui kelas: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('classes').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus kelas: $e');
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase.from('classes').delete().inFilter('id', ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa kelas: $e');
    }
  }
}
