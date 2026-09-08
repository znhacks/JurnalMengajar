import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/subject_model.dart';
import 'subject_repository.dart';

const _uuid = Uuid();

class SupabaseSubjectRepository implements SubjectRepository {
  final SupabaseClient _supabase;

  SupabaseSubjectRepository(this._supabase);

  @override
  Future<List<SubjectModel>> getAll([String? schoolId]) async {
    try {
      final response = await _supabase
          .from('subjects')
          .select()
          .order('name', ascending: true);

      final List<SubjectModel> list = [];
      for (final item in (response as List)) {
        try {
          if (item is Map<String, dynamic>) {
            list.add(SubjectModel.fromJson(item));
          } else if (item is Map) {
            list.add(SubjectModel.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> create(SubjectModel model) async {
    try {
      final payload = model.toJson();
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('subjects').insert(payload);
    } catch (e) {
      throw Exception('Gagal menambah mata pelajaran: $e');
    }
  }

  @override
  Future<void> update(SubjectModel model) async {
    try {
      await _supabase
          .from('subjects')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui mata pelajaran: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('subjects').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus mata pelajaran: $e');
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase.from('subjects').delete().inFilter('id', ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa mata pelajaran: $e');
    }
  }
}
