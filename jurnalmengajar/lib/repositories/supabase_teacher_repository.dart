import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_model.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';
import 'teacher_repository.dart';

class SupabaseTeacherRepository implements TeacherRepository {
  final SupabaseClient _supabase;

  SupabaseTeacherRepository(this._supabase);

  @override
  Future<List<TeacherModel>> getAll() async {
    // Teachers are strictly tenant-scoped. Calling getAll() without a schoolId
    // risks cross-tenant data leakage. Return empty list for safety; use getAllForSchool(schoolId) instead.
    debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] getAll() called without tenant schoolId -> returning empty list for tenant isolation.');
    return [];
  }

  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
    if (cleanSchoolId == null || cleanSchoolId.isEmpty) {
      debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] getAllForSchool called with empty or invalid schoolId: "$schoolId" -> returning empty list for tenant safety.');
      return <TeacherModel>[];
    }

    final cacheKey = 'teachers_$cleanSchoolId';

    Future<List<TeacherModel>> loadFromCache() async {
      try {
        final cached = await CacheService().loadList(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Loaded ${cached.length} teachers from cache for schoolId: $cleanSchoolId');
          return cached.map((e) => TeacherModel.fromJson(e)).toList();
        }
      } catch (_) {}
      return <TeacherModel>[];
    }

    try {
      return await NetworkResilience.execute<List<TeacherModel>>(
        operationName: 'TeacherRepository.getAllForSchool',
        fallback: loadFromCache,
        networkTask: () async {
          debugPrint('================================================================');
          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Fetching teachers for cleanSchoolId: "$cleanSchoolId" from network...');

          final Map<String, TeacherModel> teachersMap = {};
          final Set<String> activeLinkedUserIds = {};
          final Set<String> scheduledTeacherIds = {};

          // 1. Fetch only ACTIVE user memberships with TEACHER role for this specific school in user_schools
          try {
            final userSchoolsRes = await _supabase
                .from('user_schools')
                .select('user_id, role, status')
                .eq('school_id', cleanSchoolId)
                .eq('status', 'active')
                .inFilter('role', ['guru', 'teacher']);

            debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Active teacher memberships for $cleanSchoolId: ${(userSchoolsRes as List).length} rows');
            for (final row in (userSchoolsRes as List)) {
              final uid = row['user_id']?.toString();
              if (uid != null && uid.isNotEmpty) {
                activeLinkedUserIds.add(uid);
              }
            }
          } catch (err) {
            debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] user_schools query error: $err');
          }

          // 2. Fetch teachers who have active schedules in this school
          try {
            final schedRes = await _supabase
                .from('schedules')
                .select('teacher_id')
                .eq('school_id', cleanSchoolId);

            for (final row in (schedRes as List)) {
              final tid = row['teacher_id']?.toString();
              if (tid != null && tid.isNotEmpty) {
                scheduledTeacherIds.add(tid);
              }
            }
            debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Teachers with schedules in $cleanSchoolId: ${scheduledTeacherIds.length}');
          } catch (err) {
            debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] schedules query error: $err');
          }

          // 3. Query users scoped strictly to cleanSchoolId
          try {
            final Set<String> targetUserIds = {...activeLinkedUserIds, ...scheduledTeacherIds};

            var usersQuery = _supabase.from('users').select();

            if (targetUserIds.isNotEmpty) {
              // PostgREST uuid in-filter MUST NOT contain double quotes: id.in.(uuid1,uuid2)
              final idListFilter = targetUserIds.join(',');
              usersQuery = usersQuery.or('school_id.eq.$cleanSchoolId,school_ids.cs.{"$cleanSchoolId"},id.in.($idListFilter)');
            } else {
              usersQuery = usersQuery.or('school_id.eq.$cleanSchoolId,school_ids.cs.{"$cleanSchoolId"}');
            }

            final res = await usersQuery.order('full_name', ascending: true);
            debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Scoped teacher users returned: ${(res as List).length} rows for $cleanSchoolId');

            for (final item in (res as List)) {
              try {
                final Map<String, dynamic> json = item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map);

                final tId = json['id']?.toString() ?? '';
                if (tId.isEmpty) continue;

                final userRole = (json['role']?.toString() ?? '').toLowerCase();
                final isDirectMatch = AppHelper.matchesSchool(json['school_id'], json['school_ids'], cleanSchoolId);
                final isActiveTeacherMember = activeLinkedUserIds.contains(tId);
                final isScheduledTeacher = scheduledTeacherIds.contains(tId);

                // STRICT TENANT ISOLATION: User must belong to this school via direct school_id, active user_schools, or schedule
                if (!isDirectMatch && !isActiveTeacherMember && !isScheduledTeacher) {
                  debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] -> REJECTED FOREIGN USER: $tId, name=${json['full_name']} (does not belong to $cleanSchoolId)');
                  continue;
                }

                // STRICT ROLE FILTER: Dedicated pure admin (e.g. admin@jurnal.com) MUST NEVER appear as a teacher!
                final isTeacherRole = userRole == 'guru' || userRole == 'teacher';
                if (!isTeacherRole && !isActiveTeacherMember && !isScheduledTeacher) {
                  debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] -> REJECTED NON-TEACHER: id=$tId, name="${json['full_name']}", role=$userRole');
                  continue;
                }
                if (userRole == 'admin' && !isActiveTeacherMember && !isScheduledTeacher) {
                  debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] -> REJECTED PURE ADMIN: id=$tId, name="${json['full_name']}"');
                  continue;
                }

                teachersMap[tId] = TeacherModel.fromJson(json);
                debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] -> ACCEPTED GURU/TEACHER: id=$tId, name="${json['full_name']}", role=$userRole for school $cleanSchoolId');
              } catch (err) {
                debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Error parsing user: $err');
              }
            }
          } catch (err) {
            debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] scoped users query error: $err');
          }

          // 4. Ensure all teachers with schedules in this school are loaded
          final missingScheduledTeacherIds = scheduledTeacherIds.where((id) => !teachersMap.containsKey(id)).toList();
          if (missingScheduledTeacherIds.isNotEmpty) {
            try {
              final extraRes = await _supabase
                  .from('users')
                  .select()
                  .inFilter('id', missingScheduledTeacherIds);

              for (final item in (extraRes as List)) {
                try {
                  final Map<String, dynamic> json = item is Map<String, dynamic>
                      ? item
                      : Map<String, dynamic>.from(item as Map);
                  final userRole = (json['role']?.toString() ?? '').toLowerCase();
                  if (userRole == 'admin' && !activeLinkedUserIds.contains(json['id'])) continue;

                  final t = TeacherModel.fromJson(json);
                  teachersMap[t.id] = t;
                } catch (_) {}
              }
            } catch (_) {}
          }

          final teachers = teachersMap.values.toList();
          teachers.sort((a, b) => a.name.compareTo(b.name));
          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] FINAL ISOLATED TEACHERS FOR $cleanSchoolId: ${teachers.length}');

          // Save to local cache
          if (teachers.isNotEmpty) {
            CacheService().save(cacheKey, teachers.map((t) => t.toJson()).toList());
          }

          debugPrint('================================================================');
          return teachers;
        },
      );
    } catch (e) {
      debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Exception in getAllForSchool: $e');
      return await loadFromCache();
    }
  }

  @override
  Future<void> create(TeacherModel model) async {
    try {
      // Teachers are created through user registration
      throw Exception('Guru dibuat melalui registrasi pengguna');
    } catch (e) {
      throw Exception('Gagal membuat guru: $e');
    }
  }

  @override
  Future<void> update(TeacherModel model) async {
    try {
      await _supabase
          .from('users')
          .update({
            'full_name': model.name,
            'position': model.position,
            'address': model.address,
            'phone': model.phoneNumber,
            'photo_url': model.photoUrl,
          })
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui guru: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase
          .from('users')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus guru: $e');
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase
          .from('users')
          .delete()
          .inFilter('id', ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa guru: $e');
    }
  }
}
