import 'package:flutter/foundation.dart';
import 'package:nobox_chat_sdk/core/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';

class NoboxWaService {
  static const String defaultAccountId = '852562967880453';
  static const String defaultChannelId = '1';
  static const String defaultApiKey = 'Nobox-907bfe154e614d5b8be361f020e5ef62';
  /// Formats absence WhatsApp notification according to official template
  static String formatAbsenceMessage({
    required String studentName,
    required DateTime date,
    required String subjectName,
    required String statusType,
  }) {
    final formattedDate = '${date.day}-${date.month}-${date.year}';
    final st = statusType.trim().toLowerCase();
    String reasonText;
    if (st == 's' || st == 'sakit') {
      reasonText = 'Sakit';
    } else if (st == 'i' || st == 'izin') {
      reasonText = 'Izin';
    } else if (st == 'a' || st == 'alpha' || st == 'alfa') {
      reasonText = 'Alpha';
    } else {
      reasonText = statusType;
    }

    return '📢 *NOTIFIKASI ABSENSI SISWA*\n\n'
        'Yth. Orang Tua/Wali dari *$studentName*,\n\n'
        'Menginfokan bahwa pada:\n'
        '📅 Tanggal: $formattedDate\n'
        '📚 Mata Pelajaran: $subjectName\n\n'
        'Pemberitahuan: Anak Anda tidak masuk karena: *$reasonText*\n\n'
        'Mohon bantuannya untuk memantau putra/putri Bapak/Ibu.\n'
        'Terima kasih.';
  }

  /// Dispatch message directly using official nobox_chat_sdk
  static Future<bool> _sendViaNoboxSdk({
    required String phone,
    required String message,
    String? schoolId,
  }) async {
    try {
      final clean = phone.replaceAll(RegExp(r'\D'), '');
      final targetPhone = clean.startsWith('0') ? '62${clean.substring(1)}' : clean;

      String apiKey = defaultApiKey;
      String channelId = defaultChannelId;
      String accountId = defaultAccountId;

      // Check school specific config if available
      if (schoolId != null && schoolId.isNotEmpty) {
        try {
          final res = await Supabase.instance.client
              .from('school_nobox_configs')
              .select('api_key, channel_id, account_id, is_active')
              .eq('school_id', schoolId)
              .maybeSingle();
          if (res != null && res['api_key'] != null && res['is_active'] != false) {
            final key = res['api_key'].toString().trim();
            if (key.isNotEmpty) apiKey = key;
            if (res['channel_id'] != null && res['channel_id'].toString().isNotEmpty) {
              channelId = res['channel_id'].toString().trim();
            }
            if (res['account_id'] != null && res['account_id'].toString().isNotEmpty) {
              accountId = res['account_id'].toString().trim();
            }
          }
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', apiKey);

      final apiService = ApiService();
      final result = await apiService.sendMessage(
        '', // roomId
        targetPhone,
        channelId,
        'WhatsApp',
        accountId,
        message,
        type: '1',
      );

      if (kDebugMode) {
        print('nobox_chat_sdk sendMessage result: $result');
      }

      if (result['IsError'] == false) {
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('nobox_chat_sdk direct send failed, will use edge function fallback: $e');
      }
      return false;
    }
  }

  /// Send WhatsApp notification to parent via Nobox AI
  static Future<bool> sendAbsenceNotification({
    required StudentModel student,
    required String statusType, // 'S', 'I', or 'A' / 'Sakit', 'Izin', 'Alpha'
    required ClassModel classModel,
    required SubjectModel subjectModel,
    required DateTime date,
    String? schoolId,
    String? userId,
    String? note,
  }) async {
    try {
      var parentPhone = student.parentPhoneNumber?.trim();
      if ((parentPhone == null || parentPhone.isEmpty) && student.id.isNotEmpty) {
        try {
          final res = await Supabase.instance.client
              .from('students')
              .select('parent_phone_number')
              .eq('id', student.id)
              .maybeSingle();
          if (res != null && res['parent_phone_number'] != null) {
            parentPhone = res['parent_phone_number']?.toString().trim();
          }
        } catch (_) {}
      }

      if (parentPhone == null || parentPhone.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ Skip Nobox WA Notification: No parent phone number for ${student.name}');
        }
        return false;
      }

      final customMessage = formatAbsenceMessage(
        studentName: student.name,
        date: date,
        subjectName: subjectModel.name,
        statusType: statusType,
      );

      // 1. Primary dispatch via official nobox_chat_sdk
      final sentWithSdk = await _sendViaNoboxSdk(
        phone: parentPhone,
        message: customMessage,
        schoolId: schoolId,
      );

      if (sentWithSdk) {
        if (kDebugMode) {
          print('✅ Notification successfully sent via nobox_chat_sdk for ${student.name}');
        }
        return true;
      }

      // 2. Resilient Fallback via Supabase Edge Function
      final payload = {
        'student_id': student.id,
        'student_name': student.name,
        'status_type': statusType,
        'class_name': classModel.name,
        'subject_name': subjectModel.name,
        'date': '${date.day}-${date.month}-${date.year}',
        'parent_phone': parentPhone,
        'school_id': schoolId,
        'user_id': userId,
        'note': note,
        'custom_message': customMessage,
      };

      if (kDebugMode) {
        print('🤖 Sending Nobox AI WA Notification for ${student.name} to $parentPhone via fallback...');
      }

      final response = await Supabase.instance.client.functions.invoke(
        'send-nobox-wa-notification',
        body: payload,
      );

      if (kDebugMode) {
        print('Nobox AI WA Response: ${response.status} - ${response.data}');
      }
      return response.status == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending Nobox WA notification: $e');
      }
      return false;
    }
  }

  /// Send formatted daily journal report via Nobox AI WhatsApp Gateway
  static Future<void> sendDailyJournalReport({
    required String teacherName,
    required String schoolName,
    required DateTime date,
    required List<Map<String, String>> journalItems,
    String? schoolId,
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

      // 1. Primary dispatch via official nobox_chat_sdk
      final sentWithSdk = await _sendViaNoboxSdk(
        phone: phone,
        message: reportText,
        schoolId: schoolId,
      );

      if (sentWithSdk) {
        if (kDebugMode) {
          print('✅ Daily report successfully sent via nobox_chat_sdk to $phone');
        }
        return;
      }

      // 2. Resilient fallback via Edge Function
      final payload = {
        'parent_phone': phone,
        'school_id': schoolId,
        'custom_message': reportText,
      };

      if (kDebugMode) {
        print('🤖 Sending Nobox AI WA Daily Report to $phone via fallback...');
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
