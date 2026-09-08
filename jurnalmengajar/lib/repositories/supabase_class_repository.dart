import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/class_model.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';
import 'class_repository.dart';

const _uuid = Uuid();

class SupabaseClassRepository implements ClassRepository {
  final SupabaseClient _supabase;

  SupabaseClassRepository(this._supabase);

  @override
  Future<List<ClassModel>> getAll([String? schoolId]) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
    final cacheKey = 'classes_${cleanSchoolId ?? "all"}';

    Future<List<ClassModel>> loadFromCache() async {
      try {
        final cached = await CacheService().loadList(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          return cached.map((e) => ClassModel.fromJson(e)).toList();
        }
      } catch (_) {}
      return <ClassModel>[];
    }

    try {
      return await NetworkResilience.execute<List<ClassModel>>(
        operationName: 'ClassRepository.getAll',
        fallback: loadFromCache,
        networkTask: () async {
          var query = _supabase.from('classes').select();
          if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
            query = query.eq('school_id', cleanSchoolId);
          }
          final response = await query.order('name', ascending: true);

          final List<ClassModel> list = [];
          final List<Map<String, dynamic>> cacheable = [];
          for (final item in (response as List)) {
            try {
              final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
              list.add(ClassModel.fromJson(map));
              cacheable.add(map);
            } catch (_) {}
          }

          if (cacheable.isNotEmpty) {
            CacheService().save(cacheKey, cacheable);
          }
          return list;
        },
      );
    } catch (e) {
      return await loadFromCache();
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
