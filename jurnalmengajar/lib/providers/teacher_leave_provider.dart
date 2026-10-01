import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/teacher_leave_model.dart';
import '../core/utils/helper.dart';
import '../core/services/cache_service.dart';

class TeacherLeaveProvider with ChangeNotifier {
  List<TeacherLeaveModel> _leaves = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentSchoolId;
  int _loadSequence = 0;
  Future<void>? _inFlightLoadLeaves;
  String? _inFlightSchoolId;

  List<TeacherLeaveModel> get leaves => _leaves;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadLeaves(String? schoolId) async {
    final cleanId = AppHelper.parseSingleCleanSchoolId(schoolId);
    final targetSchoolId = (cleanId != null && cleanId.isNotEmpty) ? cleanId : schoolId?.trim();

    if (_inFlightLoadLeaves != null && _inFlightSchoolId == targetSchoolId) {
      return _inFlightLoadLeaves!;
    }

    final future = _executeLoadLeaves(targetSchoolId);
    _inFlightLoadLeaves = future;
    _inFlightSchoolId = targetSchoolId;
    try {
      await future;
    } finally {
      if (_inFlightLoadLeaves == future) {
        _inFlightLoadLeaves = null;
        _inFlightSchoolId = null;
      }
    }
  }

  Future<void> _executeLoadLeaves(String? targetSchoolId) async {
    final isSchoolChanged = targetSchoolId != null &&
        targetSchoolId.isNotEmpty &&
        targetSchoolId != _currentSchoolId;
    if (isSchoolChanged) {
      _leaves = [];
      _errorMessage = null;
    }
    _currentSchoolId = targetSchoolId ?? _currentSchoolId;
    _errorMessage = null;
    final int sequence = ++_loadSequence;

    // SWR Instant Cache: load cached leaves immediately
    if (_leaves.isEmpty && _currentSchoolId != null && _currentSchoolId!.isNotEmpty) {
      try {
        final cached = await CacheService().loadList('teacher_leaves_$_currentSchoolId');
        if (cached != null && cached.isNotEmpty && _leaves.isEmpty && sequence == _loadSequence) {
          _leaves = cached.map((json) => TeacherLeaveModel.fromJson(json)).toList();
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
      final supabase = Supabase.instance.client;
      String? resolvedSchoolId = _currentSchoolId;

      if (resolvedSchoolId == null ||
          resolvedSchoolId.isEmpty ||
          resolvedSchoolId == 'a1111111-1111-1111-1111-111111111111') {
        final schoolRes = await supabase.from('schools').select('id').limit(1).maybeSingle();
        if (schoolRes != null) {
          resolvedSchoolId = schoolRes['id'] as String?;
        }
      }

      if (resolvedSchoolId != null && resolvedSchoolId.isNotEmpty) {
        final res = await supabase
            .from('teacher_leaves')
            .select()
            .eq('school_id', resolvedSchoolId)
            .order('start_date', ascending: false);

        if (sequence != _loadSequence || _currentSchoolId != targetSchoolId) {
          return;
        }

        final List<TeacherLeaveModel> fresh = (res as List)
            .map((json) => TeacherLeaveModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();

        _leaves = fresh;

        // Persist to local cache for instant SWR
        final cacheable = (res as List)
            .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
            .toList();
        CacheService().save('teacher_leaves_$resolvedSchoolId', cacheable);
      } else {
        _leaves = [];
      }
    } catch (e) {
      if (sequence == _loadSequence) {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      }
    } finally {
      if (sequence == _loadSequence) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Add a new leave and link substitute teachers to specific schedules
  Future<bool> addLeave({
    required String? schoolId,
    required String teacherId,
    required DateTime startDate,
    required DateTime endDate,
    String? reason,
    required List<LeaveSubstituteItem> substitutes,
    String? createdBy,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final cleanId = AppHelper.parseSingleCleanSchoolId(schoolId);
      String? targetSchoolId = (cleanId != null && cleanId.isNotEmpty)
          ? cleanId
          : schoolId?.trim();

      final schoolRes = await supabase.from('schools').select('id').limit(1).maybeSingle();
      if (schoolRes != null) {
        final dbSchoolId = schoolRes['id'] as String?;
        if (targetSchoolId == null ||
            targetSchoolId.isEmpty ||
            targetSchoolId == 'a1111111-1111-1111-1111-111111111111') {
          targetSchoolId = dbSchoolId;
        }
      }

      if (targetSchoolId == null || targetSchoolId.isEmpty) {
        throw Exception('Sekolah belum teridentifikasi.');
      }

      // 1. Insert leave record
      final payload = {
        'school_id': targetSchoolId,
        'teacher_id': teacherId,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate.toIso8601String().split('T').first,
        'reason': reason,
        'status': 'active',
        'substitutes': substitutes.map((s) => s.toJson()).toList(),
        'created_by': createdBy,
      };

      await supabase.from('teacher_leaves').insert(payload);

      // 2. Link substitute teachers to specific schedule records
      for (final sub in substitutes) {
        if (sub.scheduleId.isNotEmpty && sub.substituteTeacherId.isNotEmpty) {
          try {
            await supabase.from('schedules').update({
              'substitute_teacher_id': sub.substituteTeacherId,
            }).eq('id', sub.scheduleId);
          } catch (err) {
            debugPrint('Note: Error linking substitute to schedule ${sub.scheduleId}: $err');
          }
        }
      }

      CacheService().remove('teacher_leaves_$targetSchoolId');
      await loadLeaves(targetSchoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete a leave and restore schedule substitute links
  Future<bool> deleteLeave(
    String leaveId,
    String? schoolId,
    List<LeaveSubstituteItem> substitutes,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      final cleanId = AppHelper.parseSingleCleanSchoolId(schoolId);
      final targetSchoolId = (cleanId != null && cleanId.isNotEmpty)
          ? cleanId
          : schoolId?.trim();

      // 1. Revert substitute teachers on schedules
      for (final sub in substitutes) {
        if (sub.scheduleId.isNotEmpty) {
          try {
            await supabase.from('schedules').update({
              'substitute_teacher_id': null,
            }).eq('id', sub.scheduleId);
          } catch (err) {
            debugPrint('Note: Error reverting substitute on schedule ${sub.scheduleId}: $err');
          }
        }
      }

      // 2. Delete the leave record
      await supabase.from('teacher_leaves').delete().eq('id', leaveId);

      if (targetSchoolId != null && targetSchoolId.isNotEmpty) {
        CacheService().remove('teacher_leaves_$targetSchoolId');
        await loadLeaves(targetSchoolId);
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
