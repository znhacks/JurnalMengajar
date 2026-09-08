import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_model.dart';
import 'schedule_repository.dart';
import '../core/constants/supabase_constants.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';

const _uuid = Uuid();

class SupabaseScheduleRepository implements ScheduleRepository {
  final SupabaseClient _supabase;

  SupabaseScheduleRepository(this._supabase);

  @override
  Future<List<ScheduleModel>> getAll([String? schoolId]) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
    final cacheKey = 'schedules_${cleanSchoolId ?? "all"}';

    // Fallback loader dari local cache jika offline / sinyal lemah
    Future<List<ScheduleModel>> loadFromCache() async {
      try {
        final cachedList = await CacheService().loadList(cacheKey);
        if (cachedList != null && cachedList.isNotEmpty) {
          debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Loaded ${cachedList.length} schedules from local cache.');
          return cachedList.map((item) => ScheduleModel.fromJson(item)).toList();
        }
      } catch (err) {
        debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Cache read error: $err');
      }
      return <ScheduleModel>[];
    }

    try {
      return await NetworkResilience.execute<List<ScheduleModel>>(
        operationName: 'ScheduleRepository.getAll',
        fallback: loadFromCache,
        networkTask: () async {
          final currentAuthUid = _supabase.auth.currentUser?.id;
          final currentAuthEmail = _supabase.auth.currentUser?.email;
          debugPrint('================================================================');
          debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Fetching ALL schedules from network...');
          debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Current Auth User: id=$currentAuthUid, email=$currentAuthEmail');
          debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Parameter schoolId: "$schoolId"');

          var query = _supabase.from(SupabaseConstants.tableSchedules).select();
          if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
            query = query.eq('school_id', cleanSchoolId);
          } else {
            debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] WARNING: ScheduleRepository.getAll called without cleanSchoolId! Scoping may rely solely on RLS.');
          }
          final response = await query.order(SupabaseConstants.fieldDate, ascending: true);

          final List rawList = response as List;
          debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Raw Database Response: ${rawList.length} rows returned.');

          final List<ScheduleModel> schedules = [];
          final List<Map<String, dynamic>> cacheableList = [];
          for (final item in rawList) {
            try {
              final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
              schedules.add(ScheduleModel.fromJson(map));
              cacheableList.add(map);
            } catch (_) {}
          }

          // Simpan ke cache lokal secara async agar selalu tersedia saat sinyal lemah
          CacheService().save(cacheKey, cacheableList);

          return schedules;
        },
      );
    } catch (e) {
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Network error in getAll, falling back to cache: $e');
      return await loadFromCache();
    }
  }

  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, {DateTime? date}) async {
    final cacheKey = 'teacher_schedules_$teacherId';

    Future<List<ScheduleModel>> loadFromCache() async {
      try {
        final cached = await CacheService().loadList(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          final allSchedules = cached.map((e) => ScheduleModel.fromJson(e)).toList();
          if (date == null) return allSchedules;
          return allSchedules.where((s) =>
              s.date.year == date.year &&
              s.date.month == date.month &&
              s.date.day == date.day).toList();
        }
      } catch (_) {}
      return <ScheduleModel>[];
    }

    try {
      return await NetworkResilience.execute<List<ScheduleModel>>(
        operationName: 'ScheduleRepository.getSchedulesForTeacher',
        fallback: loadFromCache,
        networkTask: () async {
          var query = _supabase
              .from(SupabaseConstants.tableSchedules)
              .select()
              .eq(SupabaseConstants.fieldTeacherId, teacherId);

          if (date != null) {
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final nextDateStr = '${date.add(const Duration(days: 1)).year}-${date.add(const Duration(days: 1)).month.toString().padLeft(2, '0')}-${date.add(const Duration(days: 1)).day.toString().padLeft(2, '0')}';
            query = query
                .gte(SupabaseConstants.fieldDate, dateStr)
                .lt(SupabaseConstants.fieldDate, nextDateStr);
          }

          final response = await query.order(SupabaseConstants.fieldDate, ascending: true);

          final List<ScheduleModel> schedules = [];
          final List<Map<String, dynamic>> cacheable = [];
          for (final item in (response as List)) {
            try {
              final map = item is Map<String, dynamic> ? item : Map<String, dynamic>.from(item as Map);
              schedules.add(ScheduleModel.fromJson(map));
              cacheable.add(map);
            } catch (_) {}
          }

          if (date == null && cacheable.isNotEmpty) {
            CacheService().save(cacheKey, cacheable);
          }

          return schedules;
        },
      );
    } catch (e) {
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Weak signal fallback for teacher schedules: $e');
      return await loadFromCache();
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

      // Auto-resolve school_id if missing
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(payload['school_id']);
      if (cleanSchoolId == null || cleanSchoolId.isEmpty) {
        final currentUid = _supabase.auth.currentUser?.id ?? model.teacherId;
        if (currentUid.isNotEmpty) {
          try {
            final userRes = await _supabase
                .from('users')
                .select('school_id')
                .eq('id', currentUid)
                .maybeSingle();
            if (userRes != null && userRes['school_id'] != null) {
              payload['school_id'] = AppHelper.parseSingleCleanSchoolId(userRes['school_id']);
            }
          } catch (_) {}
        }
      } else {
        payload['school_id'] = cleanSchoolId;
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
      // Auto-resolve school_id if needed
      String? fallbackSchoolId;
      final currentUid = _supabase.auth.currentUser?.id;
      if (currentUid != null) {
        try {
          final userRes = await _supabase
              .from('users')
              .select('school_id')
              .eq('id', currentUid)
              .maybeSingle();
          if (userRes != null && userRes['school_id'] != null) {
            fallbackSchoolId = AppHelper.parseSingleCleanSchoolId(userRes['school_id']);
          }
        } catch (_) {}
      }

      final payloads = models.map((model) {
        final payload = model.toJson();
        if ((payload['id'] as String?)?.isEmpty ?? true) {
          payload['id'] = _uuid.v4();
        }
        final cleanId = AppHelper.parseSingleCleanSchoolId(payload['school_id']);
        if (cleanId == null || cleanId.isEmpty) {
          if (fallbackSchoolId != null && fallbackSchoolId.isNotEmpty) {
            payload['school_id'] = fallbackSchoolId;
          }
        } else {
          payload['school_id'] = cleanId;
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

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    try {
      await _supabase
          .from(SupabaseConstants.tableSchedules)
          .delete()
          .inFilter(SupabaseConstants.fieldId, ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa jadwal: $e');
    }
  }
}
