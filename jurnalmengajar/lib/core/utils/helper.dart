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
}
