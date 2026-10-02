import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule_model.dart';
import '../repositories/schedule_repository.dart';
import '../core/services/cache_service.dart';
import '../core/utils/helper.dart';

const _uuid = Uuid();

class ScheduleProvider with ChangeNotifier {
  final ScheduleRepository scheduleRepository;

  List<ScheduleModel> _schedules = [];
  List<ScheduleModel> _teacherSchedulesForSelectedDate = [];
  List<ScheduleModel> _cachedTeacherSchedules = [];
  String? _cachedTeacherId;
  DateTime? _cachedSelectedDate;
  String? _currentSchoolId;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAllSchedulesLoaded = false;

  ScheduleProvider({required this.scheduleRepository});

  List<ScheduleModel> get schedules => _schedules;
  List<ScheduleModel> get teacherSchedulesForSelectedDate => _teacherSchedulesForSelectedDate;
  List<ScheduleModel> get cachedTeacherSchedules => _cachedTeacherSchedules;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAllSchedulesLoaded => _isAllSchedulesLoaded;

  int _loadSequence = 0;
  Future<void>? _inFlightLoadAll;
  String? _inFlightSchoolId;
  Future<void>? _inFlightTeacherLoad;
  String? _inFlightTeacherKey;

  void clearTeacherSchedulesCache() {
    _cachedTeacherId = null;
    _cachedTeacherSchedules.clear();
    _teacherSchedulesForSelectedDate.clear();
    _cachedSelectedDate = null;
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
        _schedules.removeWhere((s) {
          final sSchool = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
          return sSchool != null && sSchool.isNotEmpty && sSchool != cleanSchoolId;
        });
        _teacherSchedulesForSelectedDate.removeWhere((s) {
          final sSchool = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
          return sSchool != null && sSchool.isNotEmpty && sSchool != cleanSchoolId;
        });
      } else {
        _cachedTeacherSchedules.clear();
        _schedules.clear();
        _teacherSchedulesForSelectedDate.clear();
      }
      _cachedTeacherId = null;
      _cachedSelectedDate = null;
      _isAllSchedulesLoaded = false;
      _errorMessage = null;
    }
  }

  Future<void> loadAllSchedules([String? schoolId]) async {
    return _loadAllSchedulesInternal(schoolId, forceRefresh: false);
  }

  Future<void> refreshAllSchedules([String? schoolId]) async {
    return _loadAllSchedulesInternal(schoolId, forceRefresh: true);
  }

  Future<void> _loadAllSchedulesInternal(String? schoolId, {bool forceRefresh = false}) async {
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(schoolId) ?? schoolId?.trim();

    // Instant return: data already in memory for this school and not forced (0ms)
    if (!forceRefresh &&
        _isAllSchedulesLoaded &&
        _currentSchoolId == cleanSchoolId &&
        _schedules.isNotEmpty) {
      return;
    }

    // In-flight coalescing: reuse ongoing request for the same schoolId
    if (_inFlightLoadAll != null && _inFlightSchoolId == cleanSchoolId) {
      return _inFlightLoadAll!;
    }

    final future = _executeLoadAllSchedules(cleanSchoolId, forceRefresh: forceRefresh);
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

  Future<void> _executeLoadAllSchedules(String? cleanSchoolId, {bool forceRefresh = false}) async {
    final isSchoolChanged = cleanSchoolId != null && cleanSchoolId.isNotEmpty && cleanSchoolId != _currentSchoolId;

    if (isSchoolChanged) {
      _schedules.clear();
      _teacherSchedulesForSelectedDate.clear();
      _cachedTeacherSchedules.clear();
      _cachedTeacherId = null;
      _cachedSelectedDate = null;
      _isAllSchedulesLoaded = false;
      _errorMessage = null;
      debugPrint('[RUNTIME_DEBUG:SCHEDULE_PROVIDER] Switched school context from "$_currentSchoolId" to "$cleanSchoolId". In-memory schedules purged.');
    }

    _currentSchoolId = cleanSchoolId ?? _currentSchoolId;
    _errorMessage = null;
    final int sequence = ++_loadSequence;

    final sKey = _currentSchoolId ?? 'default';
<<<<<<< HEAD

    // SWR Instant Cache Population: If _schedules is empty, show disk cached data immediately (0ms)
    if (_schedules.isEmpty) {
=======
    final bool hasExistingSchedules = _schedules.isNotEmpty;
    if (!hasExistingSchedules) {
>>>>>>> 42f140080d98300baf8a264598c45787a22e022c
      try {
        final cached = await CacheService().loadList('schedules_$sKey');
        if (cached != null && cached.isNotEmpty && _schedules.isEmpty && sequence == _loadSequence) {
          final mapped = cached.map((s) => ScheduleModel.fromJson(s)).toList();
          _schedules = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty)
              ? mapped.where((s) => AppHelper.parseSingleCleanSchoolId(s.schoolId) == _currentSchoolId).toList()
              : mapped;
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
    }
    // CRITICAL: If _schedules is already populated in memory, NEVER set _isLoading = true!
    // This completely prevents UI flickering / loading spinners on page transitions!

    try {
      final fresh = await scheduleRepository.getAll(_currentSchoolId);
      // Sequence and tenant check: drop stale response if context switched while in-flight
      if (sequence != _loadSequence || _currentSchoolId != cleanSchoolId) {
        debugPrint('[RUNTIME_DEBUG:SCHEDULE_PROVIDER] Stale loadAllSchedules dropped for $cleanSchoolId');
        return;
      }

      // Multi-tenant defense: ensure only schedules strictly matching this school are kept
      if (_currentSchoolId != null && _currentSchoolId!.isNotEmpty) {
        _schedules = fresh.where((s) {
          final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
          return sSchoolId == _currentSchoolId;
        }).toList();
      } else {
        _schedules = fresh;
      }

      _isAllSchedulesLoaded = true;

      // Asynchronously cache to disk
      try {
        CacheService().save('schedules_$sKey', _schedules.map((e) => e.toJson()).toList());
      } catch (_) {}

      // Keep teacher cache in sync if one is currently viewed
      if (_cachedTeacherId != null) {
        _cachedTeacherSchedules = _schedules.where((s) => s.teacherId == _cachedTeacherId).toList();
        if (_cachedSelectedDate != null) {
          _updateTeacherSchedulesForDate(_cachedSelectedDate!, shouldNotify: false);
        }
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

  Future<void> loadTeacherSchedules(String teacherId, DateTime date, {bool forceRefresh = false}) async {
    final cleanSchoolId = _currentSchoolId;

    // 1. Fast path: teacher schedules are already loaded in memory for this teacher
    if (!forceRefresh && _cachedTeacherId == teacherId && _cachedTeacherSchedules.isNotEmpty) {
      _updateTeacherSchedulesForDate(date);
      return;
    }

    // 2. Fast path: all schedules are already loaded in memory for this school, extract directly!
    if (!forceRefresh && _isAllSchedulesLoaded && _schedules.isNotEmpty) {
      final teacherScheds = _schedules.where((s) {
        if (s.teacherId != teacherId) return false;
        if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
          final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
          return sSchoolId == cleanSchoolId;
        }
        return true;
      }).toList();

      _cachedTeacherId = teacherId;
      _cachedTeacherSchedules = teacherScheds;
      _updateTeacherSchedulesForDate(date);
      return;
    }

    final teacherKey = '${cleanSchoolId ?? "all"}_$teacherId';
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

  void _updateTeacherSchedulesForDate(DateTime date, {bool shouldNotify = true}) {
    _cachedSelectedDate = date;
    final cleanSchoolId = _currentSchoolId;

    final filtered = _cachedTeacherSchedules.where((s) {
      if (!s.isActive) return false;
      if (cleanSchoolId != null && cleanSchoolId.isNotEmpty) {
        final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
        if (sSchoolId != cleanSchoolId) return false;
      }
      return s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day;
    }).toList();

    _teacherSchedulesForSelectedDate = filtered;
    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<void> _executeLoadTeacherSchedules(String teacherId, DateTime date, {bool forceRefresh = false}) async {
    final cleanSchoolId = _currentSchoolId;
    final scopedKey = 'teacher_schedules_${cleanSchoolId ?? "all"}_$teacherId';

    // SWR Instant Cache Population for teacher schedules
    if (_cachedTeacherSchedules.isEmpty || _cachedTeacherId != teacherId) {
      try {
        final cached = await CacheService().loadList(scopedKey) ??
            (cleanSchoolId == null ? await CacheService().loadList('teacher_schedules_$teacherId') : null);
        if (cached != null && cached.isNotEmpty) {
          final mapped = cached.map((s) => ScheduleModel.fromJson(s)).toList();
          final filtered = (cleanSchoolId != null && cleanSchoolId.isNotEmpty)
              ? mapped.where((s) {
                  final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
                  return sSchoolId == cleanSchoolId;
                }).toList()
              : mapped;

          if (filtered.isNotEmpty) {
            _cachedTeacherSchedules = filtered;
            _cachedTeacherId = teacherId;
            _updateTeacherSchedulesForDate(date, shouldNotify: false);
            _isLoading = false;
            notifyListeners();
          }
        }
      } catch (_) {}
    }

    if (forceRefresh || _cachedTeacherId != teacherId || _cachedTeacherSchedules.isEmpty) {
      // Only set isLoading = true if we have no in-memory data to display
      if (_cachedTeacherSchedules.isEmpty) {
        _isLoading = true;
        _errorMessage = null;
        notifyListeners();
      }

      try {
        final fresh = await scheduleRepository.getSchedulesForTeacher(teacherId);
        final filteredFresh = (cleanSchoolId != null && cleanSchoolId.isNotEmpty)
            ? fresh.where((s) {
                final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
                return sSchoolId == cleanSchoolId;
              }).toList()
            : fresh;

        if (filteredFresh.isNotEmpty || _cachedTeacherSchedules.isEmpty) {
          _cachedTeacherSchedules = filteredFresh;
          _cachedTeacherId = teacherId;
          try {
            CacheService().save(scopedKey, filteredFresh.map((e) => e.toJson()).toList());
          } catch (_) {}
        } else {
          _cachedTeacherId = teacherId;
        }
      } catch (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
        return;
      }
    }

    _updateTeacherSchedulesForDate(date, shouldNotify: false);
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

  void _syncDiskCache() {
    try {
      final sKey = _currentSchoolId ?? 'default';
      CacheService().save('schedules_$sKey', _schedules.map((e) => e.toJson()).toList());
      if (_cachedTeacherId != null) {
        final scopedKey = 'teacher_schedules_${_currentSchoolId ?? "all"}_$_cachedTeacherId';
        CacheService().save(scopedKey, _cachedTeacherSchedules.map((e) => e.toJson()).toList());
      }
    } catch (_) {}
  }

  Future<bool> createSchedule(ScheduleModel model, List<dynamic> teachers, [List<dynamic>? classes]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _validateNoActiveOverlap(model, teachers: teachers, classes: classes);
      final id = model.id.isNotEmpty ? model.id : _uuid.v4();
      final finalModel = model.copyWith(
        id: id,
        schoolId: (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
            ? _currentSchoolId
            : model.schoolId,
      );
      await scheduleRepository.create(finalModel);

      // Add to local state immediately
      _schedules.removeWhere((s) => s.id == finalModel.id);
      _schedules.add(finalModel);
      _schedules.sort((a, b) => a.date.compareTo(b.date));

      if (_cachedTeacherId != null && _cachedTeacherId == finalModel.teacherId) {
        _cachedTeacherSchedules.removeWhere((s) => s.id == finalModel.id);
        _cachedTeacherSchedules.add(finalModel);
        _cachedTeacherSchedules.sort((a, b) => a.date.compareTo(b.date));
        if (_cachedSelectedDate != null) {
          _updateTeacherSchedulesForDate(_cachedSelectedDate!, shouldNotify: false);
        }
      }

      _syncDiskCache();
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
    _errorMessage = null;
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
        final id = m.id.isNotEmpty ? m.id : _uuid.v4();
        return m.copyWith(
          id: id,
          schoolId: (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (m.schoolId == null || m.schoolId!.isEmpty))
              ? _currentSchoolId
              : m.schoolId,
        );
      }).toList();

      await scheduleRepository.createMultiple(finalModels);

      final newIds = finalModels.map((m) => m.id).toSet();
      _schedules.removeWhere((s) => newIds.contains(s.id));
      _schedules.addAll(finalModels);
      _schedules.sort((a, b) => a.date.compareTo(b.date));

      if (_cachedTeacherId != null) {
        _cachedTeacherSchedules.removeWhere((s) => newIds.contains(s.id));
        final matchingTeacherModels = finalModels.where((m) => m.teacherId == _cachedTeacherId);
        _cachedTeacherSchedules.addAll(matchingTeacherModels);
        _cachedTeacherSchedules.sort((a, b) => a.date.compareTo(b.date));
        if (_cachedSelectedDate != null) {
          _updateTeacherSchedulesForDate(_cachedSelectedDate!, shouldNotify: false);
        }
      }

      _syncDiskCache();
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
    _errorMessage = null;
    notifyListeners();
    try {
      _validateNoActiveOverlap(model, excludeId: model.id, teachers: teachers, classes: classes);
      final finalModel = (_currentSchoolId != null && _currentSchoolId!.isNotEmpty && (model.schoolId == null || model.schoolId!.isEmpty))
          ? model.copyWith(schoolId: _currentSchoolId)
          : model;
      await scheduleRepository.update(finalModel);

      final sIndex = _schedules.indexWhere((s) => s.id == finalModel.id);
      if (sIndex != -1) {
        _schedules[sIndex] = finalModel;
        _schedules.sort((a, b) => a.date.compareTo(b.date));
      }

      final cIndex = _cachedTeacherSchedules.indexWhere((s) => s.id == finalModel.id);
      if (cIndex != -1) {
        _cachedTeacherSchedules[cIndex] = finalModel;
        _cachedTeacherSchedules.sort((a, b) => a.date.compareTo(b.date));
      }

      final tIndex = _teacherSchedulesForSelectedDate.indexWhere((s) => s.id == finalModel.id);
      if (tIndex != -1) {
        _teacherSchedulesForSelectedDate[tIndex] = finalModel;
      } else if (_cachedSelectedDate != null) {
        _updateTeacherSchedulesForDate(_cachedSelectedDate!, shouldNotify: false);
      }

      _syncDiskCache();
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
    final removedIndex = _schedules.indexWhere((s) => s.id == id);
    final removedModel = removedIndex != -1 ? _schedules[removedIndex] : null;

    // Optimistic instant delete (0ms)
    _schedules.removeWhere((s) => s.id == id);
    _cachedTeacherSchedules.removeWhere((s) => s.id == id);
    _teacherSchedulesForSelectedDate.removeWhere((s) => s.id == id);
    _syncDiskCache();
    notifyListeners();

    try {
      await scheduleRepository.delete(id);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      // Rollback on failure
      if (removedModel != null) {
        if (removedIndex >= 0 && removedIndex <= _schedules.length) {
          _schedules.insert(removedIndex, removedModel);
        } else {
          _schedules.add(removedModel);
        }
        if (_cachedTeacherId == removedModel.teacherId) {
          _cachedTeacherSchedules.add(removedModel);
          _cachedTeacherSchedules.sort((a, b) => a.date.compareTo(b.date));
          if (_cachedSelectedDate != null) {
            _updateTeacherSchedulesForDate(_cachedSelectedDate!, shouldNotify: false);
          }
        }
        _syncDiskCache();
        notifyListeners();
      }
      return false;
    }
  }

  Future<bool> deleteMultipleSchedules(List<String> ids) async {
    if (ids.isEmpty) return true;
    final idSet = ids.toSet();

    final removedModels = _schedules.where((s) => idSet.contains(s.id)).toList();

    // Optimistic instant delete (0ms)
    _schedules.removeWhere((s) => idSet.contains(s.id));
    _cachedTeacherSchedules.removeWhere((s) => idSet.contains(s.id));
    _teacherSchedulesForSelectedDate.removeWhere((s) => idSet.contains(s.id));
    _syncDiskCache();
    notifyListeners();

    try {
      await scheduleRepository.deleteMultiple(ids);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      // Rollback on failure
      _schedules.addAll(removedModels);
      _schedules.sort((a, b) => a.date.compareTo(b.date));
      if (_cachedTeacherId != null) {
        _cachedTeacherSchedules = _schedules.where((s) => s.teacherId == _cachedTeacherId).toList();
        if (_cachedSelectedDate != null) {
          _updateTeacherSchedulesForDate(_cachedSelectedDate!, shouldNotify: false);
        }
      }
      _syncDiskCache();
      notifyListeners();
      return false;
    }
  }
}
