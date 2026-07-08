import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/warning_letter_model.dart';
import 'warning_letter_repository.dart';

class SupabaseWarningLetterRepository implements WarningLetterRepository {
  final SupabaseClient _supabase;

  SupabaseWarningLetterRepository(this._supabase);

  @override
  Future<List<WarningLetterModel>> getAll() async {
    try {
      final response = await _supabase
          .from('warning_letters')
          .select()
          .order('issued_at', ascending: false);

      return (response as List)
          .map((json) => WarningLetterModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat surat peringatan: $e');
    }
  }

  @override
  Future<List<WarningLetterModel>> getByTeacherId(String teacherId) async {
    try {
      final response = await _supabase
          .from('warning_letters')
          .select()
          .eq('teacher_id', teacherId)
          .order('issued_at', ascending: false);

      return (response as List)
          .map((json) => WarningLetterModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat surat peringatan guru: $e');
    }
  }

  @override
  Future<void> create(WarningLetterModel model) async {
    try {
      await _supabase.from('warning_letters').insert(model.toJson());
    } catch (e) {
      // Ignore duplicate warnings or constraints
      if (e.toString().contains('duplicate key value') || e.toString().contains('23505')) {
        return;
      }
      throw Exception('Gagal membuat surat peringatan: $e');
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await _supabase
          .from('warning_letters')
          .update({'status': 'read'})
          .eq('id', id);
    } catch (e) {
      throw Exception('Gagal mengubah status surat peringatan: $e');
    }
  }
}
