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
      final cleanCode = code.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (cleanCode.isEmpty) return null;

      // 1. Search tenant in tenants table by school_code or ID (UUID)
      var tenantRes = await _supabase
          .from('tenants')
          .select('id, name, school_code, status')
          .ilike('school_code', '%$cleanCode%')
          .maybeSingle();

      tenantRes ??= await _supabase
          .from('tenants')
          .select('id, name, school_code, status')
          .eq('id', cleanCode)
          .maybeSingle();

      if (tenantRes != null) {
        final tenantId = tenantRes['id'] as String;
        final tenantName = tenantRes['name'] as String? ?? 'Sekolah';
        final tenantStatus = (tenantRes['status'] as String? ?? 'active').toLowerCase();

        if (tenantStatus == 'inactive') {
          throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
        }

        // Check active subscription in subscriptions table
        final subRes = await _supabase
            .from('subscriptions')
            .select('id, plan_id, status, ends_at')
            .eq('tenant_id', tenantId)
            .eq('status', 'active')
            .order('ends_at', ascending: false)
            .limit(1)
            .maybeSingle();

        bool isTenantPro = false;
        DateTime? endsAt;

        if (subRes != null) {
          final rawEndsAt = subRes['ends_at'];
          if (rawEndsAt != null) {
            endsAt = DateTime.tryParse(rawEndsAt.toString());
          }
          final planId = (subRes['plan_id'] as String? ?? 'free').toLowerCase();
          final isActive = endsAt == null || DateTime.now().isBefore(endsAt);
          if (isActive && (planId == 'pro' || planId == 'enterprise')) {
            isTenantPro = true;
          }
        }

        return SchoolModel(
          id: tenantId,
          name: tenantName,
          code: cleanCode,
          plan: isTenantPro ? 'pro' : 'free',
          maxTeachers: isTenantPro ? 50 : 30,
          status: 'active',
          subscriptionUntil: endsAt,
        );
      }

      // 2. Direct query on schools table: WHERE code = :cleanCode AND status = 'active'
      final schoolResponse = await _supabase
          .from('schools')
          .select()
          .ilike('code', cleanCode)
          .eq('status', 'active')
          .maybeSingle();

      if (schoolResponse != null) {
        return SchoolModel.fromJson(schoolResponse);
      }

      // 3. Check if school exists with this code but status is inactive
      final existingSchool = await _supabase
          .from('schools')
          .select()
          .ilike('code', cleanCode)
          .maybeSingle();

      if (existingSchool != null) {
        final school = SchoolModel.fromJson(existingSchool);
        if (school.isInactive) {
          throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
        }
        return school;
      }

      // 4. Fallback check by npsn or id in schools table
      final fallbackResponse = await _supabase
          .from('schools')
          .select()
          .or('npsn.ilike.$cleanCode,id.eq.$cleanCode')
          .maybeSingle();

      if (fallbackResponse != null) {
        final school = SchoolModel.fromJson(fallbackResponse);
        if (school.isInactive) {
          throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
        }
        return school;
      }

      return null;
    } catch (e) {
      if (e.toString().contains('Aktivasi sekolah sedang dinonaktifkan')) {
        rethrow;
      }
      return null;
    }
  }

  @override
  Future<SchoolModel> activateSchoolWithCode({
    required String currentSchoolId,
    required String activationCode,
  }) async {
    final cleanCode = activationCode.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (cleanCode.isEmpty) {
      throw Exception('Kode aktivasi tidak valid');
    }

    // 1. Search tenant in tenants table by school_code or ID (UUID)
    var tenantRes = await _supabase
        .from('tenants')
        .select('id, name, school_code, status')
        .ilike('school_code', '%$cleanCode%')
        .maybeSingle();

    tenantRes ??= await _supabase
        .from('tenants')
        .select('id, name, school_code, status')
        .eq('id', cleanCode)
        .maybeSingle();

    if (tenantRes == null) {
      throw Exception('Kode aktivasi tidak valid');
    }

    final tenantId = tenantRes['id'] as String;
    final tenantStatus = (tenantRes['status'] as String? ?? 'active').toLowerCase();

    if (tenantStatus == 'inactive') {
      throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
    }

    // 2. Check active subscription in subscriptions table (status = 'active' and now() < ends_at)
    final subRes = await _supabase
        .from('subscriptions')
        .select('id, plan_id, status, ends_at')
        .eq('tenant_id', tenantId)
        .eq('status', 'active')
        .order('ends_at', ascending: false)
        .limit(1)
        .maybeSingle();

    bool isTenantPro = false;
    DateTime? endsAt;

    if (subRes != null) {
      final rawEndsAt = subRes['ends_at'];
      if (rawEndsAt != null) {
        endsAt = DateTime.tryParse(rawEndsAt.toString());
      }
      final planId = (subRes['plan_id'] as String? ?? 'free').toLowerCase();
      final isActive = endsAt == null || DateTime.now().isBefore(endsAt);
      if (isActive && (planId == 'pro' || planId == 'enterprise')) {
        isTenantPro = true;
      }
    }

    // 3. Update schools table for current_school_id
    final updateData = <String, dynamic>{
      'code': cleanCode,
      'subscription_plan': isTenantPro ? 'pro' : 'free',
      'max_teachers': isTenantPro ? 50 : 30,
      'status': 'active',
      if (endsAt != null) 'subscription_until': endsAt.toIso8601String(),
    };

    final updated = await _supabase
        .from('schools')
        .update(updateData)
        .eq('id', currentSchoolId)
        .select()
        .single();

    return SchoolModel.fromJson(updated);
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
