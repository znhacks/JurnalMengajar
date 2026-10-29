import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_model.dart';
import '../core/constants/teacher_roles.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';
import 'teacher_repository.dart';

class SupabaseTeacherRepository
    implements TeacherRepository, SchoolScopedTeacherRepository {
  final SupabaseClient _supabase;

  SupabaseTeacherRepository(this._supabase);

  @override
  Future<List<TeacherModel>> getAll() async {
    // Teachers are strictly tenant-scoped. Calling getAll() without a schoolId
    // risks cross-tenant data leakage. Return empty list for safety; use getAllForSchool(schoolId) instead.
    debugPrint(
      '[RUNTIME_DEBUG:TEACHER_REPO] getAll() called without tenant schoolId -> returning empty list for tenant isolation.',
    );
    return [];
  }

  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
    if (cleanSchoolId == null || cleanSchoolId.isEmpty) {
      debugPrint(
        '[RUNTIME_DEBUG:TEACHER_REPO] getAllForSchool called with empty or invalid schoolId: "$schoolId" -> returning empty list for tenant safety.',
      );
      return <TeacherModel>[];
    }

    final cacheKey = 'teachers_$cleanSchoolId';

    Future<List<TeacherModel>> loadFromCache() async {
      try {
        final cached = await CacheService().loadList(cacheKey);
        if (cached != null && cached.isNotEmpty) {
          debugPrint(
            '[RUNTIME_DEBUG:TEACHER_REPO] Loaded ${cached.length} teachers from cache for schoolId: $cleanSchoolId',
          );
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
          debugPrint(
            '================================================================',
          );
          debugPrint(
            '[RUNTIME_DEBUG:TEACHER_REPO] Fetching teachers for cleanSchoolId: "$cleanSchoolId" from network...',
          );

          final Map<String, TeacherModel> teachersMap = {};
          final Set<String> activeLinkedUserIds = {};
          final Set<String> deactivatedTeacherIds = {};
          final Set<String> scheduledTeacherIds = {};

          // 1 & 2. Fetch teacher memberships and scheduled teacher IDs concurrently
          await Future.wait([
            (() async {
              try {
                final userSchoolsRes = await _supabase
                    .from('user_schools')
                    .select('user_id, role, status')
                    .eq('school_id', cleanSchoolId)
                    .inFilter('role', [
                      'guru',
                      'teacher',
                      TeacherRoles.softDeleted,
                    ]);

                debugPrint(
                  '[RUNTIME_DEBUG:TEACHER_REPO] Teacher memberships for $cleanSchoolId: ${(userSchoolsRes as List).length} rows',
                );
                for (final row in (userSchoolsRes as List)) {
                  final uid = row['user_id']?.toString();
                  if (uid == null || uid.isEmpty) continue;
                  final role = row['role']?.toString();
                  final membershipStatus =
                      (row['status']?.toString() ?? 'active').toLowerCase();
                  if (TeacherRoles.isSoftDeleted(role)) {
                    // Keep deactivated teachers out of the active roster even
                    // if their membership was pending/inactive for another
                    // reason. Historical lookups still receive the model.
                    deactivatedTeacherIds.add(uid);
                  } else if (membershipStatus == 'active') {
                    activeLinkedUserIds.add(uid);
                  }
                }
              } catch (err) {
                debugPrint(
                  '[RUNTIME_DEBUG:TEACHER_REPO] user_schools query error: $err',
                );
              }
            })(),
            (() async {
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
                debugPrint(
                  '[RUNTIME_DEBUG:TEACHER_REPO] Teachers with schedules in $cleanSchoolId: ${scheduledTeacherIds.length}',
                );
              } catch (err) {
                debugPrint(
                  '[RUNTIME_DEBUG:TEACHER_REPO] schedules query error: $err',
                );
              }
            })(),
          ]);

          // 3. Query users scoped strictly to cleanSchoolId
          deactivatedTeacherIds.removeAll(activeLinkedUserIds);
          final linkedUserIds = <String>{
            ...activeLinkedUserIds,
            ...deactivatedTeacherIds,
          };
          try {
            final Set<String> targetUserIds = {
              ...linkedUserIds,
              ...scheduledTeacherIds,
            };

            var usersQuery = _supabase.from('users').select();

            if (targetUserIds.isNotEmpty) {
              // PostgREST uuid in-filter MUST NOT contain double quotes: id.in.(uuid1,uuid2)
              final idListFilter = targetUserIds.join(',');
              usersQuery = usersQuery.or(
                'school_id.eq.$cleanSchoolId,school_ids.cs.{"$cleanSchoolId"},id.in.($idListFilter)',
              );
            } else {
              usersQuery = usersQuery.or(
                'school_id.eq.$cleanSchoolId,school_ids.cs.{"$cleanSchoolId"}',
              );
            }

            final res = await usersQuery.order('full_name', ascending: true);
            debugPrint(
              '[RUNTIME_DEBUG:TEACHER_REPO] Scoped teacher users returned: ${(res as List).length} rows for $cleanSchoolId',
            );

            for (final item in (res as List)) {
              try {
                final Map<String, dynamic> json = item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map);

                final tId = json['id']?.toString() ?? '';
                if (tId.isEmpty) continue;

                final userRole = (json['role']?.toString() ?? '').toLowerCase();
                final isDirectMatch = AppHelper.matchesSchool(
                  json['school_id'],
                  json['school_ids'],
                  cleanSchoolId,
                );
                final isLinkedMember = linkedUserIds.contains(tId);
                final isScheduledTeacher = scheduledTeacherIds.contains(tId);
                final isDeactivatedTeacher = deactivatedTeacherIds.contains(
                  tId,
                );

                // STRICT TENANT ISOLATION: User must belong to this school via direct school_id, teacher membership, or schedule
                if (!isDirectMatch && !isLinkedMember && !isScheduledTeacher) {
                  debugPrint(
                    '[RUNTIME_DEBUG:TEACHER_REPO] -> REJECTED FOREIGN USER: $tId, name=${json['full_name']} (does not belong to $cleanSchoolId)',
                  );
                  continue;
                }

                // STRICT ROLE FILTER: Dedicated pure admin (e.g. admin@jurnal.com) MUST NEVER appear as a teacher!
                final isTeacherRole =
                    userRole == 'guru' || userRole == 'teacher';
                final isSoftDeletedTeacher = TeacherRoles.isSoftDeleted(
                  userRole,
                );
                if (!isTeacherRole &&
                    !isSoftDeletedTeacher &&
                    !isLinkedMember &&
                    !isScheduledTeacher) {
                  debugPrint(
                    '[RUNTIME_DEBUG:TEACHER_REPO] -> REJECTED NON-TEACHER: id=$tId, name="${json['full_name']}", role=$userRole',
                  );
                  continue;
                }
                if (userRole == 'admin' &&
                    !isLinkedMember &&
                    !isScheduledTeacher) {
                  debugPrint(
                    '[RUNTIME_DEBUG:TEACHER_REPO] -> REJECTED PURE ADMIN: id=$tId, name="${json['full_name']}"',
                  );
                  continue;
                }

                final teacher = TeacherModel.fromJson(json);
                teachersMap[tId] = teacher.copyWith(
                  isDeleted: teacher.isDeleted || isDeactivatedTeacher,
                );
                debugPrint(
                  '[RUNTIME_DEBUG:TEACHER_REPO] -> ACCEPTED GURU/TEACHER: id=$tId, name="${json['full_name']}", role=$userRole, deactivated=$isDeactivatedTeacher for school $cleanSchoolId',
                );
              } catch (err) {
                debugPrint(
                  '[RUNTIME_DEBUG:TEACHER_REPO] Error parsing user: $err',
                );
              }
            }
          } catch (err) {
            debugPrint(
              '[RUNTIME_DEBUG:TEACHER_REPO] scoped users query error: $err',
            );
          }

          // 4. Ensure all teachers with schedules in this school are loaded
          final missingScheduledTeacherIds = scheduledTeacherIds
              .where((id) => !teachersMap.containsKey(id))
              .toList();
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
                  final userRole = (json['role']?.toString() ?? '')
                      .toLowerCase();
                  if (userRole == 'admin' &&
                      !linkedUserIds.contains(json['id'])) {
                    continue;
                  }

                  final t = TeacherModel.fromJson(json);
                  teachersMap[t.id] = t.copyWith(
                    isDeleted:
                        t.isDeleted || deactivatedTeacherIds.contains(t.id),
                  );
                } catch (_) {}
              }
            } catch (_) {}
          }

          final teachers = teachersMap.values.toList();
          teachers.sort((a, b) => a.name.compareTo(b.name));
          debugPrint(
            '[RUNTIME_DEBUG:TEACHER_REPO] FINAL ISOLATED TEACHERS FOR $cleanSchoolId: ${teachers.length}',
          );

          // Save to local cache
          if (teachers.isNotEmpty) {
            CacheService().save(
              cacheKey,
              teachers.map((t) => t.toJson()).toList(),
            );
          }

          debugPrint(
            '================================================================',
          );
          return teachers;
        },
      );
    } catch (e) {
      debugPrint(
        '[RUNTIME_DEBUG:TEACHER_REPO] Exception in getAllForSchool: $e',
      );
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
            'nip': model.nip,
          })
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui guru: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _deactivateAllSchools([id]);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      throw Exception('Gagal menonaktifkan guru: $message');
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    try {
      await _deactivateAllSchools(ids);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      throw Exception('Gagal menonaktifkan beberapa guru: $message');
    }
  }

  @override
  Future<void> deactivate(String id, String schoolId) async {
    try {
      await _deactivateForSchool([id], schoolId);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      throw Exception('Gagal menonaktifkan guru: $message');
    }
  }

  @override
  Future<void> deactivateMultiple(List<String> ids, String schoolId) async {
    try {
      await _deactivateForSchool(ids, schoolId);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      throw Exception('Gagal menonaktifkan beberapa guru: $message');
    }
  }

  /// Marks the teacher membership as deactivated only in [schoolId]. The
  /// membership keeps status `active` so the account can still read schedules,
  /// journals, and other historical data. Journal writes are blocked in the
  /// app layer for this school only.
  Future<void> _deactivateForSchool(List<String> ids, String schoolId) async {
    final cleanIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (cleanIds.isEmpty) return;

    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
    if (cleanSchoolId == null || cleanSchoolId.isEmpty) {
      throw Exception('Sekolah aktif tidak ditemukan.');
    }

    final updated = await _supabase
        .from('user_schools')
        .update({
          'role': TeacherRoles.softDeleted,
          'status': 'inactive',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('school_id', cleanSchoolId)
        .inFilter('user_id', cleanIds)
        .inFilter('role', ['guru', 'teacher'])
        .inFilter('status', ['active', 'requested_exit'])
        .select('user_id');

    final updatedIds = <String>{};
    for (final row in updated) {
      final uid = (row as Map)['user_id']?.toString();
      if (uid != null && uid.isNotEmpty) {
        updatedIds.add(uid);
      }
    }

    final missingIds = cleanIds
        .where((id) => !updatedIds.contains(id))
        .toList();

    if (missingIds.isNotEmpty) {
      // Some older teachers only have users.school_id or schedules and no
      // membership row. Do not create an active membership for someone who is
      // already pending/inactive; otherwise deactivation could grant access.
      final existingRows = await _supabase
          .from('user_schools')
          .select('user_id, role')
          .eq('school_id', cleanSchoolId)
          .inFilter('user_id', missingIds);

      final usersWithTeacherMembership = <String>{};
      for (final row in existingRows) {
        final map = Map<String, dynamic>.from(row as Map);
        final uid = map['user_id']?.toString();
        final role = map['role']?.toString().toLowerCase();
        if (uid == null || uid.isEmpty) continue;
        if (role == 'guru' ||
            role == 'teacher' ||
            role == 'pending_guru' ||
            TeacherRoles.isSoftDeleted(role)) {
          usersWithTeacherMembership.add(uid);
        }
      }

      final idsToInsert = missingIds
          .where((id) => !usersWithTeacherMembership.contains(id))
          .toList();

      if (usersWithTeacherMembership.isNotEmpty) {
        await _supabase
            .from('user_schools')
            .update({
              'role': TeacherRoles.softDeleted,
              'status': 'inactive',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('school_id', cleanSchoolId)
            .inFilter('user_id', usersWithTeacherMembership.toList())
            .inFilter('role', ['guru', 'teacher']);
      }

      Object? firstInsertError;
      for (final id in idsToInsert) {
        try {
          await _supabase.from('user_schools').upsert({
            'user_id': id,
            'school_id': cleanSchoolId,
            'role': TeacherRoles.softDeleted,
            'status': 'inactive',
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'user_id, school_id, role');
        } catch (e) {
          firstInsertError ??= e;
        }
      }
      if (firstInsertError != null) {
        throw Exception(firstInsertError.toString());
      }
    }

    // Synchronize users table: remove residual school references if user has no remaining active schools
    for (final uid in cleanIds) {
      try {
        final activeMems = await _supabase
            .from('user_schools')
            .select('school_id, role, status, schools(name)')
            .eq('user_id', uid)
            .eq('status', 'active');

        final validActive = (activeMems as List).where((row) {
          final sId = AppHelper.parseSingleCleanSchoolId(row['school_id']);
          final role = row['role']?.toString();
          return sId != null &&
              sId != cleanSchoolId &&
              !TeacherRoles.isSoftDeleted(role);
        }).toList();

        if (validActive.isEmpty) {
          await _supabase.from('users').update({
            'school_id': null,
            'school_name': null,
            'school_ids': [],
          }).eq('id', uid);
        } else {
          final next = validActive.first;
          final nextId = AppHelper.parseSingleCleanSchoolId(next['school_id']) ?? next['school_id'];
          final nextName = next['schools'] != null && next['schools'] is Map
              ? next['schools']['name']
              : null;
          final remainingIds = validActive
              .map((row) => AppHelper.parseSingleCleanSchoolId(row['school_id']))
              .whereType<String>()
              .toSet()
              .toList();
          await _supabase.from('users').update({
            'school_id': nextId,
            'school_name': nextName,
            'school_ids': remainingIds,
          }).eq('id', uid);
        }
      } catch (userSyncErr) {
        debugPrint('Error syncing users table for teacher $uid: $userSyncErr');
      }
    }
  }

  /// Legacy fallback for callers without a school context. It still keeps the
  /// account and historical data; only teacher memberships are marked.
  Future<void> _deactivateAllSchools(List<String> ids) async {
    final cleanIds = ids
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (cleanIds.isEmpty) return;

    await _supabase
        .from('user_schools')
        .update({
          'role': TeacherRoles.softDeleted,
          'status': 'inactive',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .inFilter('user_id', cleanIds)
        .inFilter('role', ['guru', 'teacher'])
        .inFilter('status', ['active', 'requested_exit']);

    for (final uid in cleanIds) {
      try {
        await _supabase.from('users').update({
          'school_id': null,
          'school_name': null,
          'school_ids': [],
        }).eq('id', uid);
      } catch (_) {}
    }
  }
}
