import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subject_model.dart';
import 'subject_repository.dart';

class SupabaseSubjectRepository implements SubjectRepository {
  final SupabaseClient _supabase;

  SupabaseSubjectRepository(this._supabase);

  @override
  Future<List<SubjectModel>> getAll() async {
    try {
      final response = await _supabase
          .from('subjects')
          .select()
          .order('name', ascending: true);

      return (response as List)
          .map((json) => SubjectModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat mata pelajaran: $e');
    }
  }

  @override
  Future<void> create(SubjectModel model) async {
    try {
      await _supabase.from('subjects').insert(model.toJson());
    } catch (e) {
      throw Exception('Gagal menambah mata pelajaran: $e');
    }
  }

  @override
  Future<void> update(SubjectModel model) async {
    try {
      await _supabase
          .from('subjects')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui mata pelajaran: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('subjects').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus mata pelajaran: $e');
    }
  }
}
