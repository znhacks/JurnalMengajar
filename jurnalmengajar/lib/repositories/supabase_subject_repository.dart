import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/subject_model.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';
import 'subject_repository.dart';

const _uuid = Uuid();

class SupabaseSubjectRepository implements SubjectRepository {
  final SupabaseClient _supabase;

  SupabaseSubjectRepository(this._supabase);

  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
    final cacheKey = 'subjects_${cleanSchoolId ?? "all"}';

    Future<List<SubjectModel>> loadFromCache() async {
      try {
        final cached = await CacheService().loadList(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          return cached.map((e) => SubjectModel.fromJson(e)).toList();
        }
      } catch (_) {}
      return <SubjectModel>[];
    }

    try {
      return await NetworkResilience.execute<List<SubjectModel>>(
        operationName: 'SubjectRepository.getAll',
        fallback: loadFromCache,
        networkTask: () async {
          var query = _supabase.from('subjects').select();
          if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
            query = query.eq('school_id', cleanSchoolId);
          }
          final response = await query.order('name', ascending: true);

          final List<SubjectModel> list = [];
          final List<Map<String, dynamic>> cacheable = [];
          for (final item in (response as List)) {
            try {
              final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
              list.add(SubjectModel.fromJson(map));
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
  Future<void> create(SubjectModel model) async {
    try {
      final payload = model.toJson();
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('subjects').insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah mata pelajaran: $e');
    }
  }

  @override
  Future<void> update(SubjectModel model) async {
    try {
      await _supabase
          .from('subjects')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui mata pelajaran: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('subjects').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus mata pelajaran: $e');
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase.from('subjects').delete().inFilter('id', ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa mata pelajaran: $e');
    }
  }
}
