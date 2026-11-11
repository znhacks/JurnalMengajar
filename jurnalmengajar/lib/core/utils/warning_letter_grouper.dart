import 'package:intl/intl.dart';
import '../../models/warning_letter_model.dart';
import '../../models/schedule_model.dart';
import 'helper.dart';

class GroupedWarningResult {
  final List<WarningLetterModel> schoolWarnings;
  final Map<String, List<WarningLetterModel>> groupedMap;
  final Map<String, DateTime> dateMap;
  final List<MapEntry<String, List<WarningLetterModel>>> sortedGroups;
  final Map<String, bool> groupStatusMap;
  final int pendingCount;
  final int completedCount;

  const GroupedWarningResult({
    required this.schoolWarnings,
    required this.groupedMap,
    required this.dateMap,
    required this.sortedGroups,
    required this.groupStatusMap,
    required this.pendingCount,
    required this.completedCount,
  });
}

class WarningLetterGrouper {
  /// Ekstraksi tanggal jadwal asli dari warning letter:
  /// 1. Dari schedule yang cocok (bila ada jadwal di cache)
  /// 2. Dari regex alasan: "pada tanggal d MMM yyyy"
  /// 3. Fallback ke issuedAt
  static DateTime extractWarningDate(
    WarningLetterModel warning, [
    List<ScheduleModel>? schedules,
  ]) {
    if (schedules != null && schedules.isNotEmpty) {
      final schedule = schedules
          .where((s) => s.id == warning.scheduleId)
          .firstOrNull;
      if (schedule != null && schedule.date.millisecondsSinceEpoch > 0) {
        return DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      }
    }

    final match = RegExp(r'pada tanggal (\d{1,2}\s+[A-Za-z]{3,4}\s+\d{4})').firstMatch(warning.reason);
    if (match != null) {
      final dateStr = match.group(1)!;
      try {
        final parsed = DateFormat('d MMM yyyy', 'id_ID').parse(dateStr);
        return DateTime(parsed.year, parsed.month, parsed.day);
      } catch (_) {
        try {
          final parsed = DateFormat('d MMM yyyy').parse(dateStr);
          return DateTime(parsed.year, parsed.month, parsed.day);
        } catch (_) {}
      }
    }

    return DateTime(warning.issuedAt.year, warning.issuedAt.month, warning.issuedAt.day);
  }

  /// Memfilter warning sesuai schoolId aktif dan membuang warning cacat (mis. Kelas--)
  static List<WarningLetterModel> filterSchoolWarnings(
    List<WarningLetterModel> warnings,
    String? activeSchoolId,
  ) {
    final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(activeSchoolId);
    return warnings.where((w) {
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final wSchoolId = AppHelper.parseSingleCleanSchoolId(w.schoolId);
        if (wSchoolId != null && wSchoolId.isNotEmpty && wSchoolId != cleanActiveSchoolId) {
          return false;
        }
      }
      if (w.reason.contains('Kelas--')) return false;
      return true;
    }).toList();
  }

  /// Mengelompokkan dan menghitung status warning berdasarkan tanggal jadwal
  static GroupedWarningResult groupWarnings({
    required List<WarningLetterModel> warnings,
    String? activeSchoolId,
    List<ScheduleModel>? schedules,
  }) {
    final schoolWarnings = filterSchoolWarnings(warnings, activeSchoolId);
    final Map<String, List<WarningLetterModel>> groupedMap = {};
    final Map<String, DateTime> dateMap = {};

    for (final warning in schoolWarnings) {
      final scheduleDate = extractWarningDate(warning, schedules);
      final dateKey = '${scheduleDate.year}-${scheduleDate.month.toString().padLeft(2, '0')}-${scheduleDate.day.toString().padLeft(2, '0')}';
      groupedMap.putIfAbsent(dateKey, () => []).add(warning);
      dateMap.putIfAbsent(dateKey, () => scheduleDate);
    }

    final sortedGroups = groupedMap.entries.toList()
      ..sort((a, b) {
        final dateA = dateMap[a.key]!;
        final dateB = dateMap[b.key]!;
        return dateB.compareTo(dateA);
      });

    int pendingCount = 0;
    int completedCount = 0;
    final Map<String, bool> groupStatusMap = {};

    for (final entry in groupedMap.entries) {
      final gWarnings = entry.value;
      final hasUnread = gWarnings.any((w) => w.status == 'unread');
      final isPending = hasUnread;
      groupStatusMap[entry.key] = isPending;
      if (isPending) {
        pendingCount++;
      } else {
        completedCount++;
      }
    }

    return GroupedWarningResult(
      schoolWarnings: schoolWarnings,
      groupedMap: groupedMap,
      dateMap: dateMap,
      sortedGroups: sortedGroups,
      groupStatusMap: groupStatusMap,
      pendingCount: pendingCount,
      completedCount: completedCount,
    );
  }

  /// Menghitung jumlah grup tanggal yang masih berstatus pending (memiliki unread)
  static int countPendingGroups({
    required List<WarningLetterModel> warnings,
    String? activeSchoolId,
    List<ScheduleModel>? schedules,
  }) {
    return groupWarnings(
      warnings: warnings,
      activeSchoolId: activeSchoolId,
      schedules: schedules,
    ).pendingCount;
  }
}

