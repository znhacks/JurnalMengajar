import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';

class NoboxWaService {
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
      final parentPhone = student.parentPhoneNumber?.trim();
      if (parentPhone == null || parentPhone.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ Skip Nobox WA Notification: No parent phone number for ${student.name}');
        }
        return;
      }

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

      final response = await Supabase.instance.client.functions.invoke(
        'send-nobox-wa-notification',
        body: payload,
      );

      if (kDebugMode) {
        print('Nobox AI WA Response: ${response.status} - ${response.data}');
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
    String? parentPhone,
  }) async {
    try {
      final phone = parentPhone?.trim();
      if (phone == null || phone.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ Skip Nobox WA Daily Report: No destination phone number provided');
        }
        return;
      }

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
        'parent_phone': phone,
        'custom_message': reportText,
      };

      if (kDebugMode) {
        print('🤖 Sending Nobox AI WA Daily Report to $phone...');
      }

      final response = await Supabase.instance.client.functions.invoke(
        'send-nobox-wa-notification',
        body: payload,
      );

      if (kDebugMode) {
        print('Nobox AI WA Daily Report Response: ${response.status} - ${response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending Nobox WA Daily Report: $e');
      }
    }
  }
}
