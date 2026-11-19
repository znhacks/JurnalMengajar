import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/core/utils/helper.dart';
import 'package:jurnalmengajar/core/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fleksibilitas Zona Waktu & Helper', () {
    test('Pencocokan nama kota ke zona waktu (keadaan riil Indonesia)', () {
      // WIB
      expect(AppHelper.detectTimezoneFromCity('Malang', province: 'Jawa Timur'), 'WIB');
      expect(AppHelper.detectTimezoneFromCity('Bungo', province: 'Jambi'), 'WIB');
      expect(AppHelper.detectTimezoneFromCity('Kota Bandung', province: 'Jawa Barat'), 'WIB');
      expect(AppHelper.detectTimezoneFromCity('Pontianak', province: 'Kalimantan Barat'), 'WIB');
      expect(AppHelper.detectTimezoneFromCity('Palangkaraya', province: 'Kalimantan Tengah'), 'WIB');

      // WITA
      expect(AppHelper.detectTimezoneFromCity('Denpasar', province: 'Bali'), 'WITA');
      expect(AppHelper.detectTimezoneFromCity('Makassar', province: 'Sulawesi Selatan'), 'WITA');
      expect(AppHelper.detectTimezoneFromCity('Balikpapan', province: 'Kalimantan Timur'), 'WITA');
      expect(AppHelper.detectTimezoneFromCity('Banjarmasin', province: 'Kalimantan Selatan'), 'WITA');
      expect(AppHelper.detectTimezoneFromCity('Mataram', province: 'Nusa Tenggara Barat'), 'WITA');
      expect(AppHelper.detectTimezoneFromCity('Kupang', province: 'Nusa Tenggara Timur'), 'WITA');

      // WIT
      expect(AppHelper.detectTimezoneFromCity('Jayapura', province: 'Papua'), 'WIT');
      expect(AppHelper.detectTimezoneFromCity('Ambon', province: 'Maluku'), 'WIT');
      expect(AppHelper.detectTimezoneFromCity('Sorong', province: 'Papua Barat Daya'), 'WIT');
      expect(AppHelper.detectTimezoneFromCity('Merauke', province: 'Papua Selatan'), 'WIT');
    });

    test('Fleksibilitas perhitungan offset jam non-hardcoded', () {
      // Standar Indonesia
      expect(AppHelper.getTimezoneOffsetHours('WIB'), 7);
      expect(AppHelper.getTimezoneOffsetHours('WITA'), 8);
      expect(AppHelper.getTimezoneOffsetHours('WIT'), 9);

      // Format IANA
      expect(AppHelper.getTimezoneOffsetHours('Asia/Jakarta'), 7);
      expect(AppHelper.getTimezoneOffsetHours('Asia/Pontianak'), 7);
      expect(AppHelper.getTimezoneOffsetHours('Asia/Makassar'), 8);
      expect(AppHelper.getTimezoneOffsetHours('Asia/Jayapura'), 9);

      // Format UTC / GMT
      expect(AppHelper.getTimezoneOffsetHours('UTC+7'), 7);
      expect(AppHelper.getTimezoneOffsetHours('UTC+08:00'), 8);
      expect(AppHelper.getTimezoneOffsetHours('GMT+9'), 9);
      expect(AppHelper.getTimezoneOffsetHours('+07:00'), 7);
    });

    test('Konversi format jam dengan pemisah titik maupun titik dua', () {
      // 07:00 WIB ke WITA (+1 jam) -> 08:00
      expect(AppHelper.convertTimeString('07:00', fromTz: 'WIB', toTz: 'WITA'), '08:00');

      // 07.00 WIB ke WIT (+2 jam) -> 09.00 (mempertahankan pemisah titik)
      expect(AppHelper.convertTimeString('07.00', fromTz: 'WIB', toTz: 'WIT'), '09.00');

      // 08:30 WITA ke WIB (-1 jam) -> 07:30
      expect(AppHelper.convertTimeString('08:30', fromTz: 'WITA', toTz: 'WIB'), '07:30');

      // Melintasi tengah malam: 23:30 WIB ke WITA (+1) -> 00:30
      expect(AppHelper.convertTimeString('23:30', fromTz: 'WIB', toTz: 'WITA'), '00:30');
    });

    test('Format rentang jam jadwal sekolah vs domisili guru', () {
      // Jika domisili guru sama dengan zona sekolah
      final sameTz = AppHelper.formatScheduleTimeRange(
        hrStart: '07:00',
        hrEnd: '08:30',
        schoolTz: 'WIB',
        userTz: 'WIB',
      );
      expect(sameTz, '07:00 - 08:30 WIB');

      // Jika sekolah di WITA (Denpasar) tapi guru tinggal di WIB (Malang)
      final diffTz = AppHelper.formatScheduleTimeRange(
        hrStart: '08:00',
        hrEnd: '09:30',
        schoolTz: 'WITA',
        userTz: 'WIB',
      );
      expect(diffTz, '07:00 - 08:30 WIB');
    });
  });

  group('Keadaan Riil Dataset Kota & Offline Support', () {
    test('Dataset indonesia_cities.json terisi lengkap dan valid JSON', () {
      final file = File('assets/indonesia_cities.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final list = jsonDecode(content) as List<dynamic>;

      // Harus mencakup ratusan kota/kabupaten di seluruh 38 provinsi
      expect(list.length, greaterThan(800));

      final cities = list.cast<Map<String, dynamic>>();
      final malang = cities.where((c) => (c['city'] as String).contains('Malang')).toList();
      expect(malang.isNotEmpty, isTrue);

      final bungo = cities.where((c) => (c['city'] as String).contains('Bungo')).toList();
      expect(bungo.isNotEmpty, isTrue);

      final jayapura = cities.where((c) => (c['city'] as String).contains('Jayapura')).toList();
      expect(jayapura.isNotEmpty, isTrue);
    });

    test('Penyedia Layanan Konektivitas (ConnectivityService)', () {
      final service = ConnectivityService.instance;
      expect(service.isOnline, isTrue);

      var notified = false;
      void listener() => notified = true;
      service.addListener(listener);

      // Simulasi sinyal offline
      service.reportOffline();
      expect(service.isOffline, isTrue);
      expect(notified, isTrue);

      // Simulasi pemulihan online
      notified = false;
      service.reportOnline();
      expect(service.isOnline, isTrue);
      expect(notified, isTrue);

      service.removeListener(listener);
    });
  });
}
