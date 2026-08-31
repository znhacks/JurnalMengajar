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
  Future<SchoolModel?> validateActivationCode(String code) async {
    try {
      final cleanCode = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
      if (cleanCode.isEmpty) return null;

      // 1. Fetch matching school from schools table
      final response = await _supabase
          .from('schools')
          .select()
          .ilike('code', cleanCode)
          .maybeSingle();

      if (response != null) {
        return SchoolModel.fromJson(response);
      }

      // 2. Fallback scan all schools in case of npsn or exact case differences
      final allSchools = await _supabase.from('schools').select();
      for (final s in (allSchools as List)) {
        final sCode = ((s['code'] as String?) ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final sNpsn = ((s['npsn'] as String?) ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');
        final sId = ((s['id'] as String?) ?? '').toUpperCase().replaceAll(RegExp(r'\s+'), '');

        if ((sCode.isNotEmpty && sCode == cleanCode) ||
            (sNpsn.isNotEmpty && sNpsn == cleanCode) ||
            (sId.isNotEmpty && sId == cleanCode)) {
          return SchoolModel.fromJson(Map<String, dynamic>.from(s));
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> updateSchoolPlan(String schoolId, String plan, String activationCode) async {
    try {
      final normalizedPlan = plan.toLowerCase().trim();
      final maxTeachers = normalizedPlan == 'pro' ? 50 : (normalizedPlan == 'enterprise' ? 999 : 30);
      
      await _supabase.from('schools').update({
        'subscription_plan': normalizedPlan,
        'code': activationCode,
        'max_teachers': maxTeachers,
      }).eq('id', schoolId);
      return true;
    } catch (e) {
      throw Exception('Gagal memperbarui paket langganan: $e');
    }
  }
}
