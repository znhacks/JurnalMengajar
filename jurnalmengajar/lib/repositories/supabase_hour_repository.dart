import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hour_model.dart';
import 'hour_repository.dart';

class SupabaseHourRepository implements HourRepository {
  final SupabaseClient _supabase;

  SupabaseHourRepository(this._supabase);

  @override
  Future<List<HourModel>> getAll() async {
    try {
      final response = await _supabase
          .from('lesson_hours')
          .select()
          .order('teaching_hour', ascending: true);

      return (response as List)
          .map((json) => HourModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat jam pelajaran: $e');
    }
  }

  @override
  Future<void> create(HourModel model) async {
    try {
      await _supabase.from('lesson_hours').insert(model.toJson());
    } catch (e) {
      throw Exception('Gagal menambah jam pelajaran: $e');
    }
  }

  @override
  Future<void> update(HourModel model) async {
    try {
      await _supabase
          .from('lesson_hours')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui jam pelajaran: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('lesson_hours').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus jam pelajaran: $e');
    }
  }
}
