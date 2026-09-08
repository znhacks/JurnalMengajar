import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_model.dart';
import 'schedule_repository.dart';
import '../core/constants/supabase_constants.dart';
import '../core/utils/helper.dart';


const _uuid = Uuid();

class SupabaseScheduleRepository implements ScheduleRepository {
  final SupabaseClient _supabase;

  SupabaseScheduleRepository(this._supabase);

  @override
  Future<List<ScheduleModel>> getAll([String? schoolId]) async {
    try {
      final currentAuthUid = _supabase.auth.currentUser?.id;
      final currentAuthEmail = _supabase.auth.currentUser?.email;
      debugPrint('================================================================');
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Fetching ALL schedules...');
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Current Auth User: id=$currentAuthUid, email=$currentAuthEmail');
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Parameter schoolId: "$schoolId"');

      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
      var query = _supabase.from(SupabaseConstants.tableSchedules).select();
      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        query = query.eq('school_id', cleanSchoolId);
      }
      final response = await query.order(SupabaseConstants.fieldDate, ascending: true);

      final List rawList = response as List;
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Raw Database Response: ${rawList.length} rows returned.');

      final List<ScheduleModel> schedules = [];
      int parseErrors = 0;
      for (final item in rawList) {
        try {
          if (item is Map<String, dynamic>) {
            schedules.add(ScheduleModel.fromJson(item));
          } else if (item is Map) {
            schedules.add(ScheduleModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (err) {
          parseErrors++;
          debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Parse Error on row: $item -> $err');
        }
      }

      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Parsed Schedules: ${schedules.length} successfully parsed ($parseErrors parse errors).');
      
      // Breakdown by teacher and school
      final Map<String, int> countByTeacher = {};
      final Map<String, int> countBySchool = {};
      for (final s in schedules) {
        final tKey = s.teacherId.isNotEmpty ? s.teacherId : '(empty teacherId)';
        countByTeacher[tKey] = (countByTeacher[tKey] ?? 0) + 1;

        final sKey = (s.schoolId != null && s.schoolId!.isNotEmpty) ? s.schoolId! : '(null/empty schoolId)';
        countBySchool[sKey] = (countBySchool[sKey] ?? 0) + 1;
      }

      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Schedules by Teacher ID: $countByTeacher');
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Schedules by School ID: $countBySchool');
      if (schedules.isNotEmpty) {
        final sample = schedules.first;
        debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Sample Schedule: id=${sample.id}, teacherId=${sample.teacherId}, classId=${sample.classId}, subjectId=${sample.subjectId}, date=${sample.date}, schoolId=${sample.schoolId}, isActive=${sample.isActive}');
      }
      debugPrint('================================================================');

      // Background self-heal: Ensure all schedules have the active school_id if missing
      if (schoolId != null && schoolId.isNotEmpty) {
        final backfillIds = schedules
            .where((s) => s.schoolId == null || s.schoolId!.isEmpty)
            .map((s) => s.id)
            .toList();

        if (backfillIds.isNotEmpty) {
          debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] Self-healing ${backfillIds.length} schedules with school_id=$schoolId');
          try {
            _supabase
                .from(SupabaseConstants.tableSchedules)
                .update({'school_id': schoolId})
                .inFilter('id', backfillIds)
                .then((_) {})
                .catchError((_) {});
          } catch (_) {}
        }
      }

      return schedules;
    } catch (e) {
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_REPO] ERROR in getAll: $e');
      throw Exception('Gagal memuat jadwal mengajar: $e');
    }
  }

  @override
  Future<List<ScheduleModel>> getSchedulesForTeacher(String teacherId, {DateTime? date}) async {
    try {
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
      for (final item in (response as List)) {
        try {
          if (item is Map<String, dynamic>) {
            schedules.add(ScheduleModel.fromJson(item));
          } else if (item is Map) {
            schedules.add(ScheduleModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }

      return schedules;
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
