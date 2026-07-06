import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../repositories/schedule_repository.dart';

class ScheduleProvider with ChangeNotifier {
  final ScheduleRepository scheduleRepository;

  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> _teacherSchedulesForSelectedDate = [];
  List<ScheduleModel> _cachedTeacherSchedules = [];
  String? _cachedTeacherId;
  bool _isLoading = false;
  String? _errorMessage;

  ScheduleProvider({required this.scheduleRepository});

  List<ScheduleModel> get schedules => _schedules;
  List<ScheduleModel> get teacherSchedulesForSelectedDate => _teacherSchedulesForSelectedDate;
  List<ScheduleModel> get cachedTeacherSchedules => _cachedTeacherSchedules;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void clearTeacherSchedulesCache() {
    _cachedTeacherId = null;
    _cachedTeacherSchedules.clear();
  }

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

  Future<void> loadTeacherSchedules(String teacherId, DateTime date, {bool forceRefresh = false}) async {
    if (forceRefresh || _cachedTeacherId != teacherId || _cachedTeacherSchedules.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      try {
        _cachedTeacherSchedules = await scheduleRepository.getSchedulesForTeacher(teacherId);
        _cachedTeacherId = teacherId;
      } catch (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    _teacherSchedulesForSelectedDate = _cachedTeacherSchedules.where((s) {
      return s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day;
    }).toList();

    _isLoading = false;
    notifyListeners();
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
      clearTeacherSchedulesCache();
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
      clearTeacherSchedulesCache();
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
      clearTeacherSchedulesCache();
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
      clearTeacherSchedulesCache();
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
      clearTeacherSchedulesCache();
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
