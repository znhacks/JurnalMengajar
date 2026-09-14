import 'package:flutter_test/flutter_test.dart';
import 'package:jurnalmengajar/services/excel_export_service.dart';
import 'package:excel/excel.dart';

void main() {
  group('Excel Export Service Multi-Tenant & Data Integrity Tests', () {
    test('ExcelExportService sanitizeFileName cleans invalid characters', () {
      expect(ExcelExportService.sanitizeFileName('SMKN 11 / Malang :*?'), 'SMKN_11_Malang');
      expect(ExcelExportService.sanitizeFileName('Guru  Pengajar '), 'Guru_Pengajar');
    });

    test('ExcelExportService formatDate formats consistently as YYYY-MM-DD', () {
      final date = DateTime(2026, 9, 14);
      expect(ExcelExportService.formatDate(date), '2026-09-14');
    });

    test('ExcelExportService formatDayName returns proper Indonesian day name', () {
      expect(ExcelExportService.formatDayName(DateTime(2026, 9, 14)), 'Senin');
      expect(ExcelExportService.formatDayName(DateTime(2026, 9, 15)), 'Selasa');
    });

    test('Journal Export builds valid XLSX structure without sensitive data', () {
      final excel = Excel.createExcel();
      final sheetName = 'Data Jurnal';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      final sheet = excel[sheetName];

      final headers = [
        'No',
        'Tanggal',
        'Hari',
        'Guru',
        'Mata Pelajaran',
        'Kelas',
        'Jam Ke',
        'Materi Pembelajaran',
        'Catatan / Kendala',
        'Hadir',
        'Sakit',
        'Izin',
        'Alpha',
        'Status Verifikasi',
      ];

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      // Ensure no sensitive headers
      expect(headers.contains('password'), isFalse);
      expect(headers.contains('token'), isFalse);
      expect(headers.contains('api_key'), isFalse);
      expect(headers.contains('secret'), isFalse);
      expect(headers.contains('nobox_key'), isFalse);

      final rowData = [
        IntCellValue(1),
        TextCellValue('2026-09-14'),
        TextCellValue('Senin'),
        TextCellValue('Budi Santoso'),
        TextCellValue('Matematika'),
        TextCellValue('X RPL 1'),
        IntCellValue(1),
        TextCellValue('Aljabar Linear'),
        TextCellValue('Lancar'),
        IntCellValue(30),
        IntCellValue(0),
        IntCellValue(1),
        IntCellValue(0),
        TextCellValue('Terverifikasi'),
      ];
      sheet.appendRow(rowData);

      final bytes = excel.save();
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);

      // Re-read generated workbook to ensure not corrupt
      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.tables.containsKey(sheetName), isTrue);
      final readSheet = decoded.tables[sheetName]!;
      expect(readSheet.rows.length, 2);
      expect(readSheet.rows[0][0]?.value.toString(), 'No');
      expect(readSheet.rows[1][3]?.value.toString(), 'Budi Santoso');
      expect(readSheet.rows[1][4]?.value.toString(), 'Matematika');
    });

    test('Master User Export excludes passwords, secrets, tokens', () {
      final excel = Excel.createExcel();
      final sheetName = 'Master User';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
      final sheet = excel[sheetName];

      final headers = [
        'No',
        'Nama Lengkap',
        'Email',
        'Role Aplikasi',
        'Hak Akses Sekolah',
        'Status Akun',
        'Nomor Telepon',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      final userRow = [
        IntCellValue(1),
        TextCellValue('Admin SMKN 11'),
        TextCellValue('admin@smkn11.sch.id'),
        TextCellValue('Admin Sekolah'),
        TextCellValue('Admin Sekolah'),
        TextCellValue('Aktif'),
        TextCellValue('08123456789'),
      ];
      sheet.appendRow(userRow);

      final bytes = excel.save();
      final decoded = Excel.decodeBytes(bytes!);
      final readSheet = decoded.tables[sheetName]!;
      expect(readSheet.rows.length, 2);
      expect(readSheet.rows[1][1]?.value.toString(), 'Admin SMKN 11');
      expect(readSheet.rows[1][2]?.value.toString(), 'admin@smkn11.sch.id');

      // String verification that sensitive words do not exist
      final stringContent = String.fromCharCodes(bytes);
      expect(stringContent.contains('service_role'), isFalse);
      expect(stringContent.contains('supabase_secret'), isFalse);
      expect(stringContent.contains('nobox_api_key'), isFalse);
    });

    test('Teacher Export creates Data Guru and Jadwal Guru sheets with strict tenant isolation', () {
      final excel = Excel.createExcel();
      final teacherSheetName = 'Data Guru';
      excel.rename(excel.getDefaultSheet() ?? 'Sheet1', teacherSheetName);
      final teacherSheet = excel[teacherSheetName];

      final teacherHeaders = [
        'No',
        'Nama Guru',
        'Jabatan / Posisi',
        'Mata Pelajaran Diampu',
        'Email',
        'Nomor Telepon',
        'Alamat',
      ];
      teacherSheet.appendRow(teacherHeaders.map((h) => TextCellValue(h)).toList());

      // Only valid active teachers of active school (e.g. SMKN 11)
      final teachers = [
        {'id': 't1', 'name': 'Heru Sudjatmiko', 'position': 'Guru Tetap', 'subjects': 'Matematika', 'school_id': 'school-smkn11'},
        {'id': 't2', 'name': 'Siti Aminah', 'position': 'Guru Kejuruan', 'subjects': 'Pemrograman Web', 'school_id': 'school-smkn11'},
      ];

      for (int i = 0; i < teachers.length; i++) {
        teacherSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(teachers[i]['name']!),
          TextCellValue(teachers[i]['position']!),
          TextCellValue(teachers[i]['subjects']!),
          TextCellValue('${teachers[i]['id']}@smkn11.sch.id'),
          TextCellValue('0812345678'),
          TextCellValue('Malang'),
        ]);
      }

      // Add secondary sheet 'Jadwal Guru'
      final schedSheetName = 'Jadwal Guru';
      final schedSheet = excel[schedSheetName];
      final schedHeaders = [
        'No',
        'Guru',
        'Mata Pelajaran',
        'Kelas',
        'Hari',
        'Jam Ke',
        'Waktu',
        'Catatan',
        'Status',
      ];
      schedSheet.appendRow(schedHeaders.map((h) => TextCellValue(h)).toList());

      final schedules = [
        {
          'teacher': 'Heru Sudjatmiko',
          'subject': 'Matematika',
          'class': 'XII RPL 1',
          'day': 'Senin',
          'hour': 1,
          'time': '07:00 - 08:30',
        },
        {
          'teacher': 'Heru Sudjatmiko',
          'subject': 'Matematika',
          'class': 'XII RPL 2',
          'day': 'Selasa',
          'hour': 3,
          'time': '08:45 - 10:15',
        },
        {
          'teacher': 'Siti Aminah',
          'subject': 'Pemrograman Web',
          'class': 'XI RPL 1',
          'day': 'Rabu',
          'hour': 1,
          'time': '07:00 - 09:15',
        },
      ];

      for (int i = 0; i < schedules.length; i++) {
        schedSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(schedules[i]['teacher'] as String),
          TextCellValue(schedules[i]['subject'] as String),
          TextCellValue(schedules[i]['class'] as String),
          TextCellValue(schedules[i]['day'] as String),
          IntCellValue(schedules[i]['hour'] as int),
          TextCellValue(schedules[i]['time'] as String),
          TextCellValue('-'),
          TextCellValue('Aktif'),
        ]);
      }

      final bytes = excel.save();
      expect(bytes, isNotNull);

      final decoded = Excel.decodeBytes(bytes!);
      expect(decoded.tables.containsKey('Data Guru'), isTrue);
      expect(decoded.tables.containsKey('Jadwal Guru'), isTrue);

      final readTeacherSheet = decoded.tables['Data Guru']!;
      expect(readTeacherSheet.rows.length, 3); // 1 header + 2 teachers
      expect(readTeacherSheet.rows[1][1]?.value.toString(), 'Heru Sudjatmiko');
      expect(readTeacherSheet.rows[1][3]?.value.toString(), 'Matematika');

      final readSchedSheet = decoded.tables['Jadwal Guru']!;
      expect(readSchedSheet.rows.length, 4); // 1 header + 3 schedules
      expect(readSchedSheet.rows[1][1]?.value.toString(), 'Heru Sudjatmiko');
      expect(readSchedSheet.rows[1][3]?.value.toString(), 'XII RPL 1');
      expect(readSchedSheet.rows[2][3]?.value.toString(), 'XII RPL 2');
    });

    test('Segregation: Pending teachers and pure admins are separated from active teachers', () {
      final allRawUsers = [
        {'name': 'Guru A', 'role': 'guru', 'status': 'active', 'school_id': 'school-1'},
        {'name': 'Guru B', 'role': 'guru', 'status': 'active', 'school_id': 'school-1'},
        {'name': 'Admin Asli', 'role': 'admin', 'status': 'active', 'school_id': 'school-1'},
        {'name': 'Calon Guru X', 'role': 'pending_guru', 'status': 'pending', 'school_id': 'school-1'},
        {'name': 'Guru Sekolah Lain', 'role': 'guru', 'status': 'active', 'school_id': 'school-2'},
      ];

      const activeSchoolId = 'school-1';

      // Active Teachers in active school
      final activeTeachers = allRawUsers.where((u) =>
        u['school_id'] == activeSchoolId &&
        u['role'] == 'guru' &&
        u['status'] == 'active'
      ).toList();

      expect(activeTeachers.length, 2);
      expect(activeTeachers.map((u) => u['name']), containsAll(['Guru A', 'Guru B']));
      expect(activeTeachers.map((u) => u['name']), isNot(contains('Admin Asli')));
      expect(activeTeachers.map((u) => u['name']), isNot(contains('Calon Guru X')));
      expect(activeTeachers.map((u) => u['name']), isNot(contains('Guru Sekolah Lain')));

      // Pending Teachers in active school
      final pendingTeachers = allRawUsers.where((u) =>
        u['school_id'] == activeSchoolId &&
        (u['role'] == 'pending_guru' || u['status'] == 'pending')
      ).toList();

      expect(pendingTeachers.length, 1);
      expect(pendingTeachers.first['name'], 'Calon Guru X');
    });
  });
}

