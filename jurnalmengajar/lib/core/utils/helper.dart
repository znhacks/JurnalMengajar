import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppHelper {
  static String formatDate(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
  }

  static String formatDateShort(DateTime date) {
    return DateFormat('d MMM yyyy', 'id_ID').format(date);
  }

  static String formatTime(String time) {
    return time;
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return const Color(0xFF10B981); // Emerald 500 (Green)
      case 'rejected':
        return const Color(0xFFEF4444); // Red 500
      case 'pending':
      default:
        return const Color(0xFFF59E0B); // Amber 500
    }
  }

  static String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
        return 'Terverifikasi';
      case 'rejected':
        return 'Ditolak';
      case 'pending':
      default:
        return 'Menunggu Verifikasi';
    }
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static String formatTeachingHours(List<int> hours) {
    if (hours.isEmpty) return '-';
    final sorted = hours.toSet().toList()..sort();
    if (sorted.length == 1) return '${sorted.first}';

    bool isConsecutive = true;
    for (int i = 0; i < sorted.length - 1; i++) {
      if (sorted[i + 1] != sorted[i] + 1) {
        isConsecutive = false;
        break;
      }
    }

    if (isConsecutive && sorted.length >= 2) {
      return '${sorted.first}-${sorted.last}';
    }
    return sorted.join(', ');
  }

  /// Safely extracts and cleans a list of unique school IDs from any input
  /// (dynamic List, JSON stringified array '["..."]', Postgres array '{...}', comma string '..., ...', or single UUID string).
  static List<String> parseAndCleanSchoolIds(dynamic rawInput) {
    if (rawInput == null) return [];
    final List<String> result = [];

    void addClean(String s) {
      final cleaned = s
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll('"', '')
          .replaceAll("'", '')
          .replaceAll(r'\', '')
          .trim();
      if (cleaned.isNotEmpty && !result.contains(cleaned)) {
        result.add(cleaned);
      }
    }

    if (rawInput is List) {
      for (final item in rawInput) {
        if (item != null) {
          if (item is List) {
            result.addAll(parseAndCleanSchoolIds(item));
          } else {
            final str = item.toString();
            if (str.contains(',')) {
              for (final part in str.split(',')) {
                addClean(part);
              }
            } else {
              addClean(str);
            }
          }
        }
      }
    } else if (rawInput is String) {
      final str = rawInput.trim();
      if (str.isNotEmpty) {
        final parts = str.split(',');
        for (final part in parts) {
          addClean(part);
        }
      }
    }

    return result.toSet().toList();
  }

  /// Safely extracts a single canonical clean school ID (UUID string) from any input.
  static String? parseSingleCleanSchoolId(dynamic rawInput) {
    if (rawInput == null) return null;
    final ids = parseAndCleanSchoolIds(rawInput);
    return ids.isNotEmpty ? ids.first : null;
  }

  /// Checks if a given targetSchoolId matches any school IDs in userSchoolId or userSchoolIds.
  static bool matchesSchool(dynamic userSchoolIdInput, dynamic userSchoolIdsInput, String targetSchoolId) {
    if (targetSchoolId.isEmpty) return true;
    final cleanTarget = parseSingleCleanSchoolId(targetSchoolId) ?? targetSchoolId.trim();
    final allIds = <String>{
      ...parseAndCleanSchoolIds(userSchoolIdInput),
      ...parseAndCleanSchoolIds(userSchoolIdsInput),
    };
    return allIds.contains(cleanTarget);
  }
}

