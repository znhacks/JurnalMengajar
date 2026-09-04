import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../repositories/schedule_repository.dart';

class ScheduleProvider with ChangeNotifier {
  final ScheduleRepository scheduleRepository;

  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> _teacherSchedulesForSelectedDate = [];
  List<ScheduleModel> _cachedTeacherSchedules = [];
  String? _cachedTeacherId;
  String? _currentSchoolId;
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

  Future<void> loadAllSchedules([String? schoolId]) async {
    _currentSchoolId = schoolId ?? _currentSchoolId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _schedules = await scheduleRepository.getAll(_currentSchoolId);
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

  void _validateNoActiveOverlap(
    ScheduleModel proposed, {
    String? excludeId,
    required List<dynamic> teachers,
  }) {
    if (!proposed.isActive) return;

    for (final s in _schedules) {
      if (s.id == excludeId) continue;
      if (s.isActive) {
        final dateStrS = "${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}";
        final dateStrProposed = "${proposed.date.year}-${proposed.date.month.toString().padLeft(2, '0')}-${proposed.date.day.toString().padLeft(2, '0')}";
        if (dateStrS == dateStrProposed) {
        
        final isSameTeacher = s.teacherId == proposed.teacherId;
        final isSameClass = s.classId == proposed.classId;
        final isSameHour = s.teachingHour == proposed.teachingHour;

        if (isSameHour && (isSameTeacher || isSameClass)) {
          String teacherName = 'Guru';
          try {
            final t = teachers.firstWhere((t) => t.id == s.teacherId);
            teacherName = t.name;
          } catch (_) {
            try {
              final t = teachers.firstWhere((t) => t.id == proposed.teacherId);
              teacherName = t.name;
            } catch (_) {}
          }

          throw Exception(
            'Tidak bisa membuat jadwal.\n\n'
            'Guru: $teacherName\n'
            'Jam yang terpakai: Jam ke-${proposed.teachingHour}\n\n'
            'Coba pilih jam lain'
          );
        }
      }
    }
  }
}

  Future<bool> createSchedule(ScheduleModel model, List<dynamic> teachers) async {
    _isLoading = true;
    notifyListeners();
    try {
      _validateNoActiveOverlap(model, teachers: teachers);
      final finalModel = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: _currentSchoolId)
          : model;
      await scheduleRepository.create(finalModel);
      clearTeacherSchedulesCache();
      await loadAllSchedules(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createMultipleSchedules(List<ScheduleModel> models, List<dynamic> teachers) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final m in models) {
        _validateNoActiveOverlap(m, teachers: teachers);
      }
      final finalModels = models.map((m) {
        if (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (m.schoolId == null || m.schoolId!.isEmpty)) {
          return m.copyWith(schoolId: _currentSchoolId);
        }
        return m;
      }).toList();
      await scheduleRepository.createMultiple(finalModels);
      clearTeacherSchedulesCache();
      await loadAllSchedules(_currentSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSchedule(ScheduleModel model, List<dynamic> teachers) async {
    _isLoading = true;
    notifyListeners();
    try {
      _validateNoActiveOverlap(model, excludeId: model.id, teachers: teachers);
      final finalModel = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: _currentSchoolId)
          : model;
      await scheduleRepository.update(finalModel);
      clearTeacherSchedulesCache();
      await loadAllSchedules(_currentSchoolId);
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
      await loadAllSchedules(_currentSchoolId);
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
      await loadAllSchedules(_currentSchoolId);
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
