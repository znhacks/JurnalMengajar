import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/period_model.dart';
import 'period_repository.dart';

class SupabasePeriodRepository implements PeriodRepository {
  final SupabaseClient _supabase;

  SupabasePeriodRepository(this._supabase);

  @override
  Future<List<PeriodModel>> getAll() async {
    try {
      final response = await _supabase
          .from('periods')
          .select()
          .order('name', ascending: true);

      return (response as List)
          .map((json) => PeriodModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat periode: $e');
    }
  }

  @override
  Future<void> create(PeriodModel model) async {
    try {
      await _supabase.from('periods').insert(model.toJson());
    } catch (e) {
      throw Exception('Gagal menambah periode: $e');
    }
  }

  @override
  Future<void> update(PeriodModel model) async {
    try {
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
}
