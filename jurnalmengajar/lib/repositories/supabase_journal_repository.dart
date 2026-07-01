import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';
import '../models/journal_model.dart';
import 'journal_repository.dart';
import '../core/constants/supabase_constants.dart';

const _uuid = Uuid();

class SupabaseJournalRepository implements JournalRepository {
  final SupabaseClient _supabase;

  SupabaseJournalRepository(this._supabase);

  @override
  Future<List<JournalModel>> getAll() async {
    try {
      final response = await _supabase
          .from(SupabaseConstants.tableJournals)
          .select()
          .order(SupabaseConstants.fieldDate, ascending: false);

      return (response as List)
          .map((json) => JournalModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat jurnal: $e');
    }
  }

  @override
  Future<List<JournalModel>> getJournalsForTeacher(String teacherId) async {
    try {
      final response = await _supabase
          .from(SupabaseConstants.tableJournals)
          .select()
          .eq(SupabaseConstants.fieldTeacherId, teacherId)
          .order(SupabaseConstants.fieldDate, ascending: false);

      return (response as List)
          .map((json) => JournalModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Gagal memuat jurnal guru: $e');
    }
  }

  @override
  Future<JournalModel?> getJournalForSchedule(String scheduleId) async {
    try {
      final response = await _supabase
          .from(SupabaseConstants.tableJournals)
          .select()
          .eq(SupabaseConstants.fieldScheduleId, scheduleId)
          .maybeSingle();

      if (response == null) return null;
      return JournalModel.fromJson(response);
    } catch (e) {
      throw Exception('Gagal memuat jurnal untuk jadwal: $e');
    }
  }

  @override
  Future<void> create(JournalModel model) async {
    try {
      final payload = model.toJson();
      // Remove attachment from payload (will be handled separately)
      payload.remove('attachment');
      // Generate a UUID client-side if id is empty
      if ((payload['id'] as String?)?.isEmpty ?? true) {
        payload['id'] = _uuid.v4();
      }
      
      await _supabase
          .from(SupabaseConstants.tableJournals)
          .insert(payload);
    } catch (e) {
      throw Exception('Gagal membuat jurnal: $e');
    }
  }

  @override
  Future<void> update(JournalModel model) async {
    try {
      final payload = model.toJson();
      // Remove attachment from payload (will be handled separately)
      payload.remove('attachment');
      
      await _supabase
          .from(SupabaseConstants.tableJournals)
          .update(payload)
          .eq(SupabaseConstants.fieldId, model.id);
    } catch (e) {
      throw Exception('Gagal memperbarui jurnal: $e');
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      // Get journal first to check if it has attachment
      final journal = await _supabase
          .from(SupabaseConstants.tableJournals)
          .select()
          .eq(SupabaseConstants.fieldId, id)
          .single();

      final attachmentUrl = journal[SupabaseConstants.fieldAttachmentUrl];
      
      // Delete file from storage if exists
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
        try {
          // Extract file path from URL
          final filePath = _extractFilePathFromUrl(attachmentUrl);
          if (filePath.isNotEmpty) {
            await _supabase.storage
                .from(SupabaseConstants.bucketJournalAttachments)
                .remove([filePath]);
          }
        } catch (e) {
          print('Error deleting attachment file: $e');
        }
      }

      // Delete journal record
      await _supabase
          .from(SupabaseConstants.tableJournals)
          .delete()
          .eq(SupabaseConstants.fieldId, id);
    } catch (e) {
      throw Exception('Gagal menghapus jurnal: $e');
    }
  }

  @override
  Future<void> verifyJournal(String journalId, String status) async {
    try {
      await _supabase
          .from(SupabaseConstants.tableJournals)
          .update({SupabaseConstants.fieldStatus: status})
          .eq(SupabaseConstants.fieldId, journalId);
    } catch (e) {
      throw Exception('Gagal memperbarui status jurnal: $e');
    }
  }

  /// Upload attachment file (as bytes) and return public URL
  Future<String> uploadAttachment(
    List<int> fileBytes,
    String fileName,
    String journalId,
  ) async {
    try {
      final safeFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final filePath = '$journalId/$safeFileName';

      await _supabase.storage
          .from(SupabaseConstants.bucketJournalAttachments)
          .uploadBinary(
        filePath,
        Uint8List.fromList(fileBytes),
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
        ),
      );

      // Get public URL
      final publicUrl = _supabase.storage
          .from(SupabaseConstants.bucketJournalAttachments)
          .getPublicUrl(filePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Gagal mengunggah lampiran: $e');
    }
  }

  /// Update journal attachment URL
  Future<void> updateAttachmentUrl(String journalId, String attachmentUrl) async {
    try {
      await _supabase
          .from(SupabaseConstants.tableJournals)
          .update({SupabaseConstants.fieldAttachmentUrl: attachmentUrl})
          .eq(SupabaseConstants.fieldId, journalId);
    } catch (e) {
      throw Exception('Gagal memperbarui URL lampiran: $e');
    }
  }

  /// Delete attachment file from storage
  Future<void> deleteAttachment(String attachmentUrl) async {
    try {
      final filePath = _extractFilePathFromUrl(attachmentUrl);
      if (filePath.isNotEmpty) {
        await _supabase.storage
            .from(SupabaseConstants.bucketJournalAttachments)
            .remove([filePath]);
      }
    } catch (e) {
      throw Exception('Gagal menghapus file lampiran: $e');
    }
  }

  /// Extract file path from public URL
  String _extractFilePathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      
      // URL format: .../storage/v1/object/public/journal-attachments/path/to/file
      if (segments.contains('public') && segments.contains(SupabaseConstants.bucketJournalAttachments)) {
        final bucketIndex = segments.indexOf(SupabaseConstants.bucketJournalAttachments);
        if (bucketIndex < segments.length - 1) {
          return segments.sublist(bucketIndex + 1).join('/');
        }
      }
      return '';
    } catch (e) {
      print('Error extracting file path: $e');
      return '';
    }
  }
}
