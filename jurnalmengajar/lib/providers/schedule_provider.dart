import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../repositories/schedule_repository.dart';

class ScheduleProvider with ChangeNotifier {
  final ScheduleRepository scheduleRepository;

  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> _teacherSchedulesForSelectedDate = [];
  bool _isLoading = false;
  String? _errorMessage;

  ScheduleProvider({required this.scheduleRepository}) {
    loadAllSchedules();
  }

  List<ScheduleModel> get schedules => _schedules;
  List<ScheduleModel> get teacherSchedulesForSelectedDate => _teacherSchedulesForSelectedDate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadAllSchedules() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _schedules = await scheduleRepository.getAll();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTeacherSchedules(String teacherId, DateTime date) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _teacherSchedulesForSelectedDate = await scheduleRepository.getSchedulesForTeacher(teacherId, date);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _validateNoActiveOverlap(ScheduleModel proposed, {String? excludeId}) {
    if (!proposed.isActive) return;

    for (final s in _schedules) {
      if (s.id == excludeId) continue;
      if (s.isActive &&
          s.classId == proposed.classId &&
          s.teachingHour == proposed.teachingHour &&
          s.date.year == proposed.date.year &&
          s.date.month == proposed.date.month &&
          s.date.day == proposed.date.day) {
        throw Exception('Terdapat Jadwal Aktif, Ambil jam atau tanggal yang berbeda');
      }
    }
  }

  Future<bool> createSchedule(ScheduleModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      _validateNoActiveOverlap(model);
      await scheduleRepository.create(model);
      await loadAllSchedules();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createMultipleSchedules(List<ScheduleModel> models) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final m in models) {
        _validateNoActiveOverlap(m);
      }
      await scheduleRepository.createMultiple(models);
      await loadAllSchedules();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSchedule(ScheduleModel model) async {
    _isLoading = true;
    notifyListeners();
    try {
      _validateNoActiveOverlap(model, excludeId: model.id);
      await scheduleRepository.update(model);
      await loadAllSchedules();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteSchedule(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      await scheduleRepository.delete(id);
      await loadAllSchedules();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMultipleSchedules(List<String> ids) async {
    _isLoading = true;
    notifyListeners();
    try {
      await scheduleRepository.deleteMultiple(ids);
      await loadAllSchedules();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
