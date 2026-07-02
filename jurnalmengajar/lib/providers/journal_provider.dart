import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/journal_model.dart';
import '../repositories/journal_repository.dart';
import '../repositories/supabase_journal_repository.dart';

class JournalProvider with ChangeNotifier {
  final JournalRepository journalRepository;

  List<JournalModel> _journals = [];
  List<JournalModel> _teacherJournals = [];
  bool _isLoading = false;
  String? _errorMessage;

  JournalProvider({required this.journalRepository}) {
    loadAllJournals();
  }

  List<JournalModel> get journals => _journals;
  List<JournalModel> get teacherJournals => _teacherJournals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadAllJournals() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _journals = await journalRepository.getAll();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTeacherJournals(String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _teacherJournals = await journalRepository.getJournalsForTeacher(teacherId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<JournalModel?> getJournalForSchedule(String scheduleId) async {
    try {
      return await journalRepository.getJournalForSchedule(scheduleId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> createJournal(
    JournalModel model, {
    Uint8List? attachmentBytes,
    String? attachmentFileName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.create(model);

      // Upload foto lampiran jika ada (web-compatible: gunakan bytes)
      if (attachmentBytes != null &&
          attachmentFileName != null &&
          journalRepository is SupabaseJournalRepository) {
        final supabaseRepo = journalRepository as SupabaseJournalRepository;
        // Ambil jurnal yang baru dibuat untuk mendapatkan ID-nya
        final createdJournal = await journalRepository.getJournalForSchedule(
          model.scheduleId,
        );
        if (createdJournal != null) {
          try {
            final uploadedUrl = await supabaseRepo.uploadAttachment(
              attachmentBytes,
              attachmentFileName,
              createdJournal.id,
            );
            await supabaseRepo.updateAttachmentUrl(createdJournal.id, uploadedUrl);
          } catch (storageError) {
            // Log error, tetapi jangan throw exception agar jurnal tetap dianggap berhasil dibuat
            debugPrint('Gagal mengunggah lampiran: $storageError');
            _errorMessage = 'Jurnal berhasil disimpan, namun lampiran gagal diunggah: ${storageError.toString().replaceAll('Exception: ', '')}';
            
            await loadAllJournals();
            if (model.teacherId.isNotEmpty) {
              await loadTeacherJournals(model.teacherId);
            }
            return true;
          }
        }
      }

      await loadAllJournals();
      if (model.teacherId.isNotEmpty) {
        await loadTeacherJournals(model.teacherId);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateJournal(
    JournalModel model, {
    Uint8List? attachmentBytes,
    String? attachmentFileName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.update(model);

      // Upload foto lampiran jika ada (web-compatible: gunakan bytes)
      if (attachmentBytes != null &&
          attachmentFileName != null &&
          journalRepository is SupabaseJournalRepository) {
        final supabaseRepo = journalRepository as SupabaseJournalRepository;
        try {
          final uploadedUrl = await supabaseRepo.uploadAttachment(
            attachmentBytes,
            attachmentFileName,
            model.id,
          );
          await supabaseRepo.updateAttachmentUrl(model.id, uploadedUrl);
        } catch (storageError) {
          // Log error, tetapi jangan throw exception agar jurnal tetap dianggap berhasil diperbarui
          debugPrint('Gagal mengunggah lampiran saat update: $storageError');
          _errorMessage = 'Jurnal berhasil diperbarui, namun lampiran gagal diunggah: ${storageError.toString().replaceAll('Exception: ', '')}';
          
          await loadAllJournals();
          if (model.teacherId.isNotEmpty) {
            await loadTeacherJournals(model.teacherId);
          }
          return true;
        }
      }

      await loadAllJournals();
      if (model.teacherId.isNotEmpty) {
        await loadTeacherJournals(model.teacherId);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteJournal(String id, String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.delete(id);
      await loadAllJournals();
      if (teacherId.isNotEmpty) {
        await loadTeacherJournals(teacherId);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyJournal(String journalId, String status, {String? teacherId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.verifyJournal(journalId, status);
      await loadAllJournals();
      if (teacherId != null && teacherId.isNotEmpty) {
        await loadTeacherJournals(teacherId);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
