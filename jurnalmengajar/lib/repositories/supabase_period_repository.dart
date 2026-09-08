import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/period_model.dart';
import '../core/utils/helper.dart';
import 'period_repository.dart';

const _uuid = Uuid();

class SupabasePeriodRepository implements PeriodRepository {
  final SupabaseClient _supabase;

  SupabasePeriodRepository(this._supabase);

  @override
  Future<List<PeriodModel>> getAll([String? schoolId]) async {
    try {
      final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId);
      var query = _supabase.from('periods').select();
      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        query = query.eq('school_id', cleanSchoolId);
      }
      final response = await query.order('name', ascending: true);

      final List<PeriodModel> list = [];
      for (final item in (response as List)) {
        try {
          if (item is Map<String, dynamic>) {
            list.add(PeriodModel.fromJson(item));
          } else if (item is Map) {
            list.add(PeriodModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> create(PeriodModel model) async {
    try {
      if (model.isActive) {
        var deactivateQuery = _supabase
            .from('periods')
            .update({'is_active': false})
            .eq('is_active', true);
        if (model.schoolId != null && model.schoolId!.isNotEmpty) {
          deactivateQuery = deactivateQuery.eq('school_id', model.schoolId!);
        }
        await deactivateQuery;
      }
      final payload = model.toJson();
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('periods').insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah periode: $e');
    }
  }

  @override
  Future<void> update(PeriodModel model) async {
    try {
      if (model.isActive) {
        var deactivateQuery = _supabase
            .from('periods')
            .update({'is_active': false})
            .eq('is_active', true);
        if (model.schoolId != null && model.schoolId!.isNotEmpty) {
          deactivateQuery = deactivateQuery.eq('school_id', model.schoolId!);
        }
        await deactivateQuery;
      }
      await _supabase
          .from('periods')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui periode: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('periods').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus periode: $e');
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase.from('periods').delete().inFilter('id', ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa periode: $e');
    }
  }
}
