import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/services/nobox_wa_service.dart';

void main() {
  group('NoboxWaService Format Absence Message Tests', () {
    test('Formats absence message correctly according to user requirements for Sakit', () {
      final msg = NoboxWaService.formatAbsenceMessage(
        studentName: 'Agung Prasetyo',
        date: DateTime(2026, 9, 30),
        subjectName: 'Matematika',
        statusType: 'S',
      );

      const expected = '📢 *NOTIFIKASI ABSENSI SISWA*\n\n'
          'Yth. Orang Tua/Wali dari *Agung Prasetyo*,\n\n'
          'Menginfokan bahwa pada:\n'
          '📅 Tanggal: 30-9-2026\n'
          '📚 Mata Pelajaran: Matematika\n\n'
          'Pemberitahuan: Anak Anda tidak masuk karena: *Sakit*\n\n'
          'Mohon bantuannya untuk memantau putra/putri Bapak/Ibu.\n'
          'Terima kasih.';

      expect(msg, equals(expected));
    });

    test('Formats absence message correctly for Izin', () {
      final msg = NoboxWaService.formatAbsenceMessage(
        studentName: 'Budi Santoso',
        date: DateTime(2026, 9, 30),
        subjectName: 'Bahasa Indonesia',
        statusType: 'I',
      );

      const expected = '📢 *NOTIFIKASI ABSENSI SISWA*\n\n'
          'Yth. Orang Tua/Wali dari *Budi Santoso*,\n\n'
          'Menginfokan bahwa pada:\n'
          '📅 Tanggal: 30-9-2026\n'
          '📚 Mata Pelajaran: Bahasa Indonesia\n\n'
          'Pemberitahuan: Anak Anda tidak masuk karena: *Izin*\n\n'
          'Mohon bantuannya untuk memantau putra/putri Bapak/Ibu.\n'
          'Terima kasih.';

      expect(msg, equals(expected));
    });

    test('Formats absence message correctly for Alpha', () {
      final msg = NoboxWaService.formatAbsenceMessage(
        studentName: 'Citra Lestari',
        date: DateTime(2026, 9, 30),
        subjectName: 'Bahasa Inggris',
        statusType: 'A',
      );

      const expected = '📢 *NOTIFIKASI ABSENSI SISWA*\n\n'
          'Yth. Orang Tua/Wali dari *Citra Lestari*,\n\n'
          'Menginfokan bahwa pada:\n'
          '📅 Tanggal: 30-9-2026\n'
          '📚 Mata Pelajaran: Bahasa Inggris\n\n'
          'Pemberitahuan: Anak Anda tidak masuk karena: *Alpha*\n\n'
          'Mohon bantuannya untuk memantau putra/putri Bapak/Ibu.\n'
          'Terima kasih.';

      expect(msg, equals(expected));
    });
  });
}
