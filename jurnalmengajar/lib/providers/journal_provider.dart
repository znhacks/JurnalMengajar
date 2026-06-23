import 'package:flutter/material.dart';
import '../models/journal_model.dart';
import '../repositories/journal_repository.dart';

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

  Future<bool> createJournal(JournalModel model) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.create(model);
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

  Future<bool> updateJournal(JournalModel model) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await journalRepository.update(model);
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
