import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_model.dart';
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
          .eq('role', 'guru')
          .order('full_name', ascending: true);

      return (response as List)
          .map((json) => TeacherModel(
                id: json['id'] as String,
                name: json['full_name'] as String,
                position: json['position'] as String? ?? 'Guru Bidang Studi',
                address: json['address'] as String? ?? '',
                phoneNumber: json['phone'] as String? ?? '',
                email: json['email'] as String,
                photoUrl: json['photo_url'] as String?,
              ))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat data guru: $e');
    }
  }

  @override
  Future<List<TeacherModel>> getAllForSchool(String schoolId) async {
    if (schoolId.isEmpty) return [];
    try {
      // 1. Query user_schools for userIds belonging to this schoolId
      List<String> userIds = [];
      try {
        final userSchoolsRes = await _supabase
            .from('user_schools')
            .select('user_id')
            .eq('school_id', schoolId);

        userIds = (userSchoolsRes as List)
            .map((row) => row['user_id'] as String)
            .toList();
      } catch (_) {}

      // 2. Query users where role = 'guru' AND belonging to schoolId
      List<dynamic> response = [];
      if (userIds.isNotEmpty) {
        final res = await _supabase
            .from('users')
            .select()
            .eq('role', 'guru')
            .or('id.in.(${userIds.join(",")})')
            .order('full_name', ascending: true);
        response = res as List;
      } else {
        try {
          final res = await _supabase
              .from('users')
              .select()
              .eq('role', 'guru')
              .or('school_id.ilike.%$schoolId%,school_ids.cs.{"$schoolId"}')
              .order('full_name', ascending: true);
          response = res as List;
        } catch (_) {
          try {
            final res = await _supabase
                .from('users')
                .select()
                .eq('role', 'guru')
                .eq('school_id', schoolId)
                .order('full_name', ascending: true);
            response = res as List;
          } catch (_) {
            response = [];
          }
        }
      }

      return response
          .map((json) => TeacherModel(
                id: json['id'] as String,
                name: json['full_name'] as String,
                position: json['position'] as String? ?? 'Guru Bidang Studi',
                address: json['address'] as String? ?? '',
                phoneNumber: json['phone'] as String? ?? '',
                email: json['email'] as String,
                photoUrl: json['photo_url'] as String?,
              ))
          .toList();
    } catch (e) {
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
}
