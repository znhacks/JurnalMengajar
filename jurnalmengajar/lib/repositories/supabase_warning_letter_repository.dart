import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/warning_letter_model.dart';
import '../core/utils/helper.dart';
import 'warning_letter_repository.dart';

class SupabaseWarningLetterRepository implements WarningLetterRepository {
  final SupabaseClient _supabase;

  SupabaseWarningLetterRepository(this._supabase);

  @override
  Future<List<WarningLetterModel>> getAll([String? schoolId]) async {
    try {
      var query = _supabase.from('warning_letters').select();
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        query = query.eq('school_id', cleanSchoolId);
      }

      final response = await query.order('issued_at', ascending: false);

      final List<WarningLetterModel> list = [];
      for (final item in (response as List)) {
        try {
          if (item is Map<String, dynamic>) {
            list.add(WarningLetterModel.fromJson(item));
          } else if (item is Map) {
            list.add(WarningLetterModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
      return list;
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

      final List<WarningLetterModel> list = [];
      for (final item in (response as List)) {
        try {
          if (item is Map<String, dynamic>) {
            list.add(WarningLetterModel.fromJson(item));
          } else if (item is Map) {
            list.add(WarningLetterModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
      return list;
    } catch (e) {
      throw Exception('Gagal memuat surat peringatan guru: $e');
    }
  }

  @override
  Future<void> create(WarningLetterModel model) async {
    try {
      final payload = model.toJson();
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(payload['school_id']);
      if (cleanSchoolId == null || cleanSchoolId.isEmpty) {
        final currentUid = _supabase.auth.currentUser?.id ?? model.teacherId;
        if (currentUid.isNotEmpty) {
          try {
            final userRes = await _supabase
                .from('users')
                .select('school_id')
                .eq('id', currentUid)
                .maybeSingle();
            if (userRes != null && userRes['school_id'] != null) {
              payload['school_id'] = AppHelper.parseSingleCleanSchoolId(userRes['school_id']);
            }
          } catch (_) {}
        }
      } else {
        payload['school_id'] = cleanSchoolId;
      }

      await _supabase.from('warning_letters').insert(payload);

      // Trigger push notification to teacher via Edge Function
      try {
        await _supabase.functions.invoke('send-fcm-notification', body: {
          'table': 'warning_letters',
          'type': 'INSERT',
          'record': payload,
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
