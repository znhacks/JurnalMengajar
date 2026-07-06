import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/class_model.dart';
import 'class_repository.dart';

const _uuid = Uuid();

class SupabaseClassRepository implements ClassRepository {
  final SupabaseClient _supabase;

  SupabaseClassRepository(this._supabase);

  @override
  Future<List<ClassModel>> getAll() async {
    try {
      final response = await _supabase
          .from('classes')
          .select()
          .order('name', ascending: true);

      return (response as List)
          .map((json) => ClassModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat kelas: $e');
    }
  }

  @override
  Future<void> create(ClassModel model) async {
    try {
      final payload = model.toJson();
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('classes').insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah kelas: $e');
    }
  }

  @override
  Future<void> update(ClassModel model) async {
    try {
      await _supabase
          .from('classes')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui kelas: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('classes').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus kelas: $e');
    }
  }
}
