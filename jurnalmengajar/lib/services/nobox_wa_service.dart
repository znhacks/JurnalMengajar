import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/student_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';

class NoboxWaService {
  static const String _edgeFunctionUrl =
      'https://egcxjuudphnbjwqhhbra.supabase.co/functions/v1/send-nobox-wa-notification';

  /// Send WhatsApp notification to parent via Nobox AI Edge Function
  static Future<void> sendAbsenceNotification({
    required StudentModel student,
    required String statusType, // 'S', 'I', or 'A' / 'Sakit', 'Izin', 'Alpha'
    required ClassModel classModel,
    required SubjectModel subjectModel,
    required DateTime date,
    String? note,
  }) async {
    try {
      String parentPhone = (student.parentPhoneNumber != null && student.parentPhoneNumber!.trim().isNotEmpty)
          ? student.parentPhoneNumber!.trim()
          : '082230090067';

      final payload = {
        'student_id': student.id,
        'student_name': student.name,
        'status_type': statusType,
        'class_name': classModel.name,
        'subject_name': subjectModel.name,
        'date': '${date.day}-${date.month}-${date.year}',
        'parent_phone': parentPhone,
        'note': note,
      };

      if (kDebugMode) {
        print('🤖 Sending Nobox AI WA Notification for ${student.name} to $parentPhone...');
      }

      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print('Nobox AI WA Response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending Nobox WA notification: $e');
      }
    }
  }

  /// Send formatted daily journal report via Nobox AI WhatsApp Gateway
  static Future<void> sendDailyJournalReport({
    required String teacherName,
    required String schoolName,
    required DateTime date,
    required List<Map<String, String>> journalItems,
    String parentPhone = '082230090067',
  }) async {
    try {
      const months = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final monthName = months[date.month];
      final formattedDate = '${date.day} - $monthName - ${date.year}';

      final buffer = StringBuffer();
      buffer.writeln('$teacherName | $schoolName');
      buffer.writeln('Laporan Harian : $formattedDate');
      buffer.writeln('');
      buffer.writeln('(Jurnal Mengajar)');

      if (journalItems.isEmpty) {
        buffer.writeln('- Belum ada jurnal mengajar terisi hari ini.');
      } else {
        for (final item in journalItems) {
          buffer.writeln('- Jam ke-${item['hour']} | ${item['class']} (${item['subject']}) - ${item['material']}');
        }
      }

      final reportText = buffer.toString();

      final payload = {
        'parent_phone': parentPhone,
        'custom_message': reportText,
      };

      if (kDebugMode) {
        print('🤖 Sending Nobox AI WA Daily Report to $parentPhone...');
      }

      final response = await http.post(
        Uri.parse(_edgeFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print('Nobox AI WA Daily Report Response: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending Nobox WA Daily Report: $e');
      }
    }
  }
}
