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
}
