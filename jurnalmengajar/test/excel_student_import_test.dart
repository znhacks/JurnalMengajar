import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:jurnalmengajar/models/student_model.dart';
import 'package:jurnalmengajar/services/excel_import_service.dart';

void main() {
  group('ExcelImportService Tests', () {
    test('downloadStudentTemplate generates valid Excel workbook with sample data', () async {
      // Test the logic that builds the Excel template
      final excel = Excel.createExcel();
      const sheetName = 'Format Impor Siswa';
      final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
      excel.rename(defaultSheet, sheetName);
      final sheet = excel[sheetName];

      final headers = [
        'No',
        'Nama Siswa',
        'NIS',
        'Jenis Kelamin',
        'Nomor HP Orang Tua',
        'Kelas',
      ];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      sheet.appendRow([
        IntCellValue(1),
        TextCellValue('Ahmad Fauzi'),
        TextCellValue('1001'),
        TextCellValue('Laki-laki'),
        TextCellValue('081234567890'),
        TextCellValue('X-A'),
      ]);

      final bytes = excel.save();
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);

      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.tables.containsKey(sheetName), isTrue);
      final rows = decoded.tables[sheetName]!.rows;
      expect(rows.length, 2);
      expect(rows[0][1]?.value?.toString(), 'Nama Siswa');
      expect(rows[1][1]?.value?.toString(), 'Ahmad Fauzi');
    });

    test('parseExcelBytes parses student rows, normalizes gender, and cleans numbers', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Row 0: Headers
      sheet.appendRow([
        TextCellValue('No'),
        TextCellValue('Nama Siswa'),
        TextCellValue('NIS'),
        TextCellValue('Jenis Kelamin'),
        TextCellValue('Nomor HP Orang Tua'),
        TextCellValue('Kelas'),
      ]);

      // Row 1: Male student with integer NIS and phone
      sheet.appendRow([
        IntCellValue(1),
        TextCellValue('Budi Santoso'),
        IntCellValue(101),
        TextCellValue('Laki-laki'),
        TextCellValue('08123456789'),
        TextCellValue('X-A'),
      ]);

      // Row 2: Female student with double NIS (.0)
      sheet.appendRow([
        IntCellValue(2),
        TextCellValue('Siti Aminah'),
        DoubleCellValue(102.0),
        TextCellValue('Perempuan'),
        TextCellValue('08987654321'),
        TextCellValue('X-A'),
      ]);

      // Row 3: Male with 'Pria'
      sheet.appendRow([
        IntCellValue(3),
        TextCellValue('Dedi Kurniawan'),
        TextCellValue('103'),
        TextCellValue('Pria'),
        TextCellValue('-'),
        TextCellValue('X-A'),
      ]);

      // Row 4: Empty name (should be flagged as invalid)
      sheet.appendRow([
        IntCellValue(4),
        TextCellValue(''),
        TextCellValue('104'),
        TextCellValue('L'),
        TextCellValue('08111'),
        TextCellValue('X-A'),
      ]);

      final bytes = excel.save()!;
      final result = ExcelImportService.parseExcelBytes(bytes, fileName: 'test.xlsx');

      expect(result.fileName, 'test.xlsx');
      expect(result.items.length, 4);

      // Student 1
      expect(result.items[0].name, 'Budi Santoso');
      expect(result.items[0].nis, '101');
      expect(result.items[0].gender, 'L');
      expect(result.items[0].parentPhoneNumber, '08123456789');
      expect(result.items[0].isValid, isTrue);

      // Student 2 (cleaned double .0)
      expect(result.items[1].name, 'Siti Aminah');
      expect(result.items[1].nis, '102');
      expect(result.items[1].gender, 'P');
      expect(result.items[1].isValid, isTrue);

      // Student 3 (Pria -> L, '-' phone -> null)
      expect(result.items[2].name, 'Dedi Kurniawan');
      expect(result.items[2].gender, 'L');
      expect(result.items[2].parentPhoneNumber, isNull);
      expect(result.items[2].isValid, isTrue);

      // Student 4 (empty name -> invalid)
      expect(result.items[3].isValid, isFalse);
      expect(result.items[3].error, isNotNull);
    });

    test('parseExcelBytes detects duplicates against existing students', () {
      final existingStudents = [
        StudentModel(
          id: 's-1',
          classId: 'c-1',
          name: 'Andi Pratama',
          nis: '1001',
          gender: 'L',
        ),
      ];

      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      sheet.appendRow([
        TextCellValue('Nama Siswa'),
        TextCellValue('NIS'),
        TextCellValue('JK'),
      ]);

      // Duplicate NIS
      sheet.appendRow([
        TextCellValue('Andi Pratama Re-entry'),
        TextCellValue('1001'),
        TextCellValue('L'),
      ]);

      // Duplicate Name
      sheet.appendRow([
        TextCellValue('Andi Pratama'),
        TextCellValue('9999'),
        TextCellValue('L'),
      ]);

      // Non-duplicate student
      sheet.appendRow([
        TextCellValue('Citra Lestari'),
        TextCellValue('1002'),
        TextCellValue('P'),
      ]);

      final bytes = excel.save()!;
      final result = ExcelImportService.parseExcelBytes(
        bytes,
        existingStudents: existingStudents,
      );

      expect(result.items.length, 3);

      // Item 0: duplicate by NIS
      expect(result.items[0].isDuplicate, isTrue);
      expect(result.items[0].isSelected, isFalse);

      // Item 1: duplicate by Name
      expect(result.items[1].isDuplicate, isTrue);
      expect(result.items[1].isSelected, isFalse);

      // Item 2: new student
      expect(result.items[2].isDuplicate, isFalse);
      expect(result.items[2].isSelected, isTrue);
    });

    test('toStudentModel converts StudentImportItem to StudentModel accurately', () {
      final item = StudentImportItem(
        name: ' Rina Marlina ',
        nis: ' 2005 ',
        gender: 'P',
        parentPhoneNumber: ' 0812998877 ',
      );

      final model = item.toStudentModel(classId: 'class-abc', schoolId: 'school-xyz');
      expect(model.name, 'Rina Marlina');
      expect(model.nis, '2005');
      expect(model.gender, 'P');
      expect(model.parentPhoneNumber, '0812998877');
      expect(model.classId, 'class-abc');
      expect(model.schoolId, 'school-xyz');
    });
  });
}
