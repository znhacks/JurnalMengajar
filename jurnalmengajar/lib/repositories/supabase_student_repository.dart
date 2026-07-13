import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/student_model.dart';
import 'student_repository.dart';

const _uuid = Uuid();

class SupabaseStudentRepository implements StudentRepository {
  final SupabaseClient _supabase;

  SupabaseStudentRepository(this._supabase);

  @override
  Future<List<StudentModel>> getAllByClass(String classId) async {
    try {
      final response = await _supabase
          .from('students')
          .select()
          .eq('class_id', classId)
          .order('name', ascending: true);

      return (response as List)
          .map((json) => StudentModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat siswa: $e');
    }
  }

  @override
  Future<void> create(StudentModel model) async {
    try {
      final payload = model.toJson();
      if (payload['id'] == null || (payload['id'] as String).isEmpty) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('students').insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah siswa: $e');
    }
  }

  @override
  Future<void> update(StudentModel model) async {
    try {
      await _supabase
          .from('students')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui siswa: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('students').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus siswa: $e');
    }
  }
}
