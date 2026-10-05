import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/student_model.dart';
import '../models/student_academic_history_model.dart';
import 'student_repository.dart';

const _uuid = Uuid();

class SupabaseStudentRepository implements StudentRepository {
  final SupabaseClient _supabase;

  SupabaseStudentRepository(this._supabase);

  @override
  Future<List<StudentModel>> getAllByClass(String classId) async {
    try {
      // 1. Ambil data siswa yang saat ini class_id = classId
      final primaryResponse = await _supabase
          .from('students')
          .select()
          .eq('class_id', classId)
          .order('name', ascending: true);

      final Map<String, StudentModel> studentMap = {};

      for (final item in (primaryResponse as List)) {
        try {
          final map = item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map);
          final student = StudentModel.fromJson(map);
          studentMap[student.id] = student;
        } catch (_) {}
      }

      // 2. Ambil data histori akademik pada kelas ini agar siswa pada tahun ajaran lama tetap terbaca
      try {
        final historyResponse = await _supabase
            .from('student_academic_histories')
            .select()
            .eq('class_id', classId)
            .order('created_at', ascending: false);

        final List<String> missingStudentIds = [];
        final Map<String, String> historyStatusMap = {};

        for (final item in (historyResponse as List)) {
          final sId = item['student_id']?.toString();
          final status = item['status']?.toString() ?? 'aktif';
          if (sId != null && sId.isNotEmpty) {
            historyStatusMap[sId] = status;
            if (!studentMap.containsKey(sId)) {
              missingStudentIds.add(sId);
            }
          }
        }

        // Ambil data profil siswa yang belum ada di map (karena sudah pindah/naik ke kelas lain)
        if (missingStudentIds.isNotEmpty) {
          final additionalResponse = await _supabase
              .from('students')
              .select()
              .inFilter('id', missingStudentIds);

          for (final item in (additionalResponse as List)) {
            try {
              final map = item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map);
              final student = StudentModel.fromJson(map);
              final enrollmentStatus = historyStatusMap[student.id] ?? 'aktif';
              studentMap[student.id] = student.copyWith(
                enrollmentStatus: enrollmentStatus,
              );
            } catch (_) {}
          }
        }

        // Sematkan status enrollment untuk siswa yang sudah ada di studentMap
        for (final entry in historyStatusMap.entries) {
          if (studentMap.containsKey(entry.key)) {
            final s = studentMap[entry.key]!;
            studentMap[entry.key] = s.copyWith(enrollmentStatus: entry.value);
          }
        }
      } catch (err) {
        // Fallback jika tabel history belum terjangkau
      }

      final List<StudentModel> list = studentMap.values.toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (e) {
      throw Exception('Gagal memuat siswa: $e');
    }
  }

  @override
  Future<void> create(StudentModel model) async {
    try {
      final payload = model.toJson();
      if (payload['id'] == null || (payload['id'] as String).isEmpty) {
        payload['id'] = _uuid.v4();
      }
      await _supabase.from('students').insert(payload);

      // Otomatis catat histori akademik awal jika kelas dan periode valid
      try {
        final classData = await _supabase
            .from('classes')
            .select('id, name, period_id, school_id')
            .eq('id', model.classId)
            .maybeSingle();

        if (classData != null && classData['period_id'] != null) {
          final periodData = await _supabase
              .from('periods')
              .select('name')
              .eq('id', classData['period_id'])
              .maybeSingle();

          final academicYear = periodData?['name']?.toString() ?? '-';
          final className = classData['name']?.toString() ?? '-';

          await _supabase.from('student_academic_histories').insert({
            'student_id': payload['id'],
            'school_id': model.schoolId ?? classData['school_id'],
            'period_id': classData['period_id'],
            'class_id': model.classId,
            'academic_year': academicYear,
            'class_name': className,
            'status': 'aktif',
          });
        }
      } catch (_) {}
    } catch (e) {
      throw Exception('Gagal menambah siswa: $e');
    }
  }

  @override
  Future<void> update(StudentModel model) async {
    try {
      await _supabase
          .from('students')
          .update(model.toJson())
          .eq('id', model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui siswa: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _supabase.from('students').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus siswa: $e');
    }
  }

  @override
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _supabase.from('students').delete().inFilter('id', ids);
    } catch (e) {
      throw Exception('Gagal menghapus beberapa siswa: $e');
    }
  }

  Future<void> createMultiple(List<StudentModel> models) async {
    if (models.isEmpty) return;
    try {
      final payloads = models.map((m) {
        final map = m.toJson();
        if (map['id'] == null || (map['id'] as String).isEmpty) {
          map['id'] = _uuid.v4();
        }
        return map;
      }).toList();

      const chunkSize = 100;
      for (var i = 0; i < payloads.length; i += chunkSize) {
        final end = (i + chunkSize < payloads.length) ? i + chunkSize : payloads.length;
        final chunk = payloads.sublist(i, end);
        await _supabase.from('students').insert(chunk);
      }

      // Sinkronisasi histori untuk batch siswa
      try {
        final classId = models.first.classId;
        final classData = await _supabase
            .from('classes')
            .select('id, name, period_id, school_id')
            .eq('id', classId)
            .maybeSingle();

        if (classData != null && classData['period_id'] != null) {
          final periodData = await _supabase
              .from('periods')
              .select('name')
              .eq('id', classData['period_id'])
              .maybeSingle();

          final academicYear = periodData?['name']?.toString() ?? '-';
          final className = classData['name']?.toString() ?? '-';

          final historyPayloads = payloads.map((p) {
            return {
              'student_id': p['id'],
              'school_id': p['school_id'] ?? classData['school_id'],
              'period_id': classData['period_id'],
              'class_id': classId,
              'academic_year': academicYear,
              'class_name': className,
              'status': 'aktif',
            };
          }).toList();

          for (var i = 0; i < historyPayloads.length; i += chunkSize) {
            final end = (i + chunkSize < historyPayloads.length)
                ? i + chunkSize
                : historyPayloads.length;
            final chunk = historyPayloads.sublist(i, end);
            await _supabase
                .from('student_academic_histories')
                .upsert(chunk, onConflict: 'student_id,period_id,class_id');
          }
        }
      } catch (_) {}
    } catch (e) {
      throw Exception('Gagal menambah beberapa siswa: $e');
    }
  }

  @override
  Future<List<StudentAcademicHistoryModel>> getStudentHistories(String studentId) async {
    try {
      final response = await _supabase
          .from('student_academic_histories')
          .select('''
            id, student_id, school_id, period_id, class_id, academic_year, class_name,
            status, from_period_id, from_class_id, from_class_name, to_period_id,
            to_class_id, to_class_name, transfer_date, note, created_at, updated_at
          ''')
          .eq('student_id', studentId)
          .order('academic_year', ascending: false)
          .order('created_at', ascending: false);

      final List<StudentAcademicHistoryModel> list = [];
      for (final item in (response as List)) {
        try {
          final map = item is Map<String, dynamic>
              ? item
              : Map<String, dynamic>.from(item as Map);
          list.add(StudentAcademicHistoryModel.fromJson(map));
        } catch (_) {}
      }
      return list;
    } catch (e) {
      throw Exception('Gagal memuat histori siswa: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> processPromotions({
    required String schoolId,
    required String sourcePeriodId,
    required String sourceClassId,
    String? targetPeriodId,
    String? targetClassId,
    required List<Map<String, dynamic>> items,
    DateTime? transferDate,
  }) async {
    try {
      final formattedDate = (transferDate ?? DateTime.now()).toIso8601String().split('T')[0];

      final response = await _supabase.rpc('process_student_promotions', params: {
        'p_school_id': schoolId,
        'p_source_period_id': sourcePeriodId,
        'p_source_class_id': sourceClassId,
        'p_target_period_id': targetPeriodId,
        'p_target_class_id': targetClassId,
        'p_items': items,
        'p_transfer_date': formattedDate,
      });

      if (response is Map<String, dynamic>) {
        return response;
      } else if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': true, 'message': 'Berhasil diproses.'};
    } catch (e) {
      throw Exception('Gagal memproses kenaikan kelas: $e');
    }
  }
}
