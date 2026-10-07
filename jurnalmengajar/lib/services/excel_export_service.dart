import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../models/journal_model.dart';
import '../models/schedule_model.dart';
import '../models/teacher_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';
import '../models/hour_model.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../models/class_attendance_recap_model.dart';
import '../providers/master_data_provider.dart';
import 'excel_saver.dart';

class ExcelExportService {
  /// Helper to sanitize school / teacher names for safe file names
  static String sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .trim();
  }

  /// Format date consistently as YYYY-MM-DD
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format day name in Indonesian
  static String formatDayName(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return '-';
    }
  }

  /// Standard style for header cells
  static CellStyle headerStyle() {
    return CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'), // Deep blue
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(borderStyle: BorderStyle.Medium),
    );
  }

  /// Standard style for body cells
  static CellStyle bodyStyle({HorizontalAlign align = HorizontalAlign.Left}) {
    return CellStyle(
      fontColorHex: ExcelColor.fromHexString('#1E293B'),
      horizontalAlign: align,
      verticalAlign: VerticalAlign.Center,
    );
  }
  // Export jurnal mengajar.
  static Future<void> exportJournals({
    required List<JournalModel> journals,
    required MasterDataProvider masterProvider,
    required String schoolName,
    String? teacherNameFilter,
    String sheetName = 'Data Jurnal',
  }) async {
    final excel = Excel.createExcel();
    // Use the default sheet or rename it
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetName);
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

    final headerRow = headers.map((h) => TextCellValue(h)).toList();
    sheet.appendRow(headerRow);

    // Apply header styles
    for (var col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = headerStyle();
    }

    final hStyle = bodyStyle();
    final centerStyle = bodyStyle(align: HorizontalAlign.Center);

    // Populate data
    for (int i = 0; i < journals.length; i++) {
      final j = journals[i];
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.id == j.teacherId,
        orElse: () => TeacherModel(
          id: j.teacherId,
          name: 'Guru Tidak Diketahui',
          position: '',
          address: '',
          phoneNumber: '',
          email: '',
        ),
      );
      final cls = masterProvider.classes.firstWhere(
        (c) => c.id == j.classId,
        orElse: () => ClassModel(id: j.classId, name: '-', periodId: '', studentCount: 0),
      );
      final subj = masterProvider.subjects.firstWhere(
        (s) => s.id == j.subjectId,
        orElse: () => SubjectModel(id: j.subjectId, name: '-', isActive: false),
      );

      String statusLabel = 'Menunggu';
      if (j.status == 'verified' || j.status == 'approved') {
        statusLabel = 'Terverifikasi';
      } else if (j.status == 'rejected') {
        statusLabel = 'Ditolak';
      }

      final studentCount = cls.studentCount;
      final presentCount = studentCount > 0
          ? (studentCount - (j.sickCount + j.permissionCount + j.alphaCount)).clamp(0, studentCount)
          : 0;

      final row = [
        IntCellValue(i + 1),
        TextCellValue(formatDate(j.date)),
        TextCellValue(formatDayName(j.date)),
        TextCellValue(teacher.name.isNotEmpty ? teacher.name : '-'),
        TextCellValue(subj.name.isNotEmpty ? subj.name : '-'),
        TextCellValue(cls.name.isNotEmpty ? cls.name : '-'),
        IntCellValue(j.teachingHour),
        TextCellValue(j.material.trim().isNotEmpty ? j.material.trim() : '-'),
        TextCellValue(j.note != null && j.note!.trim().isNotEmpty ? j.note!.trim() : '-'),
        IntCellValue(presentCount),
        IntCellValue(j.sickCount),
        IntCellValue(j.permissionCount),
        IntCellValue(j.alphaCount),
        TextCellValue(statusLabel),
      ];

      sheet.appendRow(row);

      final rowIndex = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: rowIndex)).cellStyle = centerStyle;
    }

    final dateSuffix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final safeSchool = sanitizeFileName(schoolName);
    final prefix = teacherNameFilter != null && teacherNameFilter.isNotEmpty
        ? 'Jurnal_${sanitizeFileName(teacherNameFilter)}'
        : 'Jurnal_Mengajar';
    final fileName = '${prefix}_${safeSchool}_$dateSuffix.xlsx';

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, fileName);
    }
  }
  // Export jadwal mengajar.
  static Future<void> exportSchedules({
    required List<ScheduleModel> schedules,
    required MasterDataProvider masterProvider,
    required String schoolName,
    String sheetName = 'Data Jadwal',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetName);
    final sheet = excel[sheetName];

    final headers = [
      'No',
      'Tanggal',
      'Hari',
      'Guru',
      'Mata Pelajaran',
      'Kelas',
      'Jam Ke',
      'Catatan',
      'Status Aktif',
    ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle();
    }

    final hStyle = bodyStyle();
    final centerStyle = bodyStyle(align: HorizontalAlign.Center);

    for (int i = 0; i < schedules.length; i++) {
      final s = schedules[i];
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.id == s.teacherId,
        orElse: () => TeacherModel(
          id: s.teacherId,
          name: 'Guru Tidak Diketahui',
          position: '',
          address: '',
          phoneNumber: '',
          email: '',
        ),
      );
      final cls = masterProvider.classes.firstWhere(
        (c) => c.id == s.classId,
        orElse: () => ClassModel(id: s.classId, name: '-', periodId: '', studentCount: 0),
      );
      final subj = masterProvider.subjects.firstWhere(
        (sub) => sub.id == s.subjectId,
        orElse: () => SubjectModel(id: s.subjectId, name: '-', isActive: false),
      );

      final row = [
        IntCellValue(i + 1),
        TextCellValue(formatDate(s.date)),
        TextCellValue(formatDayName(s.date)),
        TextCellValue(teacher.name.isNotEmpty ? teacher.name : '-'),
        TextCellValue(subj.name.isNotEmpty ? subj.name : '-'),
        TextCellValue(cls.name.isNotEmpty ? cls.name : '-'),
        IntCellValue(s.teachingHour),
        TextCellValue(s.note != null && s.note!.trim().isNotEmpty ? s.note!.trim() : '-'),
        TextCellValue(s.isActive ? 'Aktif' : 'Tidak Aktif'),
      ];

      sheet.appendRow(row);
      final rowIndex = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).cellStyle = centerStyle;
    }

    final dateSuffix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final safeSchool = sanitizeFileName(schoolName);
    final fileName = 'Jadwal_Mengajar_${safeSchool}_$dateSuffix.xlsx';

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, fileName);
    }
  }
  // Export data guru.
  static Future<void> exportTeachers({
    required List<TeacherModel> teachers,
    required String schoolName,
    List<ScheduleModel>? schedules,
    MasterDataProvider? masterProvider,
    String sheetName = 'Data Guru',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetName);
    final sheet = excel[sheetName];

    final headers = [
      'No',
      'Nama Guru',
      'Jabatan / Posisi',
      'Mata Pelajaran Diampu',
      'Email',
      'Nomor Telepon',
      'Alamat',
    ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle();
    }

    final hStyle = bodyStyle();
    final centerStyle = bodyStyle(align: HorizontalAlign.Center);

    for (int i = 0; i < teachers.length; i++) {
      final t = teachers[i];

      // Identify subjects taught by this teacher from schedules if provided
      String subjectsTaught = '-';
      if (schedules != null && masterProvider != null) {
        final teacherScheds = schedules.where((s) => s.teacherId == t.id);
        final subjectNames = teacherScheds.map((s) {
          final subj = masterProvider.subjects.firstWhere(
            (sub) => sub.id == s.subjectId,
            orElse: () => SubjectModel(id: '', name: '', isActive: false),
          );
          return subj.name;
        }).where((name) => name.isNotEmpty).toSet().toList();
        if (subjectNames.isNotEmpty) {
          subjectsTaught = subjectNames.join(', ');
        }
      }

      final row = [
        IntCellValue(i + 1),
        TextCellValue(t.name.trim().isNotEmpty ? t.name.trim() : '-'),
        TextCellValue(t.position.trim().isNotEmpty ? t.position.trim() : '-'),
        TextCellValue(subjectsTaught),
        TextCellValue(t.email.trim().isNotEmpty ? t.email.trim() : '-'),
        TextCellValue(t.phoneNumber.trim().isNotEmpty ? t.phoneNumber.trim() : '-'),
        TextCellValue(t.address.trim().isNotEmpty ? t.address.trim() : '-'),
      ];

      sheet.appendRow(row);
      final rowIndex = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).cellStyle = hStyle;
    }

    // Add secondary sheet "Jadwal Guru" if schedules are provided
    if (schedules != null && schedules.isNotEmpty && masterProvider != null) {
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
      for (var col = 0; col < schedHeaders.length; col++) {
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle();
      }

      // Filter schedules to only include the teachers being exported
      final teacherIds = teachers.map((t) => t.id).toSet();
      final relevantSchedules = schedules.where((s) => teacherIds.contains(s.teacherId)).toList();

      for (int i = 0; i < relevantSchedules.length; i++) {
        final s = relevantSchedules[i];
        final teacher = teachers.firstWhere(
          (t) => t.id == s.teacherId,
          orElse: () => masterProvider.teachers.firstWhere(
            (t) => t.id == s.teacherId,
            orElse: () => TeacherModel(id: '', name: '-', position: '', address: '', phoneNumber: '', email: ''),
          ),
        );
        final subj = masterProvider.subjects.firstWhere(
          (sub) => sub.id == s.subjectId,
          orElse: () => SubjectModel(id: '', name: '-', isActive: false),
        );
        final cls = masterProvider.classes.firstWhere(
          (c) => c.id == s.classId,
          orElse: () => ClassModel(id: '', name: '-', periodId: '', studentCount: 0),
        );
        final hour = masterProvider.hours.firstWhere(
          (h) => h.teachingHour == s.teachingHour,
          orElse: () => HourModel(id: '', teachingHour: s.teachingHour, startTime: '', endTime: ''),
        );
        final timeStr = hour.startTime.isNotEmpty && hour.endTime.isNotEmpty
            ? '${hour.startTime} - ${hour.endTime}'
            : '-';

        final schedRow = [
          IntCellValue(i + 1),
          TextCellValue(teacher.name.isNotEmpty ? teacher.name : '-'),
          TextCellValue(subj.name.isNotEmpty ? subj.name : '-'),
          TextCellValue(cls.name.isNotEmpty ? cls.name : '-'),
          TextCellValue(formatDayName(s.date)),
          IntCellValue(s.teachingHour),
          TextCellValue(timeStr),
          TextCellValue(s.note != null && s.note!.trim().isNotEmpty ? s.note!.trim() : '-'),
          TextCellValue(s.isActive ? 'Aktif' : 'Tidak Aktif'),
        ];
        schedSheet.appendRow(schedRow);

        final rowIndex = i + 1;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = hStyle;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = hStyle;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = centerStyle;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = centerStyle;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = centerStyle;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).cellStyle = centerStyle;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).cellStyle = hStyle;
        schedSheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).cellStyle = centerStyle;
      }
    }

    final dateSuffix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final safeSchool = sanitizeFileName(schoolName);
    final fileName = 'Data_Guru_${safeSchool}_$dateSuffix.xlsx';

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, fileName);
    }
  }
  // Export master kelas.
  static Future<void> exportClasses({
    required List<ClassModel> classes,
    required MasterDataProvider masterProvider,
    required String schoolName,
    String sheetName = 'Data Kelas',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetName);
    final sheet = excel[sheetName];

    final headers = [
      'No',
      'Nama Kelas',
      'Tahun Ajaran / Periode',
      'Jumlah Siswa',
    ];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle();
    }

    final hStyle = bodyStyle();
    final centerStyle = bodyStyle(align: HorizontalAlign.Center);

    for (int i = 0; i < classes.length; i++) {
      final c = classes[i];
      final period = masterProvider.periods.firstWhere(
        (p) => p.id == c.periodId,
        orElse: () => masterProvider.activePeriod != null && masterProvider.activePeriod!.id == c.periodId
            ? masterProvider.activePeriod!
            : throw Exception(),
      );
      final periodName = period.name.isNotEmpty ? period.name : '-';

      final row = [
        IntCellValue(i + 1),
        TextCellValue(c.name.trim().isNotEmpty ? c.name.trim() : '-'),
        TextCellValue(periodName),
        IntCellValue(c.studentCount),
      ];

      sheet.appendRow(row);
      final rowIndex = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = centerStyle;
    }

    final dateSuffix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final safeSchool = sanitizeFileName(schoolName);
    final fileName = 'Data_Kelas_${safeSchool}_$dateSuffix.xlsx';

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, fileName);
    }
  }
  // Export siswa per kelas.
  static Future<void> exportStudents({
    required List<StudentModel> students,
    required String className,
    required String schoolName,
    String sheetName = 'Data Siswa',
  }) async {
    final excel = Excel.createExcel();
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
    for (var col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle();
    }

    final hStyle = bodyStyle();
    final centerStyle = bodyStyle(align: HorizontalAlign.Center);

    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      final genderLabel = s.gender == 'L'
          ? 'Laki-laki'
          : (s.gender == 'P' ? 'Perempuan' : '-');

      final row = [
        IntCellValue(i + 1),
        TextCellValue(s.name.trim().isNotEmpty ? s.name.trim() : '-'),
        TextCellValue(s.nis != null && s.nis!.trim().isNotEmpty ? s.nis!.trim() : '-'),
        TextCellValue(genderLabel),
        TextCellValue(s.parentPhoneNumber != null && s.parentPhoneNumber!.trim().isNotEmpty
            ? s.parentPhoneNumber!.trim()
            : '-'),
        TextCellValue(className),
      ];

      sheet.appendRow(row);
      final rowIndex = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = centerStyle;
    }

    final dateSuffix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final safeSchool = sanitizeFileName(schoolName);
    final safeClass = sanitizeFileName(className);
    final fileName = 'Siswa_${safeClass}_${safeSchool}_$dateSuffix.xlsx';

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, fileName);
    }
  }
  // Export master user dan hak akses.
  static Future<void> exportUsers({
    required List<UserModel> users,
    required String schoolName,
    String sheetName = 'Master User',
  }) async {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, sheetName);
    final sheet = excel[sheetName];

    // Strictly NO passwords, NO tokens, NO credentials, NO secrets
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
    for (var col = 0; col < headers.length; col++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle();
    }

    final hStyle = bodyStyle();
    final centerStyle = bodyStyle(align: HorizontalAlign.Center);

    for (int i = 0; i < users.length; i++) {
      final u = users[i];

      String roleDisplay = u.role.toUpperCase();
      if (u.role.toLowerCase() == 'guru') roleDisplay = 'Guru';
      if (u.role.toLowerCase() == 'admin') roleDisplay = 'Admin Sekolah';
      if (u.role.toLowerCase() == 'superadmin') roleDisplay = 'Super Admin';
      if (u.role.toLowerCase() == 'pending_guru') roleDisplay = 'Calon Guru';

      String statusDisplay = 'Aktif';
      if (u.isPending || u.status == 'pending') {
        statusDisplay = 'Menunggu Verifikasi';
      } else if (u.status == 'inactive') {
        statusDisplay = 'Non-Aktif';
      }

      final membershipRole = u.membershipRole != null && u.membershipRole!.isNotEmpty
          ? (u.membershipRole!.toLowerCase() == 'admin' ? 'Admin Sekolah' : 'Guru')
          : roleDisplay;

      final row = [
        IntCellValue(i + 1),
        TextCellValue(u.fullName.trim().isNotEmpty ? u.fullName.trim() : '-'),
        TextCellValue(u.email.trim().isNotEmpty ? u.email.trim() : '-'),
        TextCellValue(roleDisplay),
        TextCellValue(membershipRole),
        TextCellValue(statusDisplay),
        TextCellValue(u.phoneNumber != null && u.phoneNumber!.trim().isNotEmpty ? u.phoneNumber!.trim() : '-'),
      ];

      sheet.appendRow(row);
      final rowIndex = i + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).cellStyle = centerStyle;
    }

    final dateSuffix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final safeSchool = sanitizeFileName(schoolName);
    final fileName = 'Master_User_${safeSchool}_$dateSuffix.xlsx';

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, fileName);
    }
  }
  // Export rekap kehadiran kelas.
  static Future<void> exportClassAttendanceRecap({
    required String className,
    required String periodName,
    required String schoolName,
    required List<StudentAttendanceSummary> studentSummaries,
    required List<JournalModel> classJournals,
    required MasterDataProvider masterProvider,
    String? dateRangeText,
  }) async {
    final excel = Excel.createExcel();

    // ── Sheet 1: Rekap Siswa ──────────────────────────────────────────────────
    final studentSheetName = 'Rekap Presensi Siswa';
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, studentSheetName);
    final sheet1 = excel[studentSheetName];

    final headers1 = [
      'No',
      'Nama Siswa',
      'NIS',
      'L/P',
      'Hadir (H)',
      'Sakit (S)',
      'Izin (I)',
      'Alfa (A)',
      'Total Sesi',
      '% Kehadiran',
      'Status',
    ];

    sheet1.appendRow(headers1.map((h) => TextCellValue(h)).toList());
    for (var col = 0; col < headers1.length; col++) {
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle();
    }

    final hStyle = bodyStyle();
    final centerStyle = bodyStyle(align: HorizontalAlign.Center);

    for (int i = 0; i < studentSummaries.length; i++) {
      final summary = studentSummaries[i];
      final s = summary.student;
      final genderLabel = s.gender == 'L'
          ? 'L'
          : (s.gender == 'P' ? 'P' : '-');

      final row = [
        IntCellValue(i + 1),
        TextCellValue(s.name.trim().isNotEmpty ? s.name.trim() : '-'),
        TextCellValue(s.nis != null && s.nis!.trim().isNotEmpty ? s.nis!.trim() : '-'),
        TextCellValue(genderLabel),
        IntCellValue(summary.presentCount),
        IntCellValue(summary.sickCount),
        IntCellValue(summary.permissionCount),
        IntCellValue(summary.alphaCount),
        IntCellValue(summary.totalMeetings),
        TextCellValue('${summary.attendancePercentage.toStringAsFixed(1)}%'),
        TextCellValue(summary.performanceLabel),
      ];

      sheet1.appendRow(row);
      final rowIndex = i + 1;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet1.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).cellStyle = centerStyle;
    }

    // ── Sheet 2: Log Pertemuan ────────────────────────────────────────────────
    final logSheetName = 'Log Pertemuan Kelas';
    final sheet2 = excel[logSheetName];

    final headers2 = [
      'No',
      'Tanggal',
      'Hari',
      'Jam Ke-',
      'Mata Pelajaran',
      'Guru Pengajar',
      'Materi',
      'Hadir',
      'Sakit',
      'Izin',
      'Alfa',
      'Siswa Tidak Hadir',
    ];

    sheet2.appendRow(headers2.map((h) => TextCellValue(h)).toList());
    for (var col = 0; col < headers2.length; col++) {
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle();
    }

    // Sort journals chronologically
    final sortedJournals = List<JournalModel>.from(classJournals)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (int i = 0; i < sortedJournals.length; i++) {
      final j = sortedJournals[i];
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.id == j.teacherId,
        orElse: () => TeacherModel(
          id: j.teacherId,
          name: 'Guru Tidak Diketahui',
          position: '',
          address: '',
          phoneNumber: '',
          email: '',
        ),
      );
      final subj = masterProvider.subjects.firstWhere(
        (s) => s.id == j.subjectId,
        orElse: () => SubjectModel(id: j.subjectId, name: '-', isActive: false),
      );

      final absenceInfo = JournalAbsenceInfo.fromJournal(j);
      final absentList = <String>[];
      if (absenceInfo.sickStudentNames.isNotEmpty) {
        absentList.add('Sakit: ${absenceInfo.sickStudentNames.join(", ")}');
      }
      if (absenceInfo.permissionStudentNames.isNotEmpty) {
        absentList.add('Izin: ${absenceInfo.permissionStudentNames.join(", ")}');
      }
      if (absenceInfo.alphaStudentNames.isNotEmpty) {
        absentList.add('Alfa: ${absenceInfo.alphaStudentNames.join(", ")}');
      }
      final absentDetailsStr = absentList.isNotEmpty ? absentList.join(' | ') : 'Semua Hadir';

      final totalStudentsInClass = studentSummaries.isNotEmpty ? studentSummaries.length : 30;
      final totalAbsents = j.sickCount + j.permissionCount + j.alphaCount;
      final presentCount = (totalStudentsInClass - totalAbsents).clamp(0, totalStudentsInClass);

      final row = [
        IntCellValue(i + 1),
        TextCellValue(formatDate(j.date)),
        TextCellValue(formatDayName(j.date)),
        IntCellValue(j.teachingHour),
        TextCellValue(subj.name.isNotEmpty ? subj.name : '-'),
        TextCellValue(teacher.name.isNotEmpty ? teacher.name : '-'),
        TextCellValue(j.material.trim().isNotEmpty ? j.material.trim() : '-'),
        IntCellValue(presentCount),
        IntCellValue(j.sickCount),
        IntCellValue(j.permissionCount),
        IntCellValue(j.alphaCount),
        TextCellValue(absentDetailsStr),
      ];

      sheet2.appendRow(row);
      final rowIndex = i + 1;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).cellStyle = hStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).cellStyle = centerStyle;
      sheet2.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).cellStyle = hStyle;
    }

    final dateSuffix = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final safeClass = sanitizeFileName(className);
    final safePeriod = sanitizeFileName(periodName);
    final fileName = 'Rekap_Presensi_${safeClass}_${safePeriod}_$dateSuffix.xlsx';

    final bytes = excel.save();
    if (bytes != null) {
      downloadOrShareExcel(bytes, fileName);
    }
  }
}

