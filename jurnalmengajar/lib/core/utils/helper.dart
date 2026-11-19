import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/supabase_config.dart';

enum JournalTimeScope { month, week, all }

class AppHelper {
  static String formatDate(DateTime date) {
    try {
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('EEEE, d MMMM yyyy').format(date);
    }
  }

  static String formatDateShort(DateTime date) {
    try {
      return DateFormat('d MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('d MMM yyyy').format(date);
    }
  }

  static String formatTime(String time) {
    return time;
  }

  static const List<String> supportedTimezones = ['WIB', 'WITA', 'WIT'];

  static String getTimezoneLabel(String? timezone) {
    final offset = getTimezoneOffsetHours(timezone);
    if (offset == 8) {
      return 'WITA';
    } else if (offset == 9) {
      return 'WIT';
    } else if (offset == 7) {
      return 'WIB';
    } else {
      final sign = offset >= 0 ? '+' : '';
      return 'UTC$sign$offset';
    }
  }

  static String getTimezoneShortLabel(String? timezone) {
    final offset = getTimezoneOffsetHours(timezone);
    if (offset == 8) {
      return 'WITA';
    } else if (offset == 9) {
      return 'WIT';
    } else if (offset == 7) {
      return 'WIB';
    } else {
      final sign = offset >= 0 ? '+' : '';
      return 'UTC$sign$offset';
    }
  }

  /// Menghitung offset jam zona waktu (fleksibel: mendukung WIB/WITA/WIT, UTC/GMT offsets, nama IANA, dll.)
  static int getTimezoneOffsetHours(String? timezone) {
    if (timezone == null || timezone.trim().isEmpty) return 7;
    final tz = timezone.trim().toUpperCase();

    // 1. Pencocokan langsung kode dan kota utama IANA
    if (tz == 'WIB' || tz.contains('ASIA/JAKARTA') || tz.contains('ASIA/PONTIANAK')) return 7;
    if (tz == 'WITA' || tz.contains('ASIA/MAKASSAR') || tz.contains('ASIA/UJUNG_PANDANG') || tz.contains('ASIA/BALI') || tz.contains('ASIA/MANADO')) return 8;
    if (tz == 'WIT' || tz.contains('ASIA/JAYAPURA')) return 9;

    // 2. Format offset eksplisit (e.g. UTC+7, UTC+08:00, GMT+9, +07:00, +8, -5)
    final match = RegExp(r'(?:UTC|GMT)?\s*([+-])\s*(\d{1,2})(?::(\d{2}))?').firstMatch(tz);
    if (match != null) {
      final sign = match.group(1) == '-' ? -1 : 1;
      final hours = int.tryParse(match.group(2) ?? '') ?? 7;
      return sign * hours;
    }

    // 3. Fallback pencarian kata kunci
    if (tz.contains('WITA') || tz.contains('UTC+8') || tz.contains('GMT+8')) return 8;
    if (tz.contains('WIT') || tz.contains('UTC+9') || tz.contains('GMT+9')) return 9;
    return 7;
  }

  /// Mengonversi format jam 'HH:mm' atau 'HH.mm' dari satu zona waktu ke zona waktu lain
  static String convertTimeString(String timeStr, {required String fromTz, required String toTz}) {
    if (timeStr.isEmpty) return timeStr;
    final normalizedFrom = fromTz.trim();
    final normalizedTo = toTz.trim();
    if (normalizedFrom.toUpperCase() == normalizedTo.toUpperCase()) return timeStr;

    final separator = timeStr.contains(':') ? ':' : (timeStr.contains('.') ? '.' : null);
    if (separator == null) return timeStr;

    final parts = timeStr.split(separator);
    if (parts.length != 2) return timeStr;

    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    if (hour == null || minute == null) return timeStr;

    final diff = getTimezoneOffsetHours(normalizedTo) - getTimezoneOffsetHours(normalizedFrom);
    var newHour = (hour + diff) % 24;
    if (newHour < 0) newHour += 24;

    final hStr = newHour.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr$separator$mStr';
  }

  /// Format rentang jam jadwal dengan memperhitungkan zona waktu pengguna vs zona waktu sekolah
  static String formatScheduleTimeRange({
    required String hrStart,
    required String hrEnd,
    required String schoolTz,
    String? userTz,
  }) {
    if (hrStart.isEmpty) return '';

    final sOffset = getTimezoneOffsetHours(schoolTz);
    final uOffset = (userTz == null || userTz.trim().isEmpty) ? sOffset : getTimezoneOffsetHours(userTz);

    final uShort = (userTz == null || userTz.trim().isEmpty)
        ? getTimezoneShortLabel(schoolTz)
        : getTimezoneShortLabel(userTz);

    // Jika timezone user sama dengan sekolah (atau offset selisih 0)
    if (sOffset == uOffset) {
      if (hrEnd.isNotEmpty) {
        return '$hrStart - $hrEnd $uShort';
      }
      return '$hrStart $uShort';
    }

    // Jika zona waktu tempat tinggal user berbeda dari zona sekolah:
    final convertedStart = convertTimeString(hrStart, fromTz: schoolTz, toTz: userTz!);
    final convertedEnd = hrEnd.isNotEmpty ? convertTimeString(hrEnd, fromTz: schoolTz, toTz: userTz) : '';

    if (convertedEnd.isNotEmpty) {
      return '$convertedStart - $convertedEnd $uShort';
    }
    return '$convertedStart $uShort';
  }

  /// Membersihkan nama provinsi dari format dwibahasa di database (misal: "East Java (Jawa Timur)" -> "Jawa Timur")
  static String cleanProvinceName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final trimmed = raw.trim();
    final parenMatch = RegExp(r'\((.+?)\)').firstMatch(trimmed);
    if (parenMatch != null) {
      final inside = parenMatch.group(1)?.trim() ?? '';
      if (inside.isNotEmpty) return inside;
    }
    if (trimmed == 'Sumatra Utara') return 'Sumatera Utara';
    if (trimmed == 'Sumatra Barat') return 'Sumatera Barat';
    if (trimmed == 'Sumatra Selatan') return 'Sumatera Selatan';
    return trimmed;
  }

  /// Membersihkan nama kota agar konsisten dalam penulisan
  static String cleanCityName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final trimmed = raw.trim();
    if (trimmed == 'Amlapura city') return 'Amlapura';
    if (trimmed == 'City of Balikpapan') return 'Kota Balikpapan';
    if (trimmed == 'Jambi City') return 'Kota Jambi';
    return trimmed;
  }

  /// Otomatis mendeteksi zona waktu (WIB, WITA, WIT) berdasarkan nama kota/kabupaten atau provinsi
  static String detectTimezoneFromCity(String? city, {String? province}) {
    final search = '${province ?? ''} ${city ?? ''}'.toLowerCase();
    if (search.trim().isEmpty) return 'WIB';

    // 1. Cek zona waktu WIT (Papua & Maluku)
    if (search.contains('papua') ||
        search.contains('maluku') ||
        search.contains('jayapura') ||
        search.contains('ambon') ||
        search.contains('ternate') ||
        search.contains('merauke') ||
        search.contains('sorong') ||
        search.contains('manokwari') ||
        search.contains('biak') ||
        search.contains('timika') ||
        search.contains('mimika') ||
        search.contains('nabire') ||
        search.contains('wamena') ||
        search.contains('tidore') ||
        search.contains('tual') ||
        search.contains('seram')) {
      return 'WIT';
    }

    // 2. Cek zona waktu WITA (Bali, NTB, NTT, Sulawesi, Kalsel, Kaltim, Kaltara)
    if (search.contains('bali') ||
        search.contains('denpasar') ||
        search.contains('badung') ||
        search.contains('gianyar') ||
        search.contains('klungkung') ||
        search.contains('tabanan') ||
        search.contains('buleleng') ||
        search.contains('singaraja') ||
        search.contains('karangasem') ||
        search.contains('jembrana') ||
        search.contains('bangli') ||
        search.contains('nusa tenggara') ||
        search.contains('ntb') ||
        search.contains('ntt') ||
        search.contains('lombok') ||
        search.contains('mataram') ||
        search.contains('sumbawa') ||
        search.contains('bima') ||
        search.contains('kupang') ||
        search.contains('flores') ||
        search.contains('sumba') ||
        search.contains('alor') ||
        search.contains('labuan bajo') ||
        search.contains('ende') ||
        search.contains('sulawesi') ||
        search.contains('makassar') ||
        search.contains('gowa') ||
        search.contains('maros') ||
        search.contains('bone') ||
        search.contains('palopo') ||
        search.contains('parepare') ||
        search.contains('manado') ||
        search.contains('bitung') ||
        search.contains('tomohon') ||
        search.contains('minahasa') ||
        search.contains('palu') ||
        search.contains('poso') ||
        search.contains('kendari') ||
        search.contains('baubau') ||
        search.contains('gorontalo') ||
        search.contains('mamuju') ||
        search.contains('kalimantan selatan') ||
        search.contains('kalsel') ||
        search.contains('banjarmasin') ||
        search.contains('banjarbaru') ||
        search.contains('kalimantan timur') ||
        search.contains('kaltim') ||
        search.contains('samarinda') ||
        search.contains('balikpapan') ||
        search.contains('bontang') ||
        search.contains('kutai') ||
        search.contains('berau') ||
        search.contains('kalimantan utara') ||
        search.contains('kaltara') ||
        search.contains('tarakan') ||
        search.contains('nunukan')) {
      return 'WITA';
    }

    // 3. Default ke WIB (Sumatera [termasuk Bungo, Jambi, Medan, Padang], Jawa [termasuk Malang, Surabaya, Jakarta], Kalbar, Kalteng)
    return 'WIB';
  }

  static int getTimezoneOffset(String? timezone) => getTimezoneOffsetHours(timezone);

  static DateTime nowInTimezone(String? timezone) {
    final offset = getTimezoneOffset(timezone);
    return DateTime.now().toUtc().add(Duration(hours: offset));
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
      case 'approved':
        return 'Diterima';
      case 'rejected':
        return 'Ditolak';
      case 'pending':
      default:
        return 'Pending';
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

  /// Normalizes a Supabase storage URL to ensure it points to the active Supabase host.
  /// Handles both old Supabase cloud domain and UBIG domain gracefully, including comma-separated lists.
  static String? normalizeStorageUrl(String? url) {
    if (url == null) return null;
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    // Handle comma-separated multiple URLs (e.g., multiple attachments in journals)
    if (trimmed.contains(',')) {
      return trimmed
          .split(',')
          .map((u) => normalizeStorageUrl(u.trim()))
          .where((u) => u != null && u.isNotEmpty)
          .join(',');
    }

    // Replace known legacy/alternate domains with the active Supabase URL
    final activeUrl = SupabaseConfig.url.replaceAll(RegExp(r'/+$'), '');

    if (trimmed.contains('/storage/v1/object/public/')) {
      final marker = '/storage/v1/object/public/';
      final pathIndex = trimmed.indexOf(marker);
      final storagePath = trimmed.substring(pathIndex + marker.length);
      return '$activeUrl/storage/v1/object/public/$storagePath';
    }

    return trimmed;
  }
}

