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

  JournalProvider({required this.journalRepository});

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
    List<Uint8List>? imageBytesList,
    List<String>? imageNamesList,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.create(model);

      // Upload foto lampiran jika ada (max 3, web-compatible)
      if (imageBytesList != null && imageBytesList.isNotEmpty &&
          imageNamesList != null && imageNamesList.isNotEmpty &&
          journalRepository is SupabaseJournalRepository) {
        final supabaseRepo = journalRepository as SupabaseJournalRepository;
        final bytesList = imageBytesList;
        final namesList = imageNamesList;
        final createdJournal = await journalRepository.getJournalForSchedule(model.scheduleId);
        if (createdJournal != null) {
          try {
            final uploadedUrls = <String>[];
            for (int i = 0; i < bytesList.length && i < 3; i++) {
              final url = await supabaseRepo.uploadAttachment(
                bytesList[i],
                namesList[i],
                createdJournal.id,
                suffix: '_${i + 1}',
              );
              uploadedUrls.add(url);
            }
            await supabaseRepo.updateAttachmentUrl(createdJournal.id, uploadedUrls.join(','));
          } catch (storageError) {
            debugPrint('Gagal mengunggah lampiran: $storageError');
            _errorMessage = 'Jurnal berhasil disimpan, namun lampiran gagal diunggah: ${storageError.toString().replaceAll('Exception: ', '')}';
            await loadAllJournals();
            if (model.teacherId.isNotEmpty) await loadTeacherJournals(model.teacherId);
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
    List<Uint8List>? imageBytesList,
    List<String>? imageNamesList,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.update(model);

      // Upload foto lampiran baru jika ada (max 3)
      if (imageBytesList != null && imageBytesList.isNotEmpty &&
          imageNamesList != null && imageNamesList.isNotEmpty &&
          journalRepository is SupabaseJournalRepository) {
        final supabaseRepo = journalRepository as SupabaseJournalRepository;
        final bytesList = imageBytesList;
        final namesList = imageNamesList;
        try {
          final uploadedUrls = <String>[];
          for (int i = 0; i < bytesList.length && i < 3; i++) {
            final url = await supabaseRepo.uploadAttachment(
              bytesList[i],
              namesList[i],
              model.id,
              suffix: '_${i + 1}',
            );
            uploadedUrls.add(url);
          }
          await supabaseRepo.updateAttachmentUrl(model.id, uploadedUrls.join(','));
        } catch (storageError) {
          debugPrint('Gagal mengunggah lampiran saat update: $storageError');
          _errorMessage = 'Jurnal berhasil diperbarui, namun lampiran gagal diunggah: ${storageError.toString().replaceAll('Exception: ', '')}';
          await loadAllJournals();
          if (model.teacherId.isNotEmpty) await loadTeacherJournals(model.teacherId);
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

  Future<bool> verifyJournal(String journalId, String status, {String? rejectionNote, String? teacherId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.verifyJournal(journalId, status, rejectionNote: rejectionNote);
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
