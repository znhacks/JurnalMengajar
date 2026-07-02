import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

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
          role: 'guru', // All Google sign-ins default to guru
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
          ? Uri
                .base
                .origin // e.g. "http://localhost:52512"
          : 'io.supabase.jurnalmengajar://login-callback';

      if (kIsWeb) {
        // On web: full-page redirect — the browser navigates to Google then
        // comes back to the app URL. Supabase SDK picks up the token on reload.
        // No authScreenLaunchMode needed (omitting it = default browser redirect).
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
      // 1. Create auth account
      final authResponse = await _supabase.auth.signUp(
        email: user.email,
        password: password,
      );

      final userId = authResponse.user?.id;
      if (userId == null) throw Exception('Gagal membuat akun');

      // 2. Create user in database
      final userData = user.copyWith(id: userId).toJson();
      await _supabase.from('users').insert(userData);
    } catch (e) {
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
  Future<void> updateUserRole(String userId, String role) async {
    try {
      await _supabase.from('users').update({'role': role}).eq('id', userId);
    } catch (e) {
      throw Exception('Gagal memperbarui peran pengguna: $e');
    }
  }

  @override
  Future<void> deleteAccount(String userId) async {
    try {
      await _supabase.from('users').delete().eq('id', userId);
      await logout();
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
      final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
      final filePath = 'avatars/$userId/profile.$ext';

      await _supabase.storage
          .from('avatars')
          .uploadBinary(
            filePath,
            Uint8List.fromList(imageBytes),
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final publicUrl = _supabase.storage
          .from('avatars')
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Gagal mengunggah foto profil: $e');
    }
  }
}
