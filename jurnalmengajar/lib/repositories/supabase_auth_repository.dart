import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';
import '../core/utils/image_compressor.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';
import '../core/utils/network_resilience.dart';


class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase;

  SupabaseAuthRepository(this._supabase);

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return null;

      final userId = session.user.id;

      return await NetworkResilience.execute<UserModel?>(
        operationName: 'getCurrentUser',
        networkTask: () async {
          var response = await _supabase
              .from('users')
              .select()
              .eq('id', userId)
              .maybeSingle();

          if (response == null) {
            final email = session.user.email ?? '';
            final fullName =
                session.user.userMetadata?['full_name'] as String? ??
                session.user.userMetadata?['name'] as String? ??
                email.split('@')[0];
            final photoUrl = session.user.userMetadata?['avatar_url'] as String?;
            final phone =
                session.user.phone ??
                session.user.userMetadata?['phone'] as String?;

            final newUser = UserModel(
              id: userId,
              email: email,
              fullName: fullName,
              role: 'pending_guru',
              photoUrl: photoUrl,
              phoneNumber: phone,
            );

            await _supabase
                .from('users')
                .upsert(newUser.toJson(), onConflict: 'id', ignoreDuplicates: true);

            response = await _supabase
                .from('users')
                .select()
                .eq('id', userId)
                .maybeSingle();

            if (response == null) {
              await CacheService().save('user_profile_$userId', newUser.toJson());
              return newUser;
            }
          }

          final user = UserModel.fromJson(response);
          await CacheService().save('user_profile_$userId', user.toJson());
          return user;
        },
        fallback: () async {
          final cached = await CacheService().loadMap('user_profile_$userId');
          if (cached != null) {
            debugPrint('[SupabaseAuthRepository] Loaded currentUser from cache for user: $userId');
            return UserModel.fromJson(cached);
          }
          final email = session.user.email ?? '';
          final fullName = session.user.userMetadata?['full_name'] as String? ??
              session.user.userMetadata?['name'] as String? ??
              email.split('@')[0];
          return UserModel(
            id: userId,
            email: email,
            fullName: fullName,
            role: 'guru',
          );
        },
        timeout: NetworkResilience.defaultQueryTimeout,
      );
    } catch (e) {
      debugPrint('Error getting current user: $e');
      final session = _supabase.auth.currentSession;
      if (session != null) {
        final cached = await CacheService().loadMap('user_profile_${session.user.id}');
        if (cached != null) {
          return UserModel.fromJson(cached);
        }
      }
      return null;
    }
  }

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) throw Exception('Login gagal');

      final userResponse = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      final user = UserModel.fromJson(userResponse);
      await CacheService().save('user_profile_$userId', user.toJson());
      return user;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Login gagal: $e');
    }
  }

  @override
  Future<UserModel> loginWithGoogle() async {
    try {
      final String redirectTo = kIsWeb
          ? Uri.base.origin
          : 'io.supabase.jurnalmengajar://login-callback';

      if (kIsWeb) {
        // On web: full-page redirect — the browser navigates to Google then
        // comes back to the app Netlify domain. Supabase SDK picks up token on reload.
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectTo,
        );
      } else {
        // On mobile: open Google in external browser and handle via deep link.
        await _supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectTo,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
      }

      // On web the page navigates away here — code below only runs on mobile.
      // The actual session + navigation is handled by onAuthStateChange in AuthProvider.
      return UserModel(id: '', email: '', fullName: '', role: 'guru');
    } catch (e) {
      throw Exception('Login dengan Google gagal: $e');
    }
  }

  @override
  Future<void> register(UserModel user, String password) async {
    try {
      // Check if email already exists in users table first
      Map<String, dynamic>? checkUser;
      try {
        checkUser = await _supabase
            .from('users')
            .select('role')
            .eq('email', user.email)
            .maybeSingle();
      } catch (_) {
        // Ignore RLS check errors and let signUp handle duplicate detection
      }

      if (checkUser != null) {
        final role = checkUser['role'] as String;
        if (role == 'pending_guru') {
          throw Exception('Pendaftaran Guru Anda sedang menunggu persetujuan Admin Sekolah. Silakan hubungi Admin Sekolah Anda untuk konfirmasi.');
        } else if (role == 'pending_admin') {
          throw Exception('Pendaftaran Admin Sekolah Anda sedang menunggu pengaktifan Kode Sekolah dari Superadmin. Silakan hubungi Superadmin.');
        } else {
          throw Exception('Email ini sudah terdaftar.');
        }
      }

      // Check if school exists in schools table, tenants table, or invitations
      String schoolId = user.schoolId ?? '';
      String canonicalSchoolName = user.schoolName ?? '';

      final targetName = (user.schoolName ?? '').toUpperCase().trim();
      final targetId = (user.schoolId ?? '').trim();
      final cleanTargetName = targetName.replaceAll(RegExp(r'[^A-Z0-9]'), '');

      if (targetName.isNotEmpty || targetId.isNotEmpty) {
        Map<String, dynamic>? matchedSchool;

        // 1. Check schools table with comprehensive matching
        try {
          final schoolsRes = await _supabase.from('schools').select('id, name, code, npsn, status, subscription_plan, max_teachers');
          for (final s in (schoolsRes as List)) {
            final sId = ((s['id'] as String?) ?? '').trim();
            final sName = ((s['name'] as String?) ?? '').toUpperCase().trim();
            final sCode = ((s['code'] as String?) ?? '').toUpperCase().trim();
            final sNpsn = ((s['npsn'] as String?) ?? '').toUpperCase().trim();
            final cleanSName = sName.replaceAll(RegExp(r'[^A-Z0-9]'), '');

            if ((targetId.isNotEmpty && sId.toLowerCase() == targetId.toLowerCase()) ||
                (sCode.isNotEmpty && (targetName == sCode || targetId.toUpperCase() == sCode)) ||
                (sNpsn.isNotEmpty && (targetName == sNpsn || targetId.toUpperCase() == sNpsn)) ||
                (sName.isNotEmpty && (targetName == sName || (cleanTargetName.isNotEmpty && cleanSName == cleanTargetName))) ||
                (targetName.length >= 5 && (sName.contains(targetName) || targetName.contains(sName)))) {
              matchedSchool = Map<String, dynamic>.from(s);
              break;
            }
          }
        } catch (e) {
          debugPrint('Note: Error searching schools during register: $e');
        }

        // 2. If not found, check tenants table (from JM-panel)
        if (matchedSchool == null) {
          try {
            Map<String, dynamic>? tenantRes;
            if (targetId.isNotEmpty) {
              tenantRes = await _supabase
                  .from('tenants')
                  .select('id, name, school_code, status')
                  .eq('id', targetId)
                  .maybeSingle();
            }
            if (tenantRes == null && targetName.isNotEmpty) {
              tenantRes = await _supabase
                  .from('tenants')
                  .select('id, name, school_code, status')
                  .or('school_code.ilike.%$targetName%,name.ilike.%$targetName%')
                  .maybeSingle();
            }

            if (tenantRes != null) {
              final tenantId = tenantRes['id'] as String;
              final tenantName = tenantRes['name'] as String? ?? user.schoolName ?? 'Sekolah';
              final tenantStatus = (tenantRes['status'] as String? ?? 'active').toLowerCase();
              final tenantCode = tenantRes['school_code'] as String? ?? tenantId;

              if (tenantStatus == 'inactive') {
                throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator.');
              }

              // Auto-sync into schools table
              try {
                await _supabase.from('schools').upsert({
                  'id': tenantId,
                  'name': tenantName,
                  'code': tenantCode,
                  'status': tenantStatus,
                }, onConflict: 'id');
              } catch (_) {}

              matchedSchool = {
                'id': tenantId,
                'name': tenantName,
                'code': tenantCode,
                'status': tenantStatus,
              };
            }
          } catch (e) {
            if (e.toString().contains('dinonaktifkan')) rethrow;
            debugPrint('Note: Error searching tenants during register: $e');
          }
        }

        // 3. If not found, check school_invitations table
        if (matchedSchool == null && targetId.isNotEmpty) {
          try {
            final inviteRes = await _supabase
                .from('school_invitations')
                .select('*, schools(*)')
                .ilike('code', targetId)
                .maybeSingle();
            if (inviteRes != null && inviteRes['schools'] != null) {
              matchedSchool = Map<String, dynamic>.from(inviteRes['schools'] as Map);
            }
          } catch (_) {}
        }

        if (matchedSchool != null) {
          schoolId = matchedSchool['id'] as String;
          canonicalSchoolName = (matchedSchool['name'] as String?) ?? (user.schoolName ?? '');

          // If Admin is registering with a new JM-Panel plan code for an existing school, upgrade the plan
          if (user.role == 'admin' && targetId.isNotEmpty) {
            final upperCode = targetId.toUpperCase();
            if (upperCode.contains('ENTERPRISE') || upperCode.contains('PRO')) {
              final isEnt = upperCode.contains('ENTERPRISE');
              try {
                await _supabase.from('schools').update({
                  'subscription_plan': isEnt ? 'enterprise' : 'pro',
                  'max_teachers': isEnt ? 999 : 50,
                  'status': 'active',
                }).eq('id', schoolId);
              } catch (_) {}
            }
          }
        } else {
          // Scenario 2: Guru must join an existing school
          if (user.role == 'pending_guru') {
            throw Exception('Kode sekolah tidak ditemukan di sistem. Pastikan Anda memasukkan kode sekolah yang valid dari Admin Sekolah Anda.');
          }

          // Scenario 1: Admin creates (INSERT) a new school with the JM-Panel license code
          final upperCode = targetId.toUpperCase();
          final isEntPlan = upperCode.contains('ENTERPRISE');
          final isProPlan = upperCode.contains('PRO');
          final detectedPlan = isEntPlan ? 'enterprise' : (isProPlan ? 'pro' : 'free');
          final maxTeachers = isEntPlan ? 999 : (isProPlan ? 50 : 30);

          // Check if targetId is already a valid UUID, otherwise generate one
          final uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
          if (targetId.isNotEmpty && uuidPattern.hasMatch(targetId)) {
            schoolId = targetId;
          } else {
            schoolId = const Uuid().v4();
          }

          canonicalSchoolName = (user.schoolName != null && user.schoolName!.trim().isNotEmpty)
              ? user.schoolName!.trim()
              : (targetName.isNotEmpty ? targetName : 'Sekolah');

          try {
            await _supabase.from('schools').upsert({
              'id': schoolId,
              'name': canonicalSchoolName,
              'code': targetId.isNotEmpty ? targetId.trim() : schoolId,
              'status': 'active',
              'subscription_plan': detectedPlan,
              'max_teachers': maxTeachers,
            }, onConflict: 'id');
          } catch (schoolErr) {
            debugPrint('Note: Upserting school during register: $schoolErr');
          }
        }
      }

      // 1. Create auth account with user metadata payload
      final authResponse = await _supabase.auth.signUp(
        email: user.email,
        password: password,
        data: {
          'full_name': user.fullName,
          'role': user.role,
          'phone': user.phoneNumber,
          'phone_number': user.phoneNumber,
          'position': user.position,
          'address': user.address,
          'school_name': canonicalSchoolName.isNotEmpty ? canonicalSchoolName : user.schoolName,
          'schoolName': canonicalSchoolName.isNotEmpty ? canonicalSchoolName : user.schoolName,
          'school': canonicalSchoolName.isNotEmpty ? canonicalSchoolName : user.schoolName,
          'school_id': schoolId.isNotEmpty ? schoolId : null,
          'schoolId': schoolId.isNotEmpty ? schoolId : null,
          'nip': user.nip,
        },
      );

      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Gagal membuat akun');

      // 2. Set profile photo URL if valid remote URL
      String? finalPhotoUrl = user.photoUrl;
      if (finalPhotoUrl != null && !finalPhotoUrl.startsWith('http')) {
        finalPhotoUrl = null;
      }

      // 3. Create or update user profile in database
      final userData = user.copyWith(
        id: userId,
        role: user.role,
        photoUrl: finalPhotoUrl,
        schoolId: schoolId.isNotEmpty ? schoolId : null,
        schoolName: canonicalSchoolName.isNotEmpty ? canonicalSchoolName : user.schoolName,
      ).toJson();
      try {
        await _supabase
            .from('users')
            .upsert(userData, onConflict: 'id');
      } catch (upsertErr) {
        debugPrint('Note: Upserting public.users during registration skipped due to RLS: $upsertErr');
      }

      // 4. Connect user to school in user_schools table & school_memberships
      if (schoolId.isNotEmpty) {
        try {
          // Update users table with resolved school_id and canonical school_name
          await _supabase.from('users').update({
            'school_id': schoolId,
            'school_name': canonicalSchoolName,
            if (user.nip != null && user.nip!.isNotEmpty) 'nip': user.nip,
          }).eq('id', userId);

          // Connect user to school in user_schools table
          await _supabase.from('user_schools').upsert({
            'user_id': userId,
            'school_id': schoolId,
            'role': user.role,
            'status': user.role == 'pending_guru' ? 'pending' : 'active',
          }, onConflict: 'user_id, school_id, role');

          // Multi-tenant membership table
          try {
            await _supabase.from('school_memberships').upsert({
              'user_id': userId,
              'school_id': schoolId,
              'role': user.role == 'pending_guru' ? 'guru' : user.role,
            }, onConflict: 'user_id, school_id');
          } catch (_) {}
        } catch (schoolRelErr) {
          debugPrint('Error inserting user_schools during registration: $schoolRelErr');
        }
      }
    } catch (e) {
      if (e.toString().contains('Pendaftaran Anda sedang menunggu') || 
          e.toString().contains('Email ini sudah terdaftar') ||
          e.toString().contains('dinonaktifkan')) {
        rethrow;
      }
      throw Exception('Registrasi gagal: $e');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      final String redirectTo = kIsWeb
          ? '${Uri.base.origin}/reset-password'
          : 'io.supabase.jurnalmengajar://login-callback/reset-password';

      await _supabase.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
    } catch (e) {
      throw Exception('Email tidak ditemukan atau gagal mengirim reset link!');
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw Exception('Gagal memperbarui kata sandi: $e');
    }
  }

  @override
  Future<void> changeEmail(String newEmail) async {
    try {
      final String redirectTo = kIsWeb
          ? '${Uri.base.origin}/login-callback'
          : 'io.supabase.jurnalmengajar://login-callback';

      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
        emailRedirectTo: redirectTo,
      );
    } catch (e) {
      throw Exception('Gagal mengubah email: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Logout gagal: $e');
    }
  }

  @override
  Future<UserModel> updateProfile(UserModel user) async {
    try {
      final validPhotoUrl = (user.photoUrl != null && user.photoUrl!.startsWith('http'))
          ? user.photoUrl
          : null;

      final Map<String, dynamic> updatePayload = {
        'full_name': user.fullName,
        'phone': user.phoneNumber,
        'position': user.position,
        'address': user.address,
        'photo_url': validPhotoUrl,
        'nip': user.nip,
      };

      if (user.schoolName != null && user.schoolName!.isNotEmpty) {
        updatePayload['school_name'] = user.schoolName;
      }

      await _supabase.from('users').update(updatePayload).eq('id', user.id);

      // Invalidate old caches
      await CacheService().remove('user_profile_${user.id}');
      await CacheService().purgePrefix('teachers_');

      // Get updated data
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      final updated = UserModel.fromJson(response).copyWith(
        status: user.status,
        membershipRole: user.membershipRole,
      );
      await CacheService().save('user_profile_${user.id}', updated.toCacheJson());
      return updated;
    } catch (e) {
      throw Exception('Gagal memperbarui profil: $e');
    }
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _supabase
          .from('users')
          .select()
          .order('full_name', ascending: true);

      return (response as List)
          .map((json) => UserModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat semua pengguna: $e');
    }
  }

  @override
  Future<List<UserModel>> getAllUsersForSchool(String schoolId) async {
    try {
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId.trim();
      if (cleanSchoolId.isEmpty) return [];

      // 1, 2, 3. Fetch school info, user_schools memberships, and primary users in parallel
      String schoolName = '';
      final Map<String, List<Map<String, dynamic>>> membershipsByUser = {};
      final Set<String> targetUserIds = <String>{};

      final results = await Future.wait([
        _supabase
            .from('schools')
            .select('name')
            .eq('id', cleanSchoolId)
            .maybeSingle()
            .timeout(const Duration(seconds: 12))
            .catchError((_) => null),
        _supabase
            .from('user_schools')
            .select('id, user_id, school_id, role, status')
            .eq('school_id', cleanSchoolId)
            .inFilter('status', ['active', 'pending', 'requested_exit'])
            .timeout(const Duration(seconds: 12))
            .catchError((err) {
              debugPrint('Error fetching user_schools in getAllUsersForSchool: $err');
              return <Map<String, dynamic>>[];
            }),
        _supabase
            .from('users')
            .select('id')
            .eq('school_id', cleanSchoolId)
            .timeout(const Duration(seconds: 12))
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);

      final schoolRes = results[0] as Map<String, dynamic>?;
      if (schoolRes != null) {
        schoolName = (schoolRes['name'] as String? ?? '').trim();
      }

      final userSchoolsRes = results[1] as List;
      for (final row in userSchoolsRes) {
        final m = Map<String, dynamic>.from(row as Map);
        final uid = m['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) {
          membershipsByUser.putIfAbsent(uid, () => []).add(m);
          targetUserIds.add(uid);
        }
      }

      final primaryUsersRes = results[2] as List;
      for (final row in primaryUsersRes) {
        final uid = (row as Map)['id']?.toString();
        if (uid != null && uid.isNotEmpty) {
          targetUserIds.add(uid);
        }
      }

      if (targetUserIds.isEmpty) return [];

      // 4. Query users strictly scoped to targetUserIds
      final usersRes = await _supabase
          .from('users')
          .select()
          .inFilter('id', targetUserIds.toList())
          .order('full_name', ascending: true)
          .timeout(const Duration(seconds: 12));

      final List<UserModel> result = [];

      for (final item in (usersRes as List)) {
        try {
          final json = Map<String, dynamic>.from(item as Map);
          final uid = json['id']?.toString() ?? '';
          final userMems = membershipsByUser[uid] ?? [];

          if (userMems.isEmpty) {
            final baseRole = json['role']?.toString().toLowerCase() ?? 'guru';
            final userModel = UserModel.fromJson({
              ...json,
              'role': baseRole,
              'status': baseRole == 'pending_guru' ? 'pending' : 'active',
              'school_id': cleanSchoolId,
              'school_name': schoolName.isNotEmpty ? schoolName : json['school_name'],
            });
            result.add(userModel);
            continue;
          }

          // 1. Emit pending memberships (so admin sees join requests for both Guru and Admin Cadangan)
          final pendingMems = userMems.where((m) => (m['status']?.toString().toLowerCase() == 'pending')).toList();
          for (final pMem in pendingMems) {
            final pRole = pMem['role']?.toString() ?? 'guru';
            result.add(UserModel.fromJson({
              ...json,
              'role': pRole,
              'membership_role': pRole,
              'status': 'pending',
              'school_id': cleanSchoolId,
              'school_name': schoolName.isNotEmpty ? schoolName : json['school_name'],
            }));
          }

          // 2. Emit active membership for the active users tab
          final activeMems = userMems.where((m) => (m['status']?.toString().toLowerCase() == 'active')).toList();
          if (activeMems.isNotEmpty) {
            final hasAdmin = activeMems.any((m) => m['role']?.toString().toLowerCase() == 'admin');
            final effectiveRole = hasAdmin ? 'admin' : (activeMems.first['role']?.toString() ?? 'guru');
            result.add(UserModel.fromJson({
              ...json,
              'role': effectiveRole,
              'membership_role': effectiveRole,
              'status': 'active',
              'school_id': cleanSchoolId,
              'school_name': schoolName.isNotEmpty ? schoolName : json['school_name'],
            }));
          }
        } catch (_) {}
      }

      result.sort((a, b) => a.fullName.compareTo(b.fullName));
      return result;
    } catch (e) {
      debugPrint('Error in getAllUsersForSchool: $e');
      return [];
    }
  }

  @override
  Future<void> updateUserRole(String userId, String role, [String? schoolId]) async {
    try {
      final cleanSchoolId = (schoolId != null && schoolId.isNotEmpty)
          ? (AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId.trim())
          : null;

      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        final normalizedRole = role.toLowerCase();
        if (normalizedRole == 'admin') {
          // Promoting or activating as Admin Cadangan in this school
          final existingAdminList = await _supabase
              .from('user_schools')
              .select('id')
              .eq('user_id', userId)
              .eq('school_id', cleanSchoolId)
              .eq('role', 'admin');

          if ((existingAdminList as List).isNotEmpty) {
            await _supabase
                .from('user_schools')
                .update({
                  'status': 'active',
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', (existingAdminList as List).first['id']);
          } else {
            await _supabase.from('user_schools').insert({
              'user_id': userId,
              'school_id': cleanSchoolId,
              'role': 'admin',
              'status': 'active',
            });
          }
        } else {
          // Setting or activating as 'guru'
          final existingGuruList = await _supabase
              .from('user_schools')
              .select('id')
              .eq('user_id', userId)
              .eq('school_id', cleanSchoolId)
              .eq('role', 'guru');

          if ((existingGuruList as List).isNotEmpty) {
            await _supabase
                .from('user_schools')
                .update({
                  'status': 'active',
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', (existingGuruList as List).first['id']);
          } else {
            await _supabase.from('user_schools').insert({
              'user_id': userId,
              'school_id': cleanSchoolId,
              'role': 'guru',
              'status': 'active',
            });
          }

          // If revoking admin role in this school (demoting back to pure guru), deactivate admin membership
          await _supabase
              .from('user_schools')
              .update({
                'status': 'inactive',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId)
              .eq('school_id', cleanSchoolId)
              .eq('role', 'admin');
        }
      }

      // Also update base user if user was pending
      final userRes = await _supabase
          .from('users')
          .select('role, school_id')
          .eq('id', userId)
          .maybeSingle();

      if (userRes != null) {
        final currentRole = userRes['role']?.toString().toLowerCase();
        if (currentRole == 'pending_guru') {
          final userUpdate = <String, dynamic>{'role': 'guru'};
          if (cleanSchoolId != null && (userRes['school_id'] == null || (userRes['school_id'] as String).isEmpty)) {
            userUpdate['school_id'] = cleanSchoolId;
          }
          await _supabase.from('users').update(userUpdate).eq('id', userId);
        }
      }
    } catch (e) {
      throw Exception('Gagal memperbarui peran pengguna: $e');
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    try {
      // Periksa apakah akun adalah admin sekolah atau memiliki peran admin
      final userRes = await _supabase
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      if (userRes != null && userRes['role'] == 'admin') {
        throw Exception('Akun admin sekolah dilindungi sistem dan tidak dapat dihapus.');
      }

      final schoolAdminRes = await _supabase
          .from('user_schools')
          .select('id')
          .eq('user_id', userId)
          .eq('role', 'admin')
          .limit(1);
      if (schoolAdminRes.isNotEmpty) {
        throw Exception('Akun admin sekolah dilindungi sistem dan tidak dapat dihapus.');
      }

      // Bersihkan data relasi sekolah terlebih dahulu agar tidak terganjal foreign key constraint
      try {
        await _supabase.from('user_schools').delete().eq('user_id', userId);
      } catch (_) {}
      try {
        await _supabase.from('school_memberships').delete().eq('user_id', userId);
      } catch (_) {}

      await _supabase.from('users').delete().eq('id', userId);
    } catch (e) {
      throw Exception('Gagal menghapus akun: $e');
    }
  }

  /// Upload foto profil ke Supabase Storage dan kembalikan public URL.
  /// Web-compatible: menerima bytes bukan File.
  Future<String> uploadProfilePhoto(
    List<int> imageBytes,
    String fileName,
    String userId,
  ) async {
    try {
      // Compress to WebP before uploading
      final compressed = await ImageCompressor.compressToWebp(
        bytes: imageBytes,
        originalFileName: fileName,
      );

      final ext = compressed.fileName.contains('.') ? compressed.fileName.split('.').last : 'webp';
      final filePath = 'avatars/$userId/profile.$ext';

      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            compressed.bytes,
            fileOptions: const FileOptions(cacheControl: '0', upsert: true),
          );

      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);

      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      return '$publicUrl?t=$cacheBuster';
    } catch (e) {
      throw Exception('Gagal mengunggah foto profil: $e');
    }
  }

  @override
  Future<void> updateFcmToken(String userId, String token) async {
    try {
      await _supabase
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
    } catch (e) {
      // Non-blocking log if token update fails
      debugPrint('Gagal memperbarui FCM Token: $e');
    }
  }

  @override
  Future<void> requestExitFromSchool(String membershipId, {String? schoolId, String? role, String? userId}) async {
    try {
      final cleanSchoolId = schoolId != null ? (AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId) : null;
      bool updated = false;

      // Only attempt update by ID if it's a real record ID (not a synthetic fallback ID like us_xxx)
      if (membershipId.isNotEmpty && !membershipId.startsWith('us_')) {
        final res = await _supabase
            .from('user_schools')
            .update({'status': 'requested_exit'})
            .eq('id', membershipId)
            .select('id');
        if ((res as List).isNotEmpty) {
          updated = true;
        }
      }

      // Fallback: update by userId and schoolId
      if (!updated && cleanSchoolId != null && userId != null) {
        var query = _supabase
            .from('user_schools')
            .update({'status': 'requested_exit'})
            .eq('user_id', userId)
            .eq('school_id', cleanSchoolId);
        if (role != null) {
          query = query.eq('role', role);
        }
        final res = await query.select('id');
        if ((res as List).isEmpty) {
          // If row doesn't exist yet in user_schools, insert/upsert it
          await _supabase.from('user_schools').upsert({
            'user_id': userId,
            'school_id': cleanSchoolId,
            'role': role ?? 'guru',
            'status': 'requested_exit',
          }, onConflict: 'user_id, school_id, role');
        }
      }
    } catch (e) {
      throw Exception('Gagal mengajukan keluar: $e');
    }
  }

  @override
  Future<void> cancelExitRequest(String membershipId, {String? schoolId, String? role, String? userId}) async {
    try {
      final cleanSchoolId = schoolId != null ? (AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId) : null;
      bool updated = false;

      if (membershipId.isNotEmpty && !membershipId.startsWith('us_')) {
        final res = await _supabase
            .from('user_schools')
            .update({'status': 'active'})
            .eq('id', membershipId)
            .select('id');
        if ((res as List).isNotEmpty) {
          updated = true;
        }
      }

      if (!updated && cleanSchoolId != null && userId != null) {
        var query = _supabase
            .from('user_schools')
            .update({'status': 'active'})
            .eq('user_id', userId)
            .eq('school_id', cleanSchoolId);
        if (role != null) {
          query = query.eq('role', role);
        }
        await query;
      }
    } catch (e) {
      throw Exception('Gagal membatalkan pengajuan: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingExitRequests(String schoolId) async {
    try {
      final res = await _supabase
          .from('user_schools')
          .select('*, users(full_name, email, photo_url)')
          .eq('school_id', schoolId)
          .eq('status', 'requested_exit')
          .timeout(const Duration(seconds: 12));
      
      return (res as List).map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      debugPrint('Error getting pending exit requests: $e');
      return [];
    }
  }

  @override
  Future<void> approveExitRequest(String membershipId) async {
    try {
      // 1. Fetch membership details before updating
      final membership = await _supabase
          .from('user_schools')
          .select('user_id, school_id, role')
          .eq('id', membershipId)
          .maybeSingle();

      // 2. Deactivate membership in user_schools (do NOT delete data!)
      await _supabase
          .from('user_schools')
          .update({
            'status': 'inactive',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', membershipId);

      // 3. Update users table: clean school_ids and fallback active school
      if (membership != null) {
        final uId = membership['user_id'] as String;
        final sId = membership['school_id'] as String;

        final remaining = await _supabase
            .from('user_schools')
            .select('id, school_id, role, schools(name)')
            .eq('user_id', uId)
            .eq('status', 'active');

        final remList = (remaining as List);
        final stillInThisSchool = remList.where((m) => m['school_id'] == sId).toList();
        final remainingSchoolIds = remList
            .map((r) => r['school_id']?.toString())
            .whereType<String>()
            .where((id) => id != sId)
            .toSet()
            .toList();

        final updates = <String, dynamic>{
          'school_ids': remainingSchoolIds,
        };

        if (stillInThisSchool.isEmpty) {
          // User completely exited this school
          if (remList.isNotEmpty) {
            final next = remList.first;
            updates['school_id'] = next['school_id'];
            if (next['schools'] != null && next['schools'] is Map) {
              updates['school_name'] = next['schools']['name'];
            }
            if (next['role'] != null) {
              updates['role'] = next['role'];
            }
          } else {
            updates['school_id'] = null;
            updates['school_name'] = null;
          }
        } else {
          final nextRole = stillInThisSchool.first['role'] as String;
          updates['role'] = nextRole;
        }

        await _supabase.from('users').update(updates).eq('id', uId);
      }
    } catch (e) {
      throw Exception('Gagal menyetujui pengajuan keluar: $e');
    }
  }

  @override
  Future<void> rejectExitRequest(String membershipId) async {
    try {
      await _supabase
          .from('user_schools')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', membershipId);
    } catch (e) {
      throw Exception('Gagal menolak pengajuan keluar: $e');
    }
  }

  @override
  Future<void> rejectJoinRequest(String userId, String schoolId) async {
    try {
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId.trim();
      
      // 1. Check existing memberships for this user to determine if they belong to other schools
      final userSchools = await _supabase
          .from('user_schools')
          .select('id, school_id, status')
          .eq('user_id', userId);

      final schoolRows = (userSchools as List);
      final hasOtherActiveSchools = schoolRows.any(
        (row) => row['school_id'] != cleanSchoolId && (row['status'] == 'active' || row['status'] == null)
      );

      // 2. Remove the pending membership from user_schools for this specific school
      await _supabase
          .from('user_schools')
          .delete()
          .eq('user_id', userId)
          .eq('school_id', cleanSchoolId)
          .eq('status', 'pending');

      // Multi-tenant membership table cleanup if exists
      try {
        await _supabase
            .from('school_memberships')
            .delete()
            .eq('user_id', userId)
            .eq('school_id', cleanSchoolId);
      } catch (_) {}

      // 3. Only delete account from users table if user has no other active schools
      // AND their base role is 'pending_guru' (new user who registered and was rejected on first school)
      if (!hasOtherActiveSchools) {
        final userRes = await _supabase
            .from('users')
            .select('role, school_id')
            .eq('id', userId)
            .maybeSingle();

        if (userRes != null && userRes['role']?.toString().toLowerCase() == 'pending_guru') {
          await _supabase.from('users').delete().eq('id', userId);
        }
      }
    } catch (e) {
      throw Exception('Gagal menolak permintaan bergabung: $e');
    }
  }

  @override
  Future<void> leaveSchool({required String schoolId, required String userId, String? membershipId}) async {
    try {
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId.trim();

      final currentAuthUserId = _supabase.auth.currentUser?.id;
      final isSelf = currentAuthUserId == null || currentAuthUserId == userId;

      // 1. Try atomic PostgreSQL leave_school RPC first (only if self-leaving)
      bool rpcSucceeded = false;
      if (isSelf) {
        try {
          final rpcRes = await _supabase.rpc('leave_school', params: {
            'p_school_id': cleanSchoolId,
          });
          if (rpcRes != null) {
            rpcSucceeded = true;
          }
        } catch (rpcErr) {
          debugPrint('leave_school RPC note (falling back to direct update): $rpcErr');
        }
      }

      // 2. Direct fallback update if RPC was not used or failed
      if (!rpcSucceeded) {
        if (membershipId != null && membershipId.isNotEmpty) {
          await _supabase
              .from('user_schools')
              .update({
                'status': 'inactive',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', membershipId)
              .eq('user_id', userId);
        } else {
          await _supabase
              .from('user_schools')
              .update({
                'status': 'inactive',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId)
              .eq('school_id', cleanSchoolId);
        }

        // Fetch remaining active schools for user
        final remainingRes = await _supabase
            .from('user_schools')
            .select('school_id, role, schools(name)')
            .eq('user_id', userId)
            .eq('status', 'active');

        final remainingList = (remainingRes as List);
        final remainingActiveList = remainingList
            .where((r) => (AppHelper.parseSingleCleanSchoolId(r['school_id']) ?? r['school_id']) != cleanSchoolId)
            .toList();

        final remainingSchoolIds = remainingActiveList
            .map((r) => (AppHelper.parseSingleCleanSchoolId(r['school_id']) ?? r['school_id']?.toString()))
            .whereType<String>()
            .toSet()
            .toList();

        // Update users table
        final userRow = await _supabase
            .from('users')
            .select('school_id, school_ids')
            .eq('id', userId)
            .maybeSingle();

        if (userRow != null) {
          final currentAssignedSchoolId = AppHelper.parseSingleCleanSchoolId(userRow['school_id']);
          final updates = <String, dynamic>{
            'school_ids': remainingSchoolIds,
          };

          if (currentAssignedSchoolId == cleanSchoolId) {
            if (remainingActiveList.isNotEmpty) {
              final next = remainingActiveList.first;
              final nextId = AppHelper.parseSingleCleanSchoolId(next['school_id']) ?? next['school_id'];
              updates['school_id'] = nextId;
              if (next['schools'] != null && next['schools'] is Map) {
                updates['school_name'] = next['schools']['name'];
              }
              if (next['role'] != null) {
                updates['role'] = next['role'];
              }
            } else {
              updates['school_id'] = null;
              updates['school_name'] = null;
            }
          }

          await _supabase.from('users').update(updates).eq('id', userId);
        }
      }
    } catch (e) {
      throw Exception('Gagal keluar dari sekolah: $e');
    }
  }
}
