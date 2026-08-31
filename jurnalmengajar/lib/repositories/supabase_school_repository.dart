import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/school_model.dart';
import 'school_repository.dart';

class SupabaseSchoolRepository implements SchoolRepository {
  final SupabaseClient _supabase;

  SupabaseSchoolRepository(this._supabase);

  @override
  Future<List<SchoolModel>> getAll() async {
    try {
      final response = await _supabase
          .from('schools')
          .select()
          .order('name', ascending: true);

      return (response as List)
          .map((json) => SchoolModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat daftar sekolah: $e');
    }
  }

  @override
  Future<String?> validateActivationCode(String code) async {
    try {
      final response = await _supabase
          .from('activation_codes')
          .select('plan')
          .eq('code', code)
          .maybeSingle();

      if (response != null && response['plan'] != null) {
        return response['plan'] as String;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> updateSchoolPlan(String schoolId, String plan, String activationCode) async {
    try {
      await _supabase.from('schools').update({
        'plan': plan,
        'activation_code': activationCode,
      }).eq('id', schoolId);
      return true;
    } catch (e) {
      throw Exception('Gagal memperbarui paket langganan: $e');
    }
  }
}
