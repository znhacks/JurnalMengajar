import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/period_model.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';
import 'period_repository.dart';

const _uuid = Uuid();

class SupabasePeriodRepository implements PeriodRepository {
  final SupabaseClient _supabase;

  SupabasePeriodRepository(this._supabase);

  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
    final cacheKey = 'periods_${cleanSchoolId ?? "all"}';

    Future<List<PeriodModel>> loadFromCache() async {
      try {
        final cached = await CacheService().loadList(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          return cached.map((e) => PeriodModel.fromJson(e)).toList();
        }
      } catch (_) {}
      return <PeriodModel>[];
    }

    try {
      return await NetworkResilience.execute<List<PeriodModel>>(
        operationName: 'PeriodRepository.getAll',
        fallback: loadFromCache,
        networkTask: () async {
          var query = _supabase.from('periods').select();
          if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
            query = query.eq('school_id', cleanSchoolId);
          }
          final response = await query.order('name', ascending: true);

          final List<PeriodModel> list = [];
          final List<Map<String, dynamic>> cacheable = [];
          for (final item in (response as List)) {
            try {
              final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
              list.add(PeriodModel.fromJson(map));
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
  Future<void> create(PeriodModel model) async {
    try {
      if (model.isActive) {
        var deactivateQuery = _supabase
            .from('periods')
            .update({'is_active': false})
            .eq('is_active', true);
        if (model.schoolId != null && model.schoolId!.isNotEmpty) {
          deactivateQuery = deactivateQuery.eq('school_id', model.schoolId!);
        }
        await deactivateQuery;
      }
      final payload = model.toJson();
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('periods').insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah periode: $e');
    }
  }

  @override
  Future<void> update(PeriodModel model) async {
    try {
      if (model.isActive) {
        var deactivateQuery = _supabase
            .from('periods')
            .update({'is_active': false})
            .eq('is_active', true);
        if (model.schoolId != null && model.schoolId!.isNotEmpty) {
          deactivateQuery = deactivateQuery.eq('school_id', model.schoolId!);
        }
        await deactivateQuery;
      }
      await _supabase
          .from('periods')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui periode: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('periods').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus periode: $e');
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase.from('periods').delete().inFilter('id', ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa periode: $e');
    }
  }
}
