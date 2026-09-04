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
      final Map<String, TeacherModel> teachersMap = {};

      // 1. Fetch user IDs linked in user_schools for this school
      try {
        final userSchoolsRes = await _supabase
            .from('user_schools')
            .select('user_id')
            .eq('school_id', schoolId);

        final userIds = (userSchoolsRes as List)
            .map((row) => row['user_id'] as String)
            .toList();

        if (userIds.isNotEmpty) {
          final res = await _supabase
              .from('users')
              .select()
              .eq('role', 'guru')
              .inFilter('id', userIds)
              .order('full_name', ascending: true);
          for (final json in (res as List)) {
            teachersMap[json['id'] as String] = TeacherModel(
              id: json['id'] as String,
              name: json['full_name'] as String,
              position: json['position'] as String? ?? 'Guru Bidang Studi',
              address: json['address'] as String? ?? '',
              phoneNumber: json['phone'] as String? ?? '',
              email: json['email'] as String,
              photoUrl: json['photo_url'] as String?,
            );
          }
        }
      } catch (_) {}

      // 2. Fetch users with school_id = schoolId directly
      try {
        final resDirect = await _supabase
            .from('users')
            .select()
            .eq('role', 'guru')
            .eq('school_id', schoolId)
            .order('full_name', ascending: true);
        for (final json in (resDirect as List)) {
          teachersMap[json['id'] as String] = TeacherModel(
            id: json['id'] as String,
            name: json['full_name'] as String,
            position: json['position'] as String? ?? 'Guru Bidang Studi',
            address: json['address'] as String? ?? '',
            phoneNumber: json['phone'] as String? ?? '',
            email: json['email'] as String,
            photoUrl: json['photo_url'] as String?,
          );
        }
      } catch (_) {}

      final result = teachersMap.values.toList();
      result.sort((a, b) => a.name.compareTo(b.name));
      return result;
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
