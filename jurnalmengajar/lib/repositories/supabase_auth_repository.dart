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
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error getting current user: $e');
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
      // For mobile/web OAuth, you need to set up OAuth redirect in Supabase
      // This is a placeholder - actual implementation depends on platform
      throw Exception('Login dengan Google belum dikonfigurasi');
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
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('Email tidak ditemukan atau gagal mengirim reset link!');
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
      await _supabase
          .from('users')
          .update(user.toJson())
          .eq('id', user.id);

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
}
