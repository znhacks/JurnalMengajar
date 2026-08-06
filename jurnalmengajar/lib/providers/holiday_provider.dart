import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/holiday_model.dart';

class HolidayProvider with ChangeNotifier {
  List<HolidayModel> _holidays = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<HolidayModel> get holidays => _holidays;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadHolidays(String? schoolId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      String? targetSchoolId = schoolId;

      if (targetSchoolId == null || targetSchoolId.isEmpty || targetSchoolId == 'a1111111-1111-1111-1111-111111111111') {
        final schoolRes = await supabase.from('schools').select('id').limit(1).maybeSingle();
        if (schoolRes != null) {
          targetSchoolId = schoolRes['id'] as String?;
        }
      }

      if (targetSchoolId != null && targetSchoolId.isNotEmpty) {
        final res = await supabase
            .from('school_holidays')
            .select()
            .eq('school_id', targetSchoolId)
            .order('start_date', ascending: true);

        _holidays = (res as List)
            .map((json) => HolidayModel.fromJson(json))
            .toList();
      } else {
        _holidays = [];
      }
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add holiday and soft-delete existing journals on those dates
  Future<bool> addHoliday({
    required String? schoolId,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? createdBy,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;
      String? targetSchoolId = schoolId;

      // Dynamically fetch actual valid school_id from DB if passed dummy UUID
      final schoolRes = await supabase.from('schools').select('id').limit(1).maybeSingle();
      if (schoolRes != null) {
        final dbSchoolId = schoolRes['id'] as String?;
        if (targetSchoolId == null || targetSchoolId == 'a1111111-1111-1111-1111-111111111111') {
          targetSchoolId = dbSchoolId;
        }
      }

      if (targetSchoolId == null || targetSchoolId.isEmpty) {
        throw Exception('Tidak ada data sekolah terdaftar di database. Silakan buat/pilih sekolah terlebih dahulu.');
      }

      // 1. Insert holiday record
      final payload = {
        'school_id': targetSchoolId,
        'title': title,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate.toIso8601String().split('T').first,
        'description': description,
        'created_by': createdBy,
      };

      await supabase.from('school_holidays').insert(payload);

      // 2. Soft-delete journals within this date range for this school
      final startStr = startDate.toIso8601String().split('T').first;
      final endStr = endDate.add(const Duration(days: 1)).toIso8601String().split('T').first;

      await supabase
          .from('journals')
          .update({
            'is_soft_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .gte('date', startStr)
          .lt('date', endStr);

      await loadHolidays(schoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete holiday and restore soft-deleted journals
  Future<bool> deleteHoliday(String holidayId, String schoolId, {DateTime? startDate, DateTime? endDate}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final supabase = Supabase.instance.client;

      // Restore journals if dates are provided
      if (startDate != null && endDate != null) {
        final startStr = startDate.toIso8601String().split('T').first;
        final endStr = endDate.add(const Duration(days: 1)).toIso8601String().split('T').first;

        await supabase
            .from('journals')
            .update({
              'is_soft_deleted': false,
              'deleted_at': null,
            })
            .gte('date', startStr)
            .lt('date', endStr);
      }

      await supabase.from('school_holidays').delete().eq('id', holidayId);
      await loadHolidays(schoolId);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if a specific date is a holiday
  HolidayModel? getHolidayForDate(DateTime date) {
    final checkDate = DateTime(date.year, date.month, date.day);
    for (final h in _holidays) {
      final s = DateTime(h.startDate.year, h.startDate.month, h.startDate.day);
      final e = DateTime(h.endDate.year, h.endDate.month, h.endDate.day);
      if ((checkDate.isAfter(s) || checkDate.isAtSameMomentAs(s)) &&
          (checkDate.isBefore(e) || checkDate.isAtSameMomentAs(e))) {
        return h;
      }
    }
    return null;
  }
}
