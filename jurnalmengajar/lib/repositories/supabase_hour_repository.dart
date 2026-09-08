import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/hour_model.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';
import 'hour_repository.dart';

const _uuid = Uuid();

class SupabaseHourRepository implements HourRepository {
  final SupabaseClient _supabase;

  SupabaseHourRepository(this._supabase);

  @override
  Future<List<HourModel>> getAll([String? schoolId]) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
    final cacheKey = 'hours_${cleanSchoolId ?? "all"}';

    Future<List<HourModel>> loadFromCache() async {
      try {
        final cached = await CacheService().loadList(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          return cached.map((e) => HourModel.fromJson(e)).toList();
        }
      } catch (_) {}
      return <HourModel>[];
    }

    try {
      return await NetworkResilience.execute<List<HourModel>>(
        operationName: 'HourRepository.getAll',
        fallback: loadFromCache,
        networkTask: () async {
          var query = _supabase.from('lesson_hours').select();
          if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
            query = query.eq('school_id', cleanSchoolId);
          }
          final response = await query.order('teaching_hour', ascending: true);

          final List<HourModel> list = [];
          final List<Map<String, dynamic>> cacheable = [];
          for (final item in (response as List)) {
            try {
              final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
              list.add(HourModel.fromJson(map));
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
