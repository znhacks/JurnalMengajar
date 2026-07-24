import 'package:flutter/foundation.dart';
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

      // Trigger push notification to teacher via Edge Function
      try {
        await _supabase.functions.invoke('send-fcm-notification', body: {
          'table': 'warning_letters',
          'type': 'INSERT',
          'record': model.toJson(),
        });
      } catch (fcmErr) {
        debugPrint('FCM Warning Letter notification log: $fcmErr');
      }
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

  @override
  Future<void> update(WarningLetterModel model) async {
    try {
      await _supabase
          .from('warning_letters')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui surat peringatan: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase
          .from('warning_letters')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus surat peringatan: $e');
    }
  }
}
