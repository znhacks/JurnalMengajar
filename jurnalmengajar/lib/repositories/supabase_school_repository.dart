import 'package:flutter/foundation.dart';
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

      // 1. Direct query on schools table: WHERE code = :cleanCode AND status = 'active'
      try {
        final schoolResponse = await _supabase
            .from('schools')
            .select()
            .ilike('code', cleanCode)
            .eq('status', 'active');

        if ((schoolResponse as List).isNotEmpty) {
          return SchoolModel.fromJson((schoolResponse as List).first);
        }
      } catch (_) {}

      // 2. Check if school exists with this code but status is inactive
      try {
        final existingSchool = await _supabase
            .from('schools')
            .select()
            .ilike('code', cleanCode);

        if ((existingSchool as List).isNotEmpty) {
          final school = SchoolModel.fromJson((existingSchool as List).first);
          if (school.isInactive) {
            throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
          }
          return school;
        }
      } catch (e) {
        if (e.toString().contains('dinonaktifkan')) rethrow;
      }

      // 3. Fallback: Search tenant in tenants table by school_code or ID (UUID)
      Map<String, dynamic>? tenantRes;
      try {
        final tList = await _supabase
            .from('tenants')
            .select('id, name, school_code, status')
            .ilike('school_code', '%$cleanCode%');

        if ((tList as List).isNotEmpty) {
          tenantRes = (tList as List).first as Map<String, dynamic>;
        } else {
          final tUuidList = await _supabase
              .from('tenants')
              .select('id, name, school_code, status')
              .eq('id', cleanCode);
          if ((tUuidList as List).isNotEmpty) {
            tenantRes = (tUuidList as List).first as Map<String, dynamic>;
          }
        }
      } catch (e) {
        debugPrint('Note: tenants table query: $e');
      }

      if (tenantRes != null) {
        final tenantId = tenantRes['id'] as String;
        final tenantName = tenantRes['name'] as String? ?? 'Sekolah';
        final tenantStatus = (tenantRes['status'] as String? ?? 'active').toLowerCase();

        if (tenantStatus == 'inactive') {
          throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
        }

        // Check active subscription in subscriptions table
        bool isTenantPro = false;
        DateTime? endsAt;
        try {
          final subRes = await _supabase
              .from('subscriptions')
              .select('id, plan_id, status, ends_at')
              .eq('tenant_id', tenantId)
              .eq('status', 'active')
              .order('ends_at', ascending: false)
              .limit(1);

          if ((subRes as List).isNotEmpty) {
            final firstSub = (subRes as List).first as Map<String, dynamic>;
            final rawEndsAt = firstSub['ends_at'];
            if (rawEndsAt != null) {
              endsAt = DateTime.tryParse(rawEndsAt.toString());
            }
            final planId = (firstSub['plan_id'] as String? ?? 'free').toLowerCase();
            final isActive = endsAt == null || DateTime.now().isBefore(endsAt);
            if (isActive && (planId == 'pro' || planId == 'enterprise')) {
              isTenantPro = true;
            }
          }
        } catch (_) {}

        // Check if school already exists by code in schools table before upserting
        final existingByCode = await _supabase
            .from('schools')
            .select()
            .ilike('code', cleanCode);

        if ((existingByCode as List).isNotEmpty) {
          return SchoolModel.fromJson((existingByCode as List).first);
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

      // 4. Fallback check by npsn or id in schools table
      try {
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
      } catch (e) {
        if (e.toString().contains('dinonaktifkan')) rethrow;
      }

      // 5. Check school_invitations table
      try {
        final inviteRes = await _supabase
            .from('school_invitations')
            .select('*, schools(*)')
            .ilike('code', cleanCode)
            .maybeSingle();

        if (inviteRes != null && inviteRes['schools'] != null) {
          final schoolJson = Map<String, dynamic>.from(inviteRes['schools'] as Map);
          final school = SchoolModel.fromJson(schoolJson);
          if (school.isInactive) {
            throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
          }
          return school;
        }
      } catch (e) {
        if (e.toString().contains('dinonaktifkan')) rethrow;
      }

      // 6. Check if code is a JM-Panel plan voucher / activation code
      final upper = cleanCode.toUpperCase();
      final isProPlan = upper.contains('PRO');
      final isEnterprisePlan = upper.contains('ENTERPRISE');
      final isFreePlan = upper.contains('FREE') || upper.contains('GRATIS');
      final isJMCode = upper.startsWith('JM') || upper.startsWith('SCH') || upper.startsWith('PLAN');

      if (isProPlan || isEnterprisePlan || isFreePlan || isJMCode || cleanCode.length >= 4) {
        final detectedPlan = isEnterprisePlan ? 'enterprise' : (isProPlan ? 'pro' : 'free');
        final maxTeachers = detectedPlan == 'enterprise' ? 999 : (detectedPlan == 'pro' ? 50 : 30);
        return SchoolModel(
          id: cleanCode,
          name: '',
          code: upper,
          plan: detectedPlan,
          maxTeachers: maxTeachers,
          status: 'active',
        );
      }

      return null;
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
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
    Map<String, dynamic>? tenantRes;
    try {
      tenantRes = await _supabase
          .from('tenants')
          .select('id, name, school_code, status')
          .ilike('school_code', '%$cleanCode%')
          .maybeSingle();

      tenantRes ??= await _supabase
          .from('tenants')
          .select('id, name, school_code, status')
          .eq('id', cleanCode)
          .maybeSingle();
    } catch (_) {}

    bool isTenantPro = false;
    bool isTenantEnterprise = false;
    DateTime? endsAt;

    if (tenantRes != null) {
      final tenantId = tenantRes['id'] as String;
      final tenantStatus = (tenantRes['status'] as String? ?? 'active').toLowerCase();

      if (tenantStatus == 'inactive') {
        throw Exception('Aktivasi sekolah sedang dinonaktifkan oleh administrator (status inactive).');
      }

      // Check active subscription in subscriptions table
      try {
        final subRes = await _supabase
            .from('subscriptions')
            .select('id, plan_id, status, ends_at')
            .eq('tenant_id', tenantId)
            .eq('status', 'active')
            .order('ends_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (subRes != null) {
          final rawEndsAt = subRes['ends_at'];
          if (rawEndsAt != null) {
            endsAt = DateTime.tryParse(rawEndsAt.toString());
          }
          final planId = (subRes['plan_id'] as String? ?? 'free').toLowerCase();
          final isActive = endsAt == null || DateTime.now().isBefore(endsAt);
          if (isActive) {
            if (planId == 'enterprise') {
              isTenantEnterprise = true;
            } else if (planId == 'pro') {
              isTenantPro = true;
            }
          }
        }
      } catch (_) {}
    } else {
      // Evaluate plan from JM-Panel plan code string
      final upper = cleanCode.toUpperCase();
      if (upper.contains('ENTERPRISE')) {
        isTenantEnterprise = true;
      } else if (upper.contains('PRO')) {
        isTenantPro = true;
      }
    }

    final String plan = isTenantEnterprise ? 'enterprise' : (isTenantPro ? 'pro' : 'free');
    final int maxTeachers = isTenantEnterprise ? 999 : (isTenantPro ? 50 : 30);

    final String canonicalCode = tenantRes?['school_code'] as String? ?? activationCode.trim().replaceAll(RegExp(r'\s+'), '');

    // Update schools table for current_school_id
    final updateData = <String, dynamic>{
      'code': canonicalCode,
      'subscription_plan': plan,
      'max_teachers': maxTeachers,
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
