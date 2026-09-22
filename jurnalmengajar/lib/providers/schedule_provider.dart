import 'package:flutter/material.dart';
import '../models/schedule_model.dart';
import '../repositories/schedule_repository.dart';
import '../core/services/cache_service.dart';
import '../core/utils/helper.dart';

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

  int _loadSequence = 0;
  Future<void>? _inFlightLoadAll;
  String? _inFlightSchoolId;
  Future<void>? _inFlightTeacherLoad;
  String? _inFlightTeacherKey;

  void clearTeacherSchedulesCache() {
    _cachedTeacherId = null;
    _cachedTeacherSchedules.clear();
  }

  Future<void> loadAllSchedules([String? schoolId]) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId?.trim();

    // In-flight coalescing: reuse ongoing request for the same schoolId
    if (_inFlightLoadAll != null && _inFlightSchoolId == cleanSchoolId) {
      return _inFlightLoadAll!;
    }

    final future = _executeLoadAllSchedules(cleanSchoolId);
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

  Future<void> _executeLoadAllSchedules(String? cleanSchoolId) async {
    final isSchoolChanged = cleanSchoolId != null && cleanSchoolId.isNotEmpty && cleanSchoolId != _currentSchoolId;

    if (isSchoolChanged) {
      _schedules = [];
      _teacherSchedulesForSelectedDate = [];
      _cachedTeacherSchedules = [];
      _cachedTeacherId = null;
      _errorMessage = null;
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_PROVIDER] Switched school context from "$_currentSchoolId" to "$cleanSchoolId". In-memory schedules purged.');
    }

    _currentSchoolId = cleanSchoolId ?? _currentSchoolId;
    _errorMessage = null;
    final int sequence = ++_loadSequence;

    // SWR Instant Cache Population: If _schedules is empty, show cached data immediately (0ms)
    final sKey = _currentSchoolId ?? 'default';
    if (_schedules.isEmpty) {
      try {
        final cached = await CacheService().loadList('schedules_$sKey');
        if (cached != null && cached.isNotEmpty && _schedules.isEmpty && sequence == _loadSequence) {
          _schedules = cached.map((s) => ScheduleModel.fromJson(s)).toList();
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
      final fresh = await scheduleRepository.getAll(_currentSchoolId);
      // Sequence and tenant check: drop stale response if context switched while in-flight
      if (sequence != _loadSequence || _currentSchoolId != cleanSchoolId) {
        debugPrint('[RUNTIME_DEBUG:SCHEDULE_PROVIDER] Stale loadAllSchedules dropped for $cleanSchoolId');
        return;
      }

      // Multi-tenant defense: ensure no schedule from another school slips in
      if (_currentSchoolId != null && _currentSchoolId!.isNotEmpty) {
        _schedules = fresh.where((s) {
          final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId);
          return sSchoolId == null || sSchoolId.isEmpty || sSchoolId == _currentSchoolId;
        }).toList();
      } else {
        _schedules = fresh;
      }
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_PROVIDER] Loaded ${_schedules.length} isolated schedules for $_currentSchoolId into ScheduleProvider state.');
    } catch (e) {
      if (sequence == _loadSequence) {
        _errorMessage = e.toString();
        debugPrint('[RUNTIME_DEBUG:SCHEDULE_PROVIDER] ERROR in loadAllSchedules: $e');
      }
    } finally {
      if (sequence == _loadSequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void setSchoolId(String? schoolId) {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId?.trim();
    if (cleanSchoolId != _currentSchoolId) {
      _currentSchoolId = cleanSchoolId;
      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        _cachedTeacherSchedules.removeWhere((s) {
          final sSchool = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
          return sSchool != null && sSchool.isNotEmpty && sSchool != cleanSchoolId;
        });
      } else {
        _cachedTeacherSchedules.clear();
      }
      _cachedTeacherId = null;
      _teacherSchedulesForSelectedDate.removeWhere((s) {
        if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
          final sSchool = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
          return sSchool != null && sSchool.isNotEmpty && sSchool != cleanSchoolId;
        }
        return false;
      });
    }
  }

  Future<void> loadTeacherSchedules(String teacherId, DateTime date, {bool forceRefresh = false}) async {
    final teacherKey = '${_currentSchoolId ?? "all"}_$teacherId';
    if (_inFlightTeacherLoad != null && _inFlightTeacherKey == teacherKey && !forceRefresh) {
      return _inFlightTeacherLoad!;
    }

    final future = _executeLoadTeacherSchedules(teacherId, date, forceRefresh: forceRefresh);
    _inFlightTeacherLoad = future;
    _inFlightTeacherKey = teacherKey;
    try {
      await future;
    } finally {
      if (_inFlightTeacherLoad == future) {
        _inFlightTeacherLoad = null;
        _inFlightTeacherKey = null;
      }
    }
  }

  Future<void> _executeLoadTeacherSchedules(String teacherId, DateTime date, {bool forceRefresh = false}) async {
    final cleanSchoolId = _currentSchoolId;
    final scopedKey = 'teacher_schedules_${cleanSchoolId ?? "all"}_$teacherId';

    // SWR Instant Cache Population for teacher schedules (check aligned keys)
    if (_cachedTeacherSchedules.isEmpty || _cachedTeacherId != teacherId) {
      try {
        final cached = await CacheService().loadList(scopedKey) ??
            await CacheService().loadList('teacher_schedules_$teacherId') ??
            await CacheService().loadList('schedules_teacher_$teacherId');
        if (cached != null && cached.isNotEmpty) {
          final mapped = cached.map((s) => ScheduleModel.fromJson(s)).toList();
          final filtered = (cleanSchoolId != null && cleanSchoolId.isNotEmpty)
              ? mapped.where((s) {
                  final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
                  return sSchoolId == null || sSchoolId.isEmpty || sSchoolId == cleanSchoolId;
                }).toList()
              : mapped;
          _cachedTeacherSchedules = filtered;
          _cachedTeacherId = teacherId;
          _teacherSchedulesForSelectedDate = _cachedTeacherSchedules.where((s) {
            if (!s.isActive) return false;
            return s.date.year == date.year &&
                s.date.month == date.month &&
                s.date.day == date.day;
          }).toList();
          notifyListeners();
        }
      } catch (_) {}
    }

    if (forceRefresh || _cachedTeacherId != teacherId || _cachedTeacherSchedules.isEmpty) {
      _isLoading = _cachedTeacherSchedules.isEmpty;
      _errorMessage = null;
      notifyListeners();
      try {
        final fresh = await scheduleRepository.getSchedulesForTeacher(teacherId);
        final filteredFresh = (cleanSchoolId != null && cleanSchoolId.isNotEmpty)
            ? fresh.where((s) {
                final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
                return sSchoolId == null || sSchoolId.isEmpty || sSchoolId == cleanSchoolId;
              }).toList()
            : fresh;

        if (filteredFresh.isNotEmpty || _cachedTeacherSchedules.isEmpty) {
          _cachedTeacherSchedules = filteredFresh;
          _cachedTeacherId = teacherId;
          try {
            CacheService().save(scopedKey, filteredFresh.map((e) => e.toJson()).toList());
          } catch (_) {}
        }
      } catch (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    _teacherSchedulesForSelectedDate = _cachedTeacherSchedules.where((s) {
      if (!s.isActive) return false;
      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
        if (sSchoolId != null && sSchoolId.isNotEmpty && sSchoolId != cleanSchoolId) {
          return false;
        }
      }
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
    Set<String>? excludeIds,
    required List<dynamic> teachers,
    List<dynamic>? classes,
  }) {
    if (!proposed.isActive) return;

    final proposedSchoolId = AppHelper.parseSingleCleanSchoolId(proposed.schoolId) ?? _currentSchoolId;

    for (final s in _schedules) {
      if (excludeId != null && s.id == excludeId) continue;
      if (excludeIds != null && excludeIds.contains(s.id)) continue;
      if (!s.isActive) continue;

      // Multi-tenant check: schedules in different schools do NOT conflict
      final scheduleSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId);
      if (proposedSchoolId != null &&
          proposedSchoolId.isNotEmpty &&
          scheduleSchoolId != null &&
          scheduleSchoolId.isNotEmpty &&
          proposedSchoolId != scheduleSchoolId) {
        continue;
      }

      // Date check
      final isSameDate = s.date.year == proposed.date.year &&
          s.date.month == proposed.date.month &&
          s.date.day == proposed.date.day;
      if (!isSameDate) continue;

      // Teaching hour check
      final isSameHour = s.teachingHour == proposed.teachingHour;
      if (!isSameHour) continue;

      final isSameTeacher = proposed.teacherId.isNotEmpty &&
          s.teacherId.isNotEmpty &&
          s.teacherId == proposed.teacherId;
      final isSameClass = proposed.classId.isNotEmpty &&
          s.classId.isNotEmpty &&
          s.classId == proposed.classId;

      // 1. Teacher Conflict: Same teacher already has a schedule at this hour
      if (isSameTeacher) {
        String teacherName = 'Guru';
        try {
          final t = teachers.firstWhere((t) => t.id == proposed.teacherId);
          teacherName = t.name;
        } catch (_) {
          try {
            final t = teachers.firstWhere((t) => t.id == s.teacherId);
            teacherName = t.name;
          } catch (_) {}
        }

        throw Exception(
          'Tidak bisa membuat jadwal.\n\n'
          'Guru: $teacherName\n'
          'Sudah memiliki jadwal pada Jam ke-${proposed.teachingHour}.\n\n'
          'Coba pilih jam lain'
        );
      }

      // 2. Class Conflict: Same class already has a schedule at this hour (by another teacher)
      if (isSameClass) {
        String className = 'Kelas';
        if (classes != null) {
          try {
            final c = classes.firstWhere((c) => c.id == proposed.classId);
            className = 'Kelas ${c.name}';
          } catch (_) {}
        }

        throw Exception(
          'Tidak bisa membuat jadwal.\n\n'
          '$className sudah memiliki jadwal pelajaran pada Jam ke-${proposed.teachingHour}.\n\n'
          'Coba pilih jam atau kelas lain'
        );
      }

      // If teachers are different and classes are different, it is ALLOWED.
    }
  }

  Future<bool> createSchedule(ScheduleModel model, List<dynamic> teachers, [List<dynamic>? classes]) async {
    _isLoading = true;
    notifyListeners();
    try {
      _validateNoActiveOverlap(model, teachers: teachers, classes: classes);
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

  Future<bool> createMultipleSchedules(List<ScheduleModel> models, List<dynamic> teachers, [List<dynamic>? classes, Set<String>? excludeIds]) async {
    _isLoading = true;
    notifyListeners();
    try {
      for (int i = 0; i < models.length; i++) {
        final m = models[i];
        _validateNoActiveOverlap(m, excludeIds: excludeIds, teachers: teachers, classes: classes);

        // Check intra-batch conflicts
        for (int j = i + 1; j < models.length; j++) {
          final other = models[j];
          if (!m.isActive || !other.isActive) continue;

          final sameDate = m.date.year == other.date.year &&
              m.date.month == other.date.month &&
              m.date.day == other.date.day;
          final sameHour = m.teachingHour == other.teachingHour;

          if (sameDate && sameHour) {
            if (m.teacherId.isNotEmpty && m.teacherId == other.teacherId) {
              String teacherName = 'Guru';
              try {
                final t = teachers.firstWhere((t) => t.id == m.teacherId);
                teacherName = t.name;
              } catch (_) {}
              throw Exception(
                'Tidak bisa membuat jadwal.\n\n'
                'Guru: $teacherName\n'
                'Sudah memiliki jadwal pada Jam ke-${m.teachingHour}.\n\n'
                'Coba pilih jam lain'
              );
            }

            if (m.classId.isNotEmpty && m.classId == other.classId) {
              String className = 'Kelas';
              if (classes != null) {
                try {
                  final c = classes.firstWhere((c) => c.id == m.classId);
                  className = 'Kelas ${c.name}';
                } catch (_) {}
              }
              throw Exception(
                'Tidak bisa membuat jadwal.\n\n'
                '$className sudah memiliki jadwal pelajaran pada Jam ke-${m.teachingHour}.\n\n'
                'Coba pilih jam atau kelas lain'
              );
            }
          }
        }
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

  Future<bool> updateSchedule(ScheduleModel model, List<dynamic> teachers, [List<dynamic>? classes]) async {
    _isLoading = true;
    notifyListeners();
    try {
      _validateNoActiveOverlap(model, excludeId: model.id, teachers: teachers, classes: classes);
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
