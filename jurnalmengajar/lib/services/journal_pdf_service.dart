import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/journal_model.dart';
import '../models/teacher_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';

class JournalPdfService {
  /// Generates a PDF byte array for teaching journals report tailored for supervisors.
  static Future<Uint8List> generateJournalReportPdf({
    required TeacherModel teacher,
    required List<JournalModel> journals,
    required DateTime startDate,
    required DateTime endDate,
    required List<ClassModel> classes,
    required List<SubjectModel> subjects,
    String? supervisorName,
    String? supervisorNip,
    String statusFilter = 'all',
    String? selectedClassName,
    String? selectedSubjectName,
    String schoolName = 'Jurnal Mengajar Guru',
  }) async {
    final pdf = pw.Document();

    // Setup Indonesian Date Formatters
    final dateFormat = DateFormat('dd/MM/yyyy');
    final fullDateFormat = DateFormat('d MMMM yyyy', 'id_ID');
    final printDateStr = fullDateFormat.format(DateTime.now());
    final periodStr = '${dateFormat.format(startDate)} s/d ${dateFormat.format(endDate)}';

    // Map helpers for quick lookups
    final classMap = {for (var c in classes) c.id: c.name};
    final subjectMap = {for (var s in subjects) s.id: s.name};

    // Calculate Summary Statistics
    final totalJournals = journals.length;
    final verifiedCount = journals.where((j) => j.status == 'verified' || j.status == 'approved').length;
    final pendingCount = journals.where((j) => j.status == 'pending').length;
    final totalSick = journals.fold<int>(0, (sum, j) => sum + j.sickCount);
    final totalPermission = journals.fold<int>(0, (sum, j) => sum + j.permissionCount);
    final totalAlpha = journals.fold<int>(0, (sum, j) => sum + j.alphaCount);

    // Font setup using Printing Google Fonts for clean Indonesian typography
    final ttfRegular = await PdfGoogleFonts.interRegular();
    final ttfBold = await PdfGoogleFonts.interBold();
    final ttfMedium = await PdfGoogleFonts.interMedium();

    final theme = pw.ThemeData.withFont(
      base: ttfRegular,
      bold: ttfBold,
    );

    // Add Page to Document (Landscape mode for spacious table columns)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        orientation: pw.PageOrientation.landscape,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        header: (pw.Context context) => _buildHeader(
          schoolName: schoolName,
          periodStr: periodStr,
          ttfBold: ttfBold,
          ttfRegular: ttfRegular,
          pageNumber: context.pageNumber,
          totalPages: context.pagesCount,
        ),
        footer: (pw.Context context) => _buildFooter(
          context: context,
          ttfRegular: ttfRegular,
        ),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 10),

            // Teacher Metadata Box & Filter Badges
            _buildTeacherInfoBox(
              teacher: teacher,
              printDateStr: printDateStr,
              selectedClassName: selectedClassName,
              selectedSubjectName: selectedSubjectName,
              statusFilter: statusFilter,
              ttfBold: ttfBold,
              ttfRegular: ttfRegular,
              ttfMedium: ttfMedium,
            ),

            pw.SizedBox(height: 12),

            // Summary Statistics Widgets
            _buildSummaryStats(
              totalJournals: totalJournals,
              verifiedCount: verifiedCount,
              pendingCount: pendingCount,
              totalSick: totalSick,
              totalPermission: totalPermission,
              totalAlpha: totalAlpha,
              ttfBold: ttfBold,
              ttfRegular: ttfRegular,
            ),

            pw.SizedBox(height: 14),

            // Main Journal Data Table
            if (journals.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Tidak ada data jurnal mengajar dalam kurun waktu yang dipilih.',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              _buildJournalTable(
                journals: journals,
                classMap: classMap,
                subjectMap: subjectMap,
                dateFormat: dateFormat,
                ttfBold: ttfBold,
                ttfRegular: ttfRegular,
              ),

            pw.SizedBox(height: 24),

            // Signature Block Section
            _buildSignatureBlock(
              teacher: teacher,
              supervisorName: supervisorName,
              supervisorNip: supervisorNip,
              printDateStr: printDateStr,
              ttfBold: ttfBold,
              ttfRegular: ttfRegular,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Header widget rendered at top of each page
  static pw.Widget _buildHeader({
    required String schoolName,
    required String periodStr,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
    required int pageNumber,
    required int totalPages,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LAPORAN JURNAL MENGAJAR GURU',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 14,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Periode Tanggal: $periodStr',
                  style: pw.TextStyle(
                    font: ttfRegular,
                    fontSize: 9,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  schoolName,
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 10,
                    color: PdfColors.indigo700,
                  ),
                ),
                pw.Text(
                  'Halaman $pageNumber dari $totalPages',
                  style: pw.TextStyle(
                    font: ttfRegular,
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: PdfColors.indigo700, thickness: 1.5),
      ],
    );
  }

  /// Footer widget rendered at bottom of pages
  static pw.Widget _buildFooter({
    required pw.Context context,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Dicetak secara otomatis melalui Sistem Jurnal Mengajar',
        style: pw.TextStyle(
          font: ttfRegular,
          fontSize: 7,
          color: PdfColors.grey500,
        ),
      ),
    );
  }

  /// Teacher Meta Info & Active Filters Block
  static pw.Widget _buildTeacherInfoBox({
    required TeacherModel teacher,
    required String printDateStr,
    String? selectedClassName,
    String? selectedSubjectName,
    required String statusFilter,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
    required pw.Font ttfMedium,
  }) {
    String statusLabel = 'Semua Status';
    if (statusFilter == 'verified') statusLabel = 'Hanya Terverifikasi';
    if (statusFilter == 'pending') statusLabel = 'Hanya Menunggu Approval';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.indigo50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.indigo200, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('Nama Guru  : ', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
                  pw.Text(teacher.name.isNotEmpty ? teacher.name : 'Guru Pengajar', style: pw.TextStyle(font: ttfRegular, fontSize: 9.5)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                children: [
                  pw.Text('Jabatan / Posisi : ', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
                  pw.Text(teacher.position.isNotEmpty ? teacher.position : 'Guru Mata Pelajaran', style: pw.TextStyle(font: ttfRegular, fontSize: 9.5)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('Email / Kontak : ', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
                  pw.Text(teacher.email.isNotEmpty ? teacher.email : '-', style: pw.TextStyle(font: ttfRegular, fontSize: 9.5)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                children: [
                  pw.Text('Filter Status : ', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
                  pw.Text(statusLabel, style: pw.TextStyle(font: ttfRegular, fontSize: 9.5, color: PdfColors.indigo800)),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text('Filter Kelas : ', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
                  pw.Text(selectedClassName ?? 'Semua Kelas', style: pw.TextStyle(font: ttfRegular, fontSize: 9.5)),
                ],
              ),
              pw.SizedBox(height: 3),
              pw.Row(
                children: [
                  pw.Text('Filter Mapel : ', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
                  pw.Text(selectedSubjectName ?? 'Semua Mapel', style: pw.TextStyle(font: ttfRegular, fontSize: 9.5)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Summary Statistics Boxes
  static pw.Widget _buildSummaryStats({
    required int totalJournals,
    required int verifiedCount,
    required int pendingCount,
    required int totalSick,
    required int totalPermission,
    required int totalAlpha,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
  }) {
    return pw.Row(
      children: [
        _buildStatCard('Total Jurnal', '$totalJournals', PdfColors.blue800, ttfBold, ttfRegular),
        pw.SizedBox(width: 8),
        _buildStatCard('Terverifikasi', '$verifiedCount', PdfColors.green800, ttfBold, ttfRegular),
        pw.SizedBox(width: 8),
        _buildStatCard('Menunggu', '$pendingCount', PdfColors.orange800, ttfBold, ttfRegular),
        pw.SizedBox(width: 8),
        _buildStatCard('Sakit (S)', '$totalSick', PdfColors.purple800, ttfBold, ttfRegular),
        pw.SizedBox(width: 8),
        _buildStatCard('Izin (I)', '$totalPermission', PdfColors.amber900, ttfBold, ttfRegular),
        pw.SizedBox(width: 8),
        _buildStatCard('Alpha (A)', '$totalAlpha', PdfColors.red800, ttfBold, ttfRegular),
      ],
    );
  }

  static pw.Widget _buildStatCard(
    String label,
    String value,
    PdfColor color,
    pw.Font ttfBold,
    pw.Font ttfRegular,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(font: ttfBold, fontSize: 11, color: color),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              label,
              style: pw.TextStyle(font: ttfRegular, fontSize: 7.5, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );
  }

  /// Main Table Construction
  static pw.Widget _buildJournalTable({
    required List<JournalModel> journals,
    required Map<String, String> classMap,
    required Map<String, String> subjectMap,
    required DateFormat dateFormat,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
  }) {
    final headers = [
      'No',
      'Tanggal',
      'Jam',
      'Kelas',
      'Mata Pelajaran',
      'Materi / Kegiatan Pembelajaran',
      'Absensi (S/I/A)',
      'Catatan',
      'Status',
    ];

    final data = journals.asMap().entries.map((entry) {
      final idx = entry.key + 1;
      final j = entry.value;
      final className = classMap[j.classId] ?? j.classId;
      final subjectName = subjectMap[j.subjectId] ?? j.subjectId;
      final dateStr = dateFormat.format(j.date);
      final attendanceStr = 'S:${j.sickCount} | I:${j.permissionCount} | A:${j.alphaCount}';

      String statusText = 'Pending';
      if (j.status == 'verified' || j.status == 'approved') {
        statusText = 'Verifikasi';
      } else if (j.status == 'rejected') {
        statusText = 'Ditolak';
      }

      return [
        '$idx',
        dateStr,
        'Ke-${j.teachingHour}',
        className,
        subjectName,
        j.material,
        attendanceStr,
        j.note != null && j.note!.isNotEmpty ? j.note! : '-',
        statusText,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headerStyle: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
      cellStyle: pw.TextStyle(font: ttfRegular, fontSize: 8, color: PdfColors.grey900),
      cellHeight: 20,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerLeft,
        4: pw.Alignment.centerLeft,
        5: pw.Alignment.centerLeft,
        6: pw.Alignment.center,
        7: pw.Alignment.centerLeft,
        8: pw.Alignment.center,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(22),  // No
        1: const pw.FixedColumnWidth(55),  // Tanggal
        2: const pw.FixedColumnWidth(35),  // Jam
        3: const pw.FixedColumnWidth(60),  // Kelas
        4: const pw.FixedColumnWidth(85),  // Mapel
        5: const pw.FlexColumnWidth(3),    // Materi
        6: const pw.FixedColumnWidth(70),  // Absensi
        7: const pw.FlexColumnWidth(2),    // Catatan
        8: const pw.FixedColumnWidth(55),  // Status
      },
    );
  }

  /// Official Signature Block Footer
  static pw.Widget _buildSignatureBlock({
    required TeacherModel teacher,
    String? supervisorName,
    String? supervisorNip,
    required String printDateStr,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
  }) {
    return pw.Container(
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // Left Side: Supervisor / Headmaster
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Mengetahui,',
                style: pw.TextStyle(font: ttfRegular, fontSize: 9),
              ),
              pw.Text(
                'Supervisor / Kepala Sekolah',
                style: pw.TextStyle(font: ttfBold, fontSize: 9.5),
              ),
              pw.SizedBox(height: 45), // Space for physical signature & stamp
              pw.Text(
                (supervisorName != null && supervisorName.isNotEmpty)
                    ? supervisorName
                    : '( .................................................... )',
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 9.5,
                  decoration: (supervisorName != null && supervisorName.isNotEmpty)
                      ? pw.TextDecoration.underline
                      : null,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                (supervisorNip != null && supervisorNip.isNotEmpty)
                    ? 'NIP. $supervisorNip'
                    : 'NIP. ........................................',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8.5),
              ),
            ],
          ),

          // Right Side: Teacher
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Dicetak pada: $printDateStr',
                style: pw.TextStyle(font: ttfRegular, fontSize: 9),
              ),
              pw.Text(
                'Guru Pengajar,',
                style: pw.TextStyle(font: ttfBold, fontSize: 9.5),
              ),
              pw.SizedBox(height: 45), // Space for physical signature
              pw.Text(
                teacher.name.isNotEmpty ? teacher.name : '( Nama Guru )',
                style: pw.TextStyle(font: ttfBold, fontSize: 9.5, decoration: pw.TextDecoration.underline),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'NIP / ID Guru: ${teacher.id.isNotEmpty ? teacher.id : "-"}',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
