import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';
import '../models/student_model.dart';
import '../models/class_model.dart';
import 'excel_export_service.dart';
import 'excel_saver.dart';
import 'excel_picker.dart';

class ClassImportItem {
  final String name;
  final String? description;
  final String? error;
  final bool isDuplicate;
  final String? duplicateReason;
  bool isSelected;

  ClassImportItem({
    required this.name,
    this.description,
    this.error,
    this.isDuplicate = false,
    this.duplicateReason,
    this.isSelected = true,
  });

  bool get isValid => error == null && name.trim().isNotEmpty;

  ClassModel toClassModel({
    required String periodId,
    String? schoolId,
  }) {
    return ClassModel(
      id: '',
      periodId: periodId,
      name: name.trim(),
      studentCount: 0,
      schoolId: schoolId,
    );
  }

  ClassImportItem copyWith({
    String? name,
    String? description,
    String? error,
    bool? isDuplicate,
    String? duplicateReason,
    bool? isSelected,
  }) {
    return ClassImportItem(
      name: name ?? this.name,
      description: description ?? this.description,
      error: error ?? this.error,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateReason: duplicateReason ?? this.duplicateReason,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class ClassImportParseResult {
  final String fileName;
  final int totalRows;
  final List<ClassImportItem> items;
  final List<String> warnings;

  ClassImportParseResult({
    required this.fileName,
    required this.totalRows,
    required this.items,
    this.warnings = const [],
  });

  bool get hasValidItems => items.any((i) => i.isValid);
  int get validCount => items.where((i) => i.isValid).length;
  int get duplicateCount => items.where((i) => i.isDuplicate).length;
  int get errorCount => items.where((i) => !i.isValid).length;
  int get selectedCount => items.where((i) => i.isSelected && i.isValid).length;
}

class StudentImportItem {
  final String name;
  final String? nis;
  final String? gender; // 'L' (Laki-laki) or 'P' (Perempuan)
  final String? parentPhoneNumber;
  final String? className;
  final String? error;
  final bool isDuplicate;
  final String? duplicateReason;
  bool isSelected;

  StudentImportItem({
    required this.name,
    this.nis,
    this.gender = 'L',
    this.parentPhoneNumber,
    this.className,
    this.error,
    this.isDuplicate = false,
    this.duplicateReason,
    this.isSelected = true,
  });

  bool get isValid => error == null && name.trim().isNotEmpty;

  StudentModel toStudentModel({
    required String classId,
    String? schoolId,
  }) {
    return StudentModel(
      id: '',
      classId: classId,
      name: name.trim(),
      nis: (nis != null && nis!.trim().isNotEmpty) ? nis!.trim() : null,
      gender: gender ?? 'L',
      parentPhoneNumber: (parentPhoneNumber != null && parentPhoneNumber!.trim().isNotEmpty)
          ? parentPhoneNumber!.trim()
          : null,
      schoolId: schoolId,
    );
  }

  StudentImportItem copyWith({
    String? name,
    String? nis,
    String? gender,
    String? parentPhoneNumber,
    String? className,
    String? error,
    bool? isDuplicate,
    String? duplicateReason,
    bool? isSelected,
  }) {
    return StudentImportItem(
      name: name ?? this.name,
      nis: nis ?? this.nis,
      gender: gender ?? this.gender,
      parentPhoneNumber: parentPhoneNumber ?? this.parentPhoneNumber,
      className: className ?? this.className,
      error: error ?? this.error,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      duplicateReason: duplicateReason ?? this.duplicateReason,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class StudentImportParseResult {
  final String fileName;
  final int totalRows;
  final List<StudentImportItem> items;
  final List<String> warnings;

  StudentImportParseResult({
    required this.fileName,
    required this.totalRows,
    required this.items,
    this.warnings = const [],
  });

  bool get hasValidItems => items.any((i) => i.isValid);
  int get validCount => items.where((i) => i.isValid).length;
  int get duplicateCount => items.where((i) => i.isDuplicate).length;
  int get errorCount => items.where((i) => !i.isValid).length;
  int get selectedCount => items.where((i) => i.isSelected && i.isValid).length;
}

class ExcelImportService {
  /// Unduh template format Excel untuk impor kelas (Langkah 1)
  static Future<void> downloadClassTemplate({
    String schoolName = 'Sekolah',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    const sheetName = 'Format Impor Kelas';
    excel.rename(defaultSheet, sheetName);
    final sheet = excel[sheetName];

    final headers = [
      'No',
      'Nama Kelas',
      'Keterangan / Jurusan (Opsional)',
    ];

    // Mengatur lebar kolom agar lega dan teks tidak terpotong
    sheet.setColumnWidth(0, 10.0);
    sheet.setColumnWidth(1, 30.0);
    sheet.setColumnWidth(2, 38.0);

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle =
          ExcelExportService.headerStyle();
    }

    final hStyle = ExcelExportService.bodyStyle();
    final centerStyle = ExcelExportService.bodyStyle(align: HorizontalAlign.Center);

    final sampleRows = [
      [IntCellValue(1), TextCellValue('X RPL 1'), TextCellValue('Rekayasa Perangkat Lunak')],
      [IntCellValue(2), TextCellValue('X RPL 2'), TextCellValue('Rekayasa Perangkat Lunak')],
      [IntCellValue(3), TextCellValue('XI TKJ 1'), TextCellValue('Teknik Komputer dan Jaringan')],
      [IntCellValue(4), TextCellValue('XI TKJ 2'), TextCellValue('Teknik Komputer dan Jaringan')],
      [IntCellValue(5), TextCellValue('XII DKV 1'), TextCellValue('Desain Komunikasi Visual')],
    ];

    for (int i = 0; i < sampleRows.length; i++) {
      sheet.appendRow(sampleRows[i]);
      final rowIndex = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = hStyle;
    }

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, 'Template_Impor_Kelas.xlsx');
    }
  }

  /// Memilih file Excel dari penyimpanan dan mem-parsing hasil kelas
  static Future<ClassImportParseResult?> pickAndParseClassExcel({
    List<ClassModel>? existingClasses,
  }) async {
    final picked = await pickExcelFilePlatform();
    if (picked == null) {
      return null;
    }

    if (picked.bytes.isEmpty) {
      throw Exception('File Excel kosong atau tidak dapat dibaca.');
    }

    return parseClassExcelBytes(
      picked.bytes,
      fileName: picked.name,
      existingClasses: existingClasses,
    );
  }

  /// Mem-parsing bytes Excel menjadi data kelas siap impor
  static ClassImportParseResult parseClassExcelBytes(
    List<int> bytes, {
    String fileName = 'File Excel',
    List<ClassModel>? existingClasses,
  }) {
    final uint8Bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final excel = Excel.decodeBytes(uint8Bytes);

    if (excel.tables.isEmpty) {
      throw Exception('File Excel tidak memiliki sheet yang dapat dibaca.');
    }

    Sheet? targetSheet;
    for (final table in excel.tables.values) {
      if (table.rows.isNotEmpty) {
        targetSheet = table;
        break;
      }
    }

    if (targetSheet == null || targetSheet.rows.isEmpty) {
      throw Exception('Lembar kerja Excel kosong.');
    }

    final rows = targetSheet.rows;
    final List<String> warnings = [];

    // Deteksi baris header
    int headerRowIndex = 0;
    int nameCol = -1;
    int descCol = -1;

    for (int r = 0; r < rows.length && r < 5; r++) {
      final row = rows[r];
      for (int c = 0; c < row.length; c++) {
        final val = row[c]?.value?.toString().trim().toLowerCase() ?? '';
        if (nameCol == -1 && (val.contains('nama kelas') || val == 'kelas' || val == 'nama')) {
          nameCol = c;
          headerRowIndex = r;
        } else if (descCol == -1 && (val.contains('jurusan') || val.contains('keterangan') || val.contains('peminatan') || val.contains('tingkat'))) {
          descCol = c;
        }
      }
      if (nameCol != -1) break;
    }

    // Fallback jika tidak ada header
    if (nameCol == -1) {
      nameCol = rows[0].length > 1 ? 1 : 0;
      headerRowIndex = -1;
      warnings.add('Header tidak terdeteksi otomatis, menggunakan kolom ke-${nameCol + 1} sebagai nama kelas.');
    }

    final existingNames = (existingClasses ?? [])
        .map((c) => c.name.trim().toLowerCase())
        .toSet();

    final List<ClassImportItem> items = [];
    final seenInFile = <String>{};

    final startRow = headerRowIndex + 1;
    for (int r = startRow; r < rows.length; r++) {
      final row = rows[r];
      if (row.isEmpty) continue;

      String rawName = '';
      if (nameCol < row.length && row[nameCol]?.value != null) {
        rawName = row[nameCol]!.value.toString().trim();
      }

      String? rawDesc;
      if (descCol != -1 && descCol < row.length && row[descCol]?.value != null) {
        rawDesc = row[descCol]!.value.toString().trim();
        if (rawDesc.isEmpty) rawDesc = null;
      }

      // Lewati baris kosong
      if (rawName.isEmpty && (rawDesc == null || rawDesc.isEmpty)) {
        continue;
      }

      String? error;
      if (rawName.isEmpty) {
        error = 'Nama kelas tidak boleh kosong';
      }

      final normalizedName = rawName.toLowerCase();
      bool isDuplicate = false;
      String? duplicateReason;

      if (existingNames.contains(normalizedName)) {
        isDuplicate = true;
        duplicateReason = 'Sudah terdaftar di sistem';
      } else if (seenInFile.contains(normalizedName)) {
        isDuplicate = true;
        duplicateReason = 'Duplikat dalam file Excel ini';
      }

      if (rawName.isNotEmpty) {
        seenInFile.add(normalizedName);
      }

      items.add(
        ClassImportItem(
          name: rawName,
          description: rawDesc,
          error: error,
          isDuplicate: isDuplicate,
          duplicateReason: duplicateReason,
          isSelected: error == null && !isDuplicate,
        ),
      );
    }

    if (items.isEmpty) {
      throw Exception('Tidak ditemukan data baris kelas pada file Excel.');
    }

    return ClassImportParseResult(
      fileName: fileName,
      totalRows: items.length,
      items: items,
      warnings: warnings,
    );
  }

  /// Unduh atau bagikan template format Excel untuk impor siswa (Langkah 2)
  static Future<void> downloadStudentTemplate({
    String className = 'Kelas Contoh',
    String schoolName = 'Sekolah',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    const sheetName = 'Format Impor Siswa';
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

    // Mengatur lebar kolom agar rapi, berjarak lega, dan teks tidak bertumpuk
    sheet.setColumnWidth(0, 8.0);
    sheet.setColumnWidth(1, 32.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 18.0);
    sheet.setColumnWidth(4, 24.0);
    sheet.setColumnWidth(5, 22.0);

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle =
          ExcelExportService.headerStyle();
    }

    final hStyle = ExcelExportService.bodyStyle();
    final centerStyle = ExcelExportService.bodyStyle(align: HorizontalAlign.Center);

    final sampleRows = [
      [IntCellValue(1), TextCellValue('Ahmad Fauzi'), TextCellValue('1001'), TextCellValue('Laki-laki'), TextCellValue('081234567890'), TextCellValue(className)],
      [IntCellValue(2), TextCellValue('Siti Rahmah'), TextCellValue('1002'), TextCellValue('Perempuan'), TextCellValue('081298765432'), TextCellValue(className)],
      [IntCellValue(3), TextCellValue('Budi Santoso'), TextCellValue('1003'), TextCellValue('Laki-laki'), TextCellValue('081311223344'), TextCellValue(className)],
      [IntCellValue(4), TextCellValue('Dewi Lestari'), TextCellValue('1004'), TextCellValue('Perempuan'), TextCellValue('081555667788'), TextCellValue(className)],
    ];

    for (int i = 0; i < sampleRows.length; i++) {
      sheet.appendRow(sampleRows[i]);
      final rowIndex = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = centerStyle;
    }

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, 'Template_Impor_Siswa.xlsx');
    }
  }

  /// Memilih file Excel dari penyimpanan dan mem-parsing hasilnya
  static Future<StudentImportParseResult?> pickAndParseExcel({
    List<StudentModel>? existingStudents,
  }) async {
    final picked = await pickExcelFilePlatform();
    if (picked == null) {
      return null;
    }

    if (picked.bytes.isEmpty) {
      throw Exception('File Excel kosong atau tidak dapat dibaca.');
    }

    return parseExcelBytes(
      picked.bytes,
      fileName: picked.name,
      existingStudents: existingStudents,
    );
  }

  /// Mem-parsing bytes Excel menjadi data siswa siap impor
  static StudentImportParseResult parseExcelBytes(
    List<int> bytes, {
    String fileName = 'File Excel',
    List<StudentModel>? existingStudents,
  }) {
    final uint8Bytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final excel = Excel.decodeBytes(uint8Bytes);

    if (excel.tables.isEmpty) {
      throw Exception('File Excel tidak memiliki sheet yang dapat dibaca.');
    }

    // Ambil sheet pertama yang memiliki baris data
    Sheet? targetSheet;
    for (final table in excel.tables.values) {
      if (table.rows.isNotEmpty) {
        targetSheet = table;
        break;
      }
    }

    if (targetSheet == null || targetSheet.rows.isEmpty) {
      throw Exception('Lembar kerja Excel kosong.');
    }

    final rows = targetSheet.rows;
    final List<String> warnings = [];

    // 1. Deteksi baris header secara cerdas
    int headerRowIndex = 0;
    int nameCol = -1;
    int nisCol = -1;
    int genderCol = -1;
    int phoneCol = -1;
    int classCol = -1;

    for (int r = 0; r < rows.length && r < 10; r++) {
      final row = rows[r];
      int matchCount = 0;

      for (int c = 0; c < row.length; c++) {
        final val = _cellToString(row[c]).toLowerCase();
        if (_isNameHeader(val)) matchCount++;
        if (_isNisHeader(val)) matchCount++;
        if (_isGenderHeader(val)) matchCount++;
        if (_isPhoneHeader(val)) matchCount++;
        if (_isClassHeader(val)) matchCount++;
      }

      if (matchCount >= 2) {
        headerRowIndex = r;
        break;
      }
    }

    // 2. Petakan kolom dari baris header terpilih
    final headerRow = rows[headerRowIndex];
    for (int c = 0; c < headerRow.length; c++) {
      final val = _cellToString(headerRow[c]).toLowerCase();
      if (nameCol == -1 && _isNameHeader(val)) {
        nameCol = c;
      } else if (nisCol == -1 && _isNisHeader(val)) {
        nisCol = c;
      } else if (genderCol == -1 && _isGenderHeader(val)) {
        genderCol = c;
      } else if (phoneCol == -1 && _isPhoneHeader(val)) {
        phoneCol = c;
      } else if (classCol == -1 && _isClassHeader(val)) {
        classCol = c;
      }
    }

    // 3. Fallback jika kolom tertentu tidak teridentifikasi berdasarkan nama header
    if (nameCol == -1) {
      // Default: jika kolom 0 berisi angka urut (No), maka nama di kolom 1, jika tidak di kolom 0
      final firstRowData = rows.length > headerRowIndex + 1 ? rows[headerRowIndex + 1] : null;
      if (firstRowData != null && firstRowData.isNotEmpty) {
        final val0 = _cellToString(firstRowData[0]);
        if (int.tryParse(val0) != null && firstRowData.length > 1) {
          nameCol = 1;
          nisCol = firstRowData.length > 2 ? 2 : -1;
          genderCol = firstRowData.length > 3 ? 3 : -1;
          phoneCol = firstRowData.length > 4 ? 4 : -1;
          classCol = firstRowData.length > 5 ? 5 : -1;
        } else {
          nameCol = 0;
          nisCol = firstRowData.length > 1 ? 1 : -1;
          genderCol = firstRowData.length > 2 ? 2 : -1;
          phoneCol = firstRowData.length > 3 ? 3 : -1;
          classCol = firstRowData.length > 4 ? 4 : -1;
        }
      } else {
        nameCol = 1;
      }
      warnings.add('Kolom dicocokkan otomatis berdasarkan posisi urutan default.');
    }

    final List<StudentImportItem> parsedItems = [];
    final existingNisSet = <String>{};
    final existingNameSet = <String>{};

    if (existingStudents != null) {
      for (final s in existingStudents) {
        if (s.nis != null && s.nis!.trim().isNotEmpty) {
          existingNisSet.add(s.nis!.trim().toLowerCase());
        }
        if (s.name.trim().isNotEmpty) {
          existingNameSet.add(s.name.trim().toLowerCase());
        }
      }
    }

    final Set<String> batchNisSet = {};

    // 4. Baca setiap baris data
    for (int r = headerRowIndex + 1; r < rows.length; r++) {
      final row = rows[r];

      // Periksa apakah baris benar-benar kosong
      bool allEmpty = true;
      for (final cell in row) {
        if (_cellToString(cell).isNotEmpty) {
          allEmpty = false;
          break;
        }
      }
      if (allEmpty) continue;

      final rawName = _getCellValue(row, nameCol);
      final rawNis = _getCellValue(row, nisCol);
      final rawGender = _getCellValue(row, genderCol);
      final rawPhone = _getCellValue(row, phoneCol);
      final rawClass = _getCellValue(row, classCol);

      // Validasi nama
      if (rawName.isEmpty) {
        parsedItems.add(StudentImportItem(
          name: '(Baris ${r + 1} - Nama Kosong)',
          error: 'Nama siswa pada baris ${r + 1} tidak boleh kosong',
          isSelected: false,
        ));
        continue;
      }

      // Normalisasi Jenis Kelamin
      final normalizedGender = _normalizeGender(rawGender);

      // Normalisasi NIS & Telepon
      final cleanNis = _cleanNumberString(rawNis);
      final cleanPhone = _cleanNumberString(rawPhone);

      // Pengecekan Duplikat
      bool isDup = false;
      String? dupReason;

      final lowerName = rawName.toLowerCase();
      final lowerNis = cleanNis?.toLowerCase();

      if (lowerNis != null && lowerNis.isNotEmpty) {
        if (existingNisSet.contains(lowerNis)) {
          isDup = true;
          dupReason = 'NIS $cleanNis sudah terdaftar di kelas';
        } else if (batchNisSet.contains(lowerNis)) {
          isDup = true;
          dupReason = 'NIS $cleanNis duplikat di dalam file';
        } else {
          batchNisSet.add(lowerNis);
        }
      }

      if (!isDup && existingNameSet.contains(lowerName)) {
        isDup = true;
        dupReason = 'Nama "$rawName" sudah ada di kelas ini';
      }

      parsedItems.add(StudentImportItem(
        name: rawName,
        nis: cleanNis,
        gender: normalizedGender,
        parentPhoneNumber: cleanPhone,
        className: rawClass.isNotEmpty ? rawClass : null,
        isDuplicate: isDup,
        duplicateReason: dupReason,
        isSelected: !isDup, // Default: jangan centang yang duplikat
      ));
    }

    return StudentImportParseResult(
      fileName: fileName,
      totalRows: parsedItems.length,
      items: parsedItems,
      warnings: warnings,
    );
  }

  static String _cellToString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    if (val is TextCellValue) {
      return val.value.toString().trim();
    }
    if (val is IntCellValue) {
      return val.value.toString().trim();
    }
    if (val is DoubleCellValue) {
      final d = val.value;
      if (d == d.roundToDouble()) {
        return d.toInt().toString();
      }
      return d.toString();
    }
    final str = val.toString().trim();
    if (str == '-' || str == 'null' || str == 'N/A' || str == 'n/a') {
      return '';
    }
    return str;
  }

  static String _getCellValue(List<Data?> row, int colIndex) {
    if (colIndex < 0 || colIndex >= row.length) return '';
    final str = _cellToString(row[colIndex]);
    if (str == '-' || str == 'null' || str == 'N/A' || str == 'n/a') {
      return '';
    }
    return str;
  }

  static String? _cleanNumberString(String val) {
    var s = val.trim();
    if (s.isEmpty || s == '-' || s == 'null') return null;
    // Hapus trailing .0 jika dihasilkan dari format angka Excel
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2);
    }
    return s.isNotEmpty ? s : null;
  }

  static String _normalizeGender(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.startsWith('l') || s == 'pria' || s == 'laki-laki' || s == 'male' || s == 'laki') {
      return 'L';
    }
    if (s.startsWith('p') || s == 'wanita' || s == 'perempuan' || s == 'female') {
      return 'P';
    }
    return 'L'; // Default Laki-laki
  }

  static bool _isNameHeader(String val) {
    final v = val.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return v.contains('namasiswa') ||
        v.contains('namalengkap') ||
        v == 'nama' ||
        v.contains('studentname') ||
        v == 'siswa';
  }

  static bool _isNisHeader(String val) {
    final v = val.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return v == 'nis' ||
        v == 'nisn' ||
        v.contains('nomorinduk') ||
        v.contains('noinduk') ||
        v == 'noid';
  }

  static bool _isGenderHeader(String val) {
    final v = val.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return v.contains('jeniskelamin') ||
        v == 'jk' ||
        v == 'gender' ||
        v == 'lp' ||
        v == 'sex';
  }

  static bool _isPhoneHeader(String val) {
    final v = val.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return v.contains('nomorhp') ||
        v.contains('nohp') ||
        v.contains('telepon') ||
        v.contains('nohportu') ||
        v.contains('hp') ||
        v.contains('phone') ||
        v.contains('kontak') ||
        v.contains('wa');
  }

  static bool _isClassHeader(String val) {
    final v = val.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return v == 'kelas' || v == 'class' || v == 'rombel' || v.contains('namakelas');
  }
}
