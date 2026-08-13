import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';
import '../core/utils/image_compressor.dart';

const _uuid = Uuid();

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabase;

  SupabaseAuthRepository(this._supabase);

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return null;

      final userId = session.user.id;

      // Try fetching existing profile first
      var response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        // No profile yet — create one (Google OAuth first-time login).
        // Use upsert with ignoreDuplicates so that even if two concurrent
        // calls race here, only one insert wins and no exception is thrown.
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
          role: 'pending_guru', // All Google sign-ins default to pending_guru
          photoUrl: photoUrl,
          phoneNumber: phone,
        );

        await _supabase
            .from('users')
            .upsert(newUser.toJson(), onConflict: 'id', ignoreDuplicates: true);

        // Always fetch the stored record — in case another concurrent call
        // already inserted (and possibly with different data).
        response = await _supabase
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();

        // If still null for some reason, return the locally-built model
        if (response == null) return newUser;
      }

      return UserModel.fromJson(response);
    } catch (e) {
      // Log but do not rethrow — returning null causes login screen to show.
      // We swallow so _initialized is still set to true and the router can decide.
      debugPrint('Error getting current user: $e');
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

      return UserModel.fromJson(userResponse);
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
          'school_name': user.schoolName,
          'schoolName': user.schoolName,
          'school': user.schoolName,
        },
      );

      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Gagal membuat akun');

      // 2. Upload profile photo if provided and is a local file path
      String? finalPhotoUrl = user.photoUrl;
      if (finalPhotoUrl != null &&
          finalPhotoUrl.isNotEmpty &&
          !finalPhotoUrl.startsWith('http')) {
        try {
          final file = File(finalPhotoUrl);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final fileName = finalPhotoUrl.split('/').last;
            finalPhotoUrl = await uploadProfilePhoto(bytes, fileName, userId);
          }
        } catch (uploadError) {
          debugPrint('Error uploading profile photo during registration: $uploadError');
          finalPhotoUrl = null;
        }
      }

      // 3. Create or update user profile in database
      final userData = user.copyWith(
        id: userId,
        role: user.role,
        photoUrl: finalPhotoUrl,
      ).toJson();
      try {
        await _supabase
            .from('users')
            .upsert(userData, onConflict: 'id');
      } catch (upsertErr) {
        debugPrint('Note: Upserting public.users during registration skipped due to RLS: $upsertErr');
      }

      // 4. Connect user to school in user_schools table
      if (user.schoolName != null && user.schoolName!.isNotEmpty) {
        try {
          // Find matching school by code, npsn, or name
          final schoolsRes = await _supabase.from('schools').select('id, name, code, npsn');
          Map<String, dynamic>? matchedSchool;
          final target = user.schoolName!.toUpperCase().trim();

          for (final s in (schoolsRes as List)) {
            final sName = ((s['name'] as String?) ?? '').toUpperCase().trim();
            final sCode = ((s['code'] as String?) ?? '').toUpperCase().trim();
            final sNpsn = ((s['npsn'] as String?) ?? '').toUpperCase().trim();

            if ((sCode.isNotEmpty && target == sCode) ||
                (sNpsn.isNotEmpty && target == sNpsn) ||
                (sName.isNotEmpty && target == sName)) {
              matchedSchool = Map<String, dynamic>.from(s);
              break;
            }
          }

          String schoolId;
          String canonicalSchoolName = user.schoolName!;
          if (matchedSchool != null) {
            schoolId = matchedSchool['id'] as String;
            canonicalSchoolName = (matchedSchool['name'] as String?) ?? user.schoolName!;
          } else {
            // Auto create new school entry if school code/name does not exist yet
            final newSchoolId = _uuid.v4();
            final schoolInsert = {
              'id': newSchoolId,
              'name': user.schoolName,
              'code': target,
            };
            final insertedSchool = await _supabase
                .from('schools')
                .insert(schoolInsert)
                .select('id')
                .single();
            schoolId = insertedSchool['id'] as String;
          }

          // Update users table with resolved school_id and canonical school_name
          await _supabase.from('users').update({
            'school_id': schoolId,
            'school_name': canonicalSchoolName,
          }).eq('id', userId);

          // Connect user to school in user_schools table
          await _supabase.from('user_schools').upsert({
            'user_id': userId,
            'school_id': schoolId,
            'role': user.role,
          });
        } catch (schoolRelErr) {
          debugPrint('Error inserting user_schools during registration: $schoolRelErr');
        }
      }
    } catch (e) {
      if (e.toString().contains('Pendaftaran Anda sedang menunggu') || e.toString().contains('Email ini sudah terdaftar')) {
        rethrow;
      }
      throw Exception('Registrasi gagal: $e');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      // Always redirect back into the app via the registered custom scheme.
      // On Android the OS intercepts this URL and opens the app via the intent
      // filter registered in AndroidManifest.xml. Avoid using Uri.base.origin
      // because during development that resolves to http://localhost:<port>,
      // which would cause the reset link in the email to open the desktop browser
      // instead of the mobile app.
      const redirectTo = 'io.supabase.jurnalmengajar://login-callback/reset-password';

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
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail),
        emailRedirectTo: 'io.supabase.jurnalmengajar://login-callback',
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
      await _supabase.from('users').update(user.toJson()).eq('id', user.id);

      // Get updated data
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson(response);
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
      // 1. Fetch school info to get school name
      String schoolName = '';
      try {
        final schoolRes = await _supabase
            .from('schools')
            .select('name')
            .eq('id', schoolId)
            .maybeSingle();
        if (schoolRes != null) {
          schoolName = (schoolRes['name'] as String? ?? '').trim();
        }
      } catch (_) {}

      // 2. Fetch user IDs linked in user_schools
      Set<String> userIds = {};
      try {
        final userSchoolsRes = await _supabase
            .from('user_schools')
            .select('user_id')
            .eq('school_id', schoolId);

        userIds = (userSchoolsRes as List)
            .map((row) => row['user_id'] as String)
            .toSet();
      } catch (_) {}

      // 3. Query users safely without PostgREST string syntax errors
      final Map<String, UserModel> usersMap = {};

      // Query A: users matching school_id
      try {
        final res1 = await _supabase
            .from('users')
            .select()
            .eq('school_id', schoolId)
            .order('full_name', ascending: true);
        for (final json in (res1 as List)) {
          final u = UserModel.fromJson(json);
          usersMap[u.id] = u;
        }
      } catch (e) {
        debugPrint('Note: querying users by school_id: $e');
      }

      // Query B: users matching userIds from user_schools
      if (userIds.isNotEmpty) {
        try {
          final res2 = await _supabase
              .from('users')
              .select()
              .or('id.in.(${userIds.join(",")})')
              .order('full_name', ascending: true);
          for (final json in (res2 as List)) {
            final u = UserModel.fromJson(json);
            usersMap[u.id] = u;
          }
        } catch (e) {
          debugPrint('Note: querying users by userIds: $e');
        }
      }

      // Query C: users matching school_name if available
      if (schoolName.isNotEmpty) {
        try {
          final res3 = await _supabase
              .from('users')
              .select()
              .eq('school_name', schoolName)
              .order('full_name', ascending: true);
          for (final json in (res3 as List)) {
            final u = UserModel.fromJson(json);
            usersMap[u.id] = u;
          }
        } catch (e) {
          debugPrint('Note: querying users by school_name: $e');
        }
      }

      final result = usersMap.values.toList();
      result.sort((a, b) => a.fullName.compareTo(b.fullName));
      return result;
    } catch (e) {
      debugPrint('Error in getAllUsersForSchool: $e');
      return [];
    }
  }

  @override
  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _supabase.from('users').update({'role': role}).eq('id', userId);
      try {
        await _supabase.from('user_schools').update({'role': role}).eq('user_id', userId);
      } catch (_) {}
    } catch (e) {
      throw Exception('Gagal memperbarui peran pengguna: $e');
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    try {
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
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
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
}
