import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_model.dart';
import '../core/utils/helper.dart';
import 'teacher_repository.dart';


class SupabaseTeacherRepository implements TeacherRepository {
  final SupabaseClient _supabase;

  SupabaseTeacherRepository(this._supabase);

  @override
  Future<List<TeacherModel>> getAll() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('full_name', ascending: true);

      final List<TeacherModel> teachers = [];
      for (final item in (response as List)) {
        try {
          if (item is Map<String, dynamic>) {
            teachers.add(TeacherModel.fromJson(item));
          } else if (item is Map) {
            teachers.add(TeacherModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
      return teachers;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async {
    try {
      debugPrint('================================================================');
      debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Fetching teachers for schoolId: "$schoolId"...');

      final Map<String, TeacherModel> teachersMap = {};
      final Set<String> linkedUserIds = {};

      if (schoolId.isNotEmpty) {
        // 1. Fetch user IDs linked in user_schools for this school
        try {
          final userSchoolsRes = await _supabase
              .from('user_schools')
              .select('user_id, role, status')
              .eq('school_id', schoolId);

          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] user_schools query returned: ${(userSchoolsRes as List).length} rows');
          for (final row in (userSchoolsRes as List)) {
            final status = (row['status'] as String? ?? 'active').toLowerCase();
            final uid = row['user_id']?.toString();
            final role = row['role']?.toString();
            debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] -> user_schools entry: user_id=$uid, role=$role, status=$status');
            if (status != 'pending' && status != 'rejected') {
              if (uid != null && uid.isNotEmpty) {
                linkedUserIds.add(uid);
              }
            }
          }
        } catch (err) {
          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] user_schools error: $err');
        }

        // 2. Fetch user IDs linked in school_memberships
        try {
          final memRes = await _supabase
              .from('school_memberships')
              .select('user_id, role')
              .eq('school_id', schoolId);

          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] school_memberships query returned: ${(memRes as List).length} rows');
          for (final row in (memRes as List)) {
            final uid = row['user_id']?.toString();
            if (uid != null && uid.isNotEmpty) {
              linkedUserIds.add(uid);
            }
          }
        } catch (err) {
          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] school_memberships error: $err');
        }
      }

      debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Total linked user IDs from memberships: ${linkedUserIds.length}');

      // 3. Query all users from public.users table
      try {
        final res = await _supabase
            .from('users')
            .select()
            .order('full_name', ascending: true);

        debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] public.users query returned: ${(res as List).length} total users.');

        for (final item in (res as List)) {
          try {
            final Map<String, dynamic> json = item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item as Map);

            final tId = json['id']?.toString() ?? '';
            final userFullName = json['full_name']?.toString() ?? json['name']?.toString() ?? '';
            final userRole = json['role']?.toString() ?? '';
            
            final isLinked = linkedUserIds.contains(tId);
            final isSchoolMatch = schoolId.isEmpty ||
                AppHelper.matchesSchool(json['school_id'], json['school_ids'], schoolId);

            if (isLinked || isSchoolMatch || schoolId.isEmpty) {
              teachersMap[tId] = TeacherModel.fromJson(json);
              debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] -> MATCHED USER: id=$tId, name="$userFullName", role=$userRole, schoolId=$schoolId (isLinked=$isLinked, isSchoolMatch=$isSchoolMatch)');
            }
          } catch (err) {
            debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Error parsing user: $err');
          }
        }
      } catch (err) {
        debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] public.users error: $err');
      }

      // 4. Fallback: if userIds from memberships were not loaded yet, query specifically by ID
      if (linkedUserIds.isNotEmpty) {
        final missingIds = linkedUserIds.where((id) => !teachersMap.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Fetching missing linked users by ID: $missingIds');
          try {
            final missingRes = await _supabase
                .from('users')
                .select()
                .inFilter('id', missingIds);

            for (final item in (missingRes as List)) {
              try {
                final Map<String, dynamic> json = item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map);
                final t = TeacherModel.fromJson(json);
                teachersMap[t.id] = t;
              } catch (_) {}
            }
          } catch (_) {}
        }
      }

      // 5. Ensure all teachers that have schedules in schedules table are also present
      try {
        final schedRes = await _supabase
            .from('schedules')
            .select('teacher_id');

        final Set<String> scheduleTeacherIds = {};
        for (final row in (schedRes as List)) {
          final tid = row['teacher_id']?.toString();
          if (tid != null && tid.isNotEmpty && !teachersMap.containsKey(tid)) {
            scheduleTeacherIds.add(tid);
          }
        }

        if (scheduleTeacherIds.isNotEmpty) {
          debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] Fetching extra teachers from schedules: $scheduleTeacherIds');
          try {
            final extraRes = await _supabase
                .from('users')
                .select()
                .inFilter('id', scheduleTeacherIds.toList());

            for (final item in (extraRes as List)) {
              try {
                final Map<String, dynamic> json = item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map);
                final t = TeacherModel.fromJson(json);
                teachersMap[t.id] = t;
              } catch (_) {}
            }
          } catch (_) {}
        }
      } catch (_) {}

      final teachers = teachersMap.values.toList();
      teachers.sort((a, b) => a.name.compareTo(b.name));
      debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] FINAL TEACHER COUNT RETURNED: ${teachers.length}');
      for (final t in teachers) {
        debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] -> Teacher: id=${t.id}, name="${t.name}", position="${t.position}", email="${t.email}"');
      }
      debugPrint('================================================================');
      return teachers;
    } catch (e) {
      debugPrint('[RUNTIME_DEBUG:TEACHER_REPO] ERROR in getAllForSchool: $e');
      return [];
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
