import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/journal_model.dart';
import '../repositories/journal_repository.dart';
import '../repositories/supabase_journal_repository.dart';
import '../core/services/cache_service.dart';
import '../core/utils/helper.dart';

class JournalProvider with ChangeNotifier {
  final JournalRepository journalRepository;

  List<JournalModel> _journals = [];
  List<JournalModel> _teacherJournals = [];
  String? _currentSchoolId;
  bool _isLoading = false;
  String? _errorMessage;

  JournalProvider({required this.journalRepository});

  int _loadSequence = 0;
  Future<void>? _inFlightLoadAll;
  String? _inFlightSchoolId;
  Future<void>? _inFlightTeacherLoad;
  String? _inFlightTeacherId;

  List<JournalModel> get journals => _journals;
  List<JournalModel> get teacherJournals => _teacherJournals;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadAllJournals([String? schoolId]) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId?.trim();

    if (_inFlightLoadAll != null && _inFlightSchoolId == cleanSchoolId) {
      return _inFlightLoadAll!;
    }

    final future = _executeLoadAllJournals(cleanSchoolId);
    _inFlightLoadAll = future;
    _inFlightSchoolId = cleanSchoolId;
    try {
      await future;
    } finally {
      if (_inFlightLoadAll == future) {
        _inFlightLoadAll = null;
        _inFlightSchoolId = null;
      }
    }
  }

  Future<void> _executeLoadAllJournals(String? cleanSchoolId) async {
    final isSchoolChanged = cleanSchoolId != null && cleanSchoolId.isNotEmpty && cleanSchoolId != _currentSchoolId;

    if (isSchoolChanged) {
      _journals = [];
      _teacherJournals = [];
      _errorMessage = null;
      debugPrint('[RUNTIME_DEBUG:JOURNAL_PROVIDER] Switched school context from "$_currentSchoolId" to "$cleanSchoolId". In-memory journals purged.');
    }

    _currentSchoolId = cleanSchoolId ?? _currentSchoolId;
    _errorMessage = null;
    final int sequence = ++_loadSequence;

    final sKey = _currentSchoolId ?? 'default';
    if (_journals.isEmpty) {
      try {
        final cached = await CacheService().loadList('journals_$sKey');
        if (cached != null && cached.isNotEmpty && _journals.isEmpty && sequence == _loadSequence) {
          _journals = cached.map((j) => JournalModel.fromJson(j)).toList();
          _isLoading = false;
          notifyListeners();
        } else {
          _isLoading = true;
          notifyListeners();
        }
      } catch (_) {
        _isLoading = true;
        notifyListeners();
      }
    } else {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final fresh = await journalRepository.getAll(_currentSchoolId);
      if (sequence != _loadSequence || _currentSchoolId != cleanSchoolId) {
        debugPrint('[RUNTIME_DEBUG:JOURNAL_PROVIDER] Stale loadAllJournals dropped for $cleanSchoolId');
        return;
      }

      // Multi-tenant defense: ensure no journal from another school slips in
      if (_currentSchoolId != null && _currentSchoolId!.isNotEmpty) {
        _journals = fresh.where((j) {
          final sSchoolId = AppHelper.parseSingleCleanSchoolId(j.schoolId);
          return sSchoolId == null || sSchoolId.isEmpty || sSchoolId == _currentSchoolId;
        }).toList();
      } else {
        _journals = fresh;
      }
    } catch (e) {
      if (sequence == _loadSequence) {
        _errorMessage = e.toString();
      }
    } finally {
      if (sequence == _loadSequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadTeacherJournals(String teacherId) async {
    if (_inFlightTeacherLoad != null && _inFlightTeacherId == teacherId) {
      return _inFlightTeacherLoad!;
    }

    final future = _executeLoadTeacherJournals(teacherId);
    _inFlightTeacherLoad = future;
    _inFlightTeacherId = teacherId;
    try {
      await future;
    } finally {
      if (_inFlightTeacherLoad == future) {
        _inFlightTeacherLoad = null;
        _inFlightTeacherId = null;
      }
    }
  }

  Future<void> _executeLoadTeacherJournals(String teacherId) async {
    _errorMessage = null;
    if (_teacherJournals.isEmpty) {
      try {
        final cached = await CacheService().loadList('teacher_journals_$teacherId') ??
            await CacheService().loadList('journals_teacher_$teacherId');
        if (cached != null && cached.isNotEmpty && _teacherJournals.isEmpty) {
          _teacherJournals = cached.map((j) => JournalModel.fromJson(j)).toList();
          _isLoading = false;
          notifyListeners();
        } else {
          _isLoading = true;
          notifyListeners();
        }
      } catch (_) {
        _isLoading = true;
        notifyListeners();
      }
    } else {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final fresh = await journalRepository.getJournalsForTeacher(teacherId);
      if (fresh.isNotEmpty || _teacherJournals.isEmpty) {
        _teacherJournals = fresh;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearTeacherJournalsCache() {
    _teacherJournals = [];
    notifyListeners();
  }

  Future<JournalModel?> getJournalForSchedule(String scheduleId, {DateTime? date}) async {
    try {
      return await journalRepository.getJournalForSchedule(scheduleId, date: date);
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
      final finalModel = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: _currentSchoolId)
          : model;
      await journalRepository.create(finalModel);

      // Upload foto lampiran jika ada (max 3, web-compatible)
      if (imageBytesList != null && imageBytesList.isNotEmpty &&
          imageNamesList != null && imageNamesList.isNotEmpty &&
          journalRepository is SupabaseJournalRepository) {
        final supabaseRepo = journalRepository as SupabaseJournalRepository;
        final bytesList = imageBytesList;
        final namesList = imageNamesList;
        final createdJournal = await journalRepository.getJournalForSchedule(
          model.scheduleId,
          date: model.date,
        );
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
            await loadAllJournals(_currentSchoolId);
            if (model.teacherId.isNotEmpty) await loadTeacherJournals(model.teacherId);
            return true;
          }
        }
      }

      await loadAllJournals(_currentSchoolId);
      if (model.teacherId.isNotEmpty) {
        await loadTeacherJournals(model.teacherId);
      }
      return true;
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('journals_schedule_id_fkey') || msg.contains('23503')) {
        msg = 'Jadwal ini tidak ditemukan di database (ID jadwal tidak terdaftar atau sudah dihapus). Silakan refresh halaman jadwal Anda.';
      }
      _errorMessage = msg;
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
      final finalModel = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: _currentSchoolId)
          : model;
      await journalRepository.update(finalModel);

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
          await loadAllJournals(_currentSchoolId);
          if (model.teacherId.isNotEmpty) await loadTeacherJournals(model.teacherId);
          return true;
        }
      }

      await loadAllJournals(_currentSchoolId);
      if (model.teacherId.isNotEmpty) {
        await loadTeacherJournals(model.teacherId);
      }
      return true;
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('journals_schedule_id_fkey') || msg.contains('23503')) {
        msg = 'Jadwal ini tidak ditemukan di database (ID jadwal tidak terdaftar atau sudah dihapus). Silakan refresh halaman jadwal Anda.';
      }
      _errorMessage = msg;
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
      _journals.removeWhere((j) => j.id == id);
      _teacherJournals.removeWhere((j) => j.id == id);
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
      await loadAllJournals(_currentSchoolId);
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

  Future<bool> deleteMultipleJournals(List<String> ids) async {
    if (ids.isEmpty) return true;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.deleteMultiple(ids);
      final idSet = ids.toSet();
      _journals.removeWhere((j) => idSet.contains(j.id));
      _teacherJournals.removeWhere((j) => idSet.contains(j.id));
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
