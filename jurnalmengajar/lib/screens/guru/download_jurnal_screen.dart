import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/theme/app_theme.dart';
import '../../models/class_model.dart';
import '../../models/journal_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../models/school_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../services/journal_pdf_service.dart';
import '../../widgets/guru_drawer.dart';

class GuruDownloadJurnalScreen extends StatefulWidget {
  const GuruDownloadJurnalScreen({super.key});

  @override
  State<GuruDownloadJurnalScreen> createState() =>
      _GuruDownloadJurnalScreenState();
}

class _GuruDownloadJurnalScreenState extends State<GuruDownloadJurnalScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  String _selectedStatus = 'all'; // 'all', 'verified', 'pending'
  String? _selectedClassId;
  String? _selectedSubjectId;
  String? _selectedSchoolId;

  final TextEditingController _supervisorNameController =
      TextEditingController();
  final TextEditingController _supervisorNipController =
      TextEditingController();
  final TextEditingController _schoolNameController = TextEditingController(
    text: 'SMP NEGERI 1 SATU ATAP MEMPURA',
  );

  String _presetRange = 'Bulan Ini';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _supervisorNameController.dispose();
    _supervisorNipController.dispose();
    _schoolNameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(
      context,
      listen: false,
    );
    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
        orElse: () => TeacherModel(
          id: '',
          name: currentUser.fullName,
          position: '',
          address: '',
          phoneNumber: '',
          email: currentUser.email,
        ),
      );
      if (teacher.id.isNotEmpty) {
        await journalProvider.loadTeacherJournals(teacher.id);
      }

      // Auto match teacher's school from active school provider
      final activeId = authProvider.activeSchoolId;
      final activeSchool = authProvider.activeSchool;
      setState(() {
        _selectedSchoolId = activeId;
        _schoolNameController.text = activeSchool?.name ?? authProvider.activeSchoolName;
      });
    }
  }

  void _applyPresetRange(String preset) {
    final now = DateTime.now();
    setState(() {
      _presetRange = preset;
      if (preset == 'Bulan Ini') {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
      } else if (preset == '30 Hari Terakhir') {
        _startDate = now.subtract(const Duration(days: 30));
        _endDate = now;
      } else if (preset == 'Bulan Lalu') {
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
        _startDate = lastMonth;
        _endDate = lastDayOfLastMonth;
      } else if (preset == 'Semester Ini') {
        // Semester Ganjil: Jul-Des, Semester Genap: Jan-Jun
        final month = now.month;
        if (month >= 7) {
          _startDate = DateTime(now.year, 7, 1);
        } else {
          _startDate = DateTime(now.year, 1, 1);
        }
        _endDate = now;
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _presetRange = 'Kustom';
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  TeacherModel _getCurrentTeacher(
    AuthProvider authProvider,
    MasterDataProvider masterProvider,
  ) {
    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return TeacherModel(
        id: '',
        name: 'Guru Pengajar',
        position: 'Guru Mata Pelajaran',
        address: '',
        phoneNumber: '',
        email: '',
      );
    }
    return masterProvider.teachers.firstWhere(
      (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
      orElse: () => TeacherModel(
        id: currentUser.id,
        name: currentUser.fullName,
        position: 'Guru Pengajar',
        address: '',
        phoneNumber: '',
        email: currentUser.email,
      ),
    );
  }

  List<JournalModel> _getFilteredJournals(
    List<JournalModel> allTeacherJournals,
  ) {
    final startOfDay = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      0,
      0,
      0,
    );
    final endOfDay = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      23,
      59,
      59,
    );

    return allTeacherJournals.where((j) {
      // Date Range Filter
      if (j.date.isBefore(startOfDay) || j.date.isAfter(endOfDay)) {
        return false;
      }
      // Status Filter
      if (_selectedStatus == 'verified' &&
          j.status != 'verified' &&
          j.status != 'approved') {
        return false;
      }
      if (_selectedStatus == 'pending' && j.status != 'pending') {
        return false;
      }
      // Class Filter
      if (_selectedClassId != null && j.classId != _selectedClassId) {
        return false;
      }
      // Subject Filter
      if (_selectedSubjectId != null && j.subjectId != _selectedSubjectId) {
        return false;
      }
      return true;
    }).toList()..sort(
      (a, b) => a.date.compareTo(b.date),
    ); // Sort chronologically ascending for report
  }

  void _openPdfPreview(
    BuildContext context,
    TeacherModel teacher,
    List<JournalModel> journals,
    List<ClassModel> classes,
    List<SubjectModel> subjects,
    MasterDataProvider masterProvider,
    AuthProvider authProvider,
  ) {
    if (journals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada data jurnal yang sesuai dengan filter terpilih.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedClassName = _selectedClassId != null
        ? classes
              .firstWhere(
                (c) => c.id == _selectedClassId,
                orElse: () =>
                    ClassModel(id: '', periodId: '', name: '', studentCount: 0),
              )
              .name
        : null;

    final selectedSubjectName = _selectedSubjectId != null
        ? subjects
              .firstWhere(
                (s) => s.id == _selectedSubjectId,
                orElse: () => SubjectModel(id: '', name: '', isActive: true),
              )
              .name
        : null;

    final selectedSchool = _selectedSchoolId != null
        ? (_selectedSchoolId == authProvider.activeSchoolId
            ? authProvider.activeSchool
            : masterProvider.schools.firstWhere(
                (s) => s.id == _selectedSchoolId,
                orElse: () => SchoolModel(
                  id: 'default',
                  name: _schoolNameController.text.trim(),
                ),
              ))
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              'Pratinjau Laporan PDF',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          body: PdfPreview(
            build: (format) => JournalPdfService.generateJournalReportPdf(
              teacher: teacher,
              journals: journals,
              startDate: _startDate,
              endDate: _endDate,
              classes: classes,                                                                                                             
              subjects: subjects,
              school: selectedSchool,
              supervisorName: _supervisorNameController.text.trim(),
              supervisorNip: _supervisorNipController.text.trim(),
              statusFilter: _selectedStatus,
              selectedClassName: selectedClassName,
              selectedSubjectName: selectedSubjectName,
              schoolName: selectedSchool?.name ??
                  (_schoolNameController.text.trim().isNotEmpty
                      ? _schoolNameController.text.trim()
                      : authProvider.activeSchoolName),
            ),
            pdfFileName:
                'Laporan_Jurnal_${teacher.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.pdf',
            canChangeOrientation: false,
            canChangePageFormat: false,
            initialPageFormat: PdfPageFormat.a4.landscape,
          ),
        ),
      ),
    );
  }

  Future<void> _directDownloadOrPrint(
    TeacherModel teacher,
    List<JournalModel> journals,
    List<ClassModel> classes,
    List<SubjectModel> subjects,
    MasterDataProvider masterProvider,
    AuthProvider authProvider,
  ) async {
    if (journals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak ada data jurnal yang sesuai dengan filter terpilih.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedClassName = _selectedClassId != null
        ? classes
              .firstWhere(
                (c) => c.id == _selectedClassId,
                orElse: () =>
                    ClassModel(id: '', periodId: '', name: '', studentCount: 0),
              )
              .name
        : null;

    final selectedSubjectName = _selectedSubjectId != null
        ? subjects
              .firstWhere(
                (s) => s.id == _selectedSubjectId,
                orElse: () => SubjectModel(id: '', name: '', isActive: true),
              )
              .name
        : null;

    final selectedSchool = _selectedSchoolId != null
        ? (_selectedSchoolId == authProvider.activeSchoolId
            ? authProvider.activeSchool
            : masterProvider.schools.firstWhere(
                (s) => s.id == _selectedSchoolId,
                orElse: () => SchoolModel(
                  id: 'default',
                  name: _schoolNameController.text.trim(),
                ),
              ))
        : null;

    final pdfBytes = await JournalPdfService.generateJournalReportPdf(
      teacher: teacher,
      journals: journals,
      startDate: _startDate,
      endDate: _endDate,
      classes: classes,
      subjects: subjects,
      school: selectedSchool,
      supervisorName: _supervisorNameController.text.trim(),
      supervisorNip: _supervisorNipController.text.trim(),
      statusFilter: _selectedStatus,
      selectedClassName: selectedClassName,
      selectedSubjectName: selectedSubjectName,
      schoolName: selectedSchool?.name ??
          (_schoolNameController.text.trim().isNotEmpty
              ? _schoolNameController.text.trim()
              : authProvider.activeSchoolName),
    );

    final fileName =
        'Laporan_Jurnal_${teacher.name.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(_startDate)}_${DateFormat('yyyyMMdd').format(_endDate)}.pdf';

    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();

    final teacher = _getCurrentTeacher(authProvider, masterProvider);
    final filteredJournals = _getFilteredJournals(
      journalProvider.teacherJournals,
    );
    final dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

    final verifiedCount = filteredJournals
        .where((j) => j.status == 'verified' || j.status == 'approved')
        .length;
    final pendingCount = filteredJournals
        .where((j) => j.status == 'pending')
        .length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () {
              final rootScaffold = ctx
                  .findRootAncestorStateOfType<ScaffoldState>();
              if (rootScaffold != null && rootScaffold.hasDrawer) {
                rootScaffold.openDrawer();
              } else {
                Scaffold.maybeOf(ctx)?.openDrawer();
              }
            },
          ),
        ),
        title: const Text('Download & Setor Jurnal'),
      ),
      drawer: const GuruDrawer(currentRoute: '/guru/download-jurnal'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 28.sp,
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Laporan Setor Supervisor',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Unduh laporan jurnal mengajar resmi dalam format PDF lengkap dengan tabel & kolom tanda tangan.',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.5.sp,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Section 1: Rentang Tanggal
              _buildSectionCard(
                title: '1. Rentang Tanggal Laporan',
                icon: Icons.date_range_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Preset Chips
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children:
                          [
                            'Bulan Ini',
                            '30 Hari Terakhir',
                            'Bulan Lalu',
                            'Semester Ini',
                          ].map((preset) {
                            final isSelected = _presetRange == preset;
                            return ChoiceChip(
                              label: Text(preset),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryColor.withValues(
                                alpha: 0.15,
                              ),
                              labelStyle: GoogleFonts.hankenGrotesk(
                                fontSize: 11.5.sp,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : const Color(0xFF475569),
                              ),
                              onSelected: (_) => _applyPresetRange(preset),
                            );
                          }).toList(),
                    ),

                    SizedBox(height: 14.h),

                    // Date Selectors
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tanggal Mulai',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 10.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: AppTheme.primaryColor,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        dateFormat.format(_startDate),
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: const Color(0xFF94A3B8),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            borderRadius: BorderRadius.circular(10.r),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 10.h,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFFCBD5E1),
                                ),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tanggal Selesai',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 10.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: AppTheme.primaryColor,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        dateFormat.format(_endDate),
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Section 2: Filter Data
              _buildSectionCard(
                title: '2. Filter Status & Kelas',
                icon: Icons.filter_alt_rounded,
                child: Column(
                  children: [
                    // Status Filter Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status Verifikasi Jurnal',
                        prefixIcon: const Icon(
                          Icons.verified_rounded,
                          size: 20,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('Semua Status (Terverifikasi & Pending)'),
                        ),
                        DropdownMenuItem(
                          value: 'verified',
                          child: Text('Hanya Terverifikasi / Disetujui'),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Hanya Menunggu Approval'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStatus = val);
                      },
                    ),

                    SizedBox(height: 12.h),

                    // Class Filter Dropdown
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedClassId,
                      decoration: InputDecoration(
                        labelText: 'Filter Kelas',
                        prefixIcon: const Icon(Icons.class_rounded, size: 20),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Semua Kelas'),
                        ),
                        ...masterProvider.classes.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedClassId = val),
                    ),

                    SizedBox(height: 12.h),

                    // Subject Filter Dropdown
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedSubjectId,
                      decoration: InputDecoration(
                        labelText: 'Filter Mata Pelajaran',
                        prefixIcon: const Icon(Icons.book_rounded, size: 20),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Semua Mata Pelajaran'),
                        ),
                        ...masterProvider.subjects.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedSubjectId = val),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Section 3: Identitas Sekolah Tempat Cetak Jurnal
              _buildSectionCard(
                title: '3. Identitas Sekolah Untuk Kop Dokumen',
                icon: Icons.school_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedSchoolId,
                      decoration: InputDecoration(
                        labelText: 'Pilih Sekolah',
                        hintText: 'Pilih sekolah tempat cetak jurnal',
                        prefixIcon: const Icon(
                          Icons.account_balance_rounded,
                          size: 20,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sekolah Lainnya (Manual)'),
                        ),
                        if (masterProvider.schools.isNotEmpty)
                          ...masterProvider.schools.map(
                            (s) => DropdownMenuItem<String?>(
                              value: s.id,
                              child: Text(
                                s.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedSchoolId = val;
                          if (val != null && masterProvider.schools.isNotEmpty) {
                            final sch = masterProvider.schools.firstWhere(
                              (s) => s.id == val,
                            );
                            _schoolNameController.text = sch.name;
                          }
                        });
                      },
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Kop dokumen PDF akan menggunakan format resmi instansi sesuai sekolah yang dipilih guru.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.sp,
                        color: const Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              // Section 4: Informasi Penandatangan (Supervisor / Kepala Sekolah)
              _buildSectionCard(
                title: '4. Data Supervisor / Penandatangan',
                icon: Icons.draw_rounded,
                child: Column(
                  children: [
                    TextField(
                      controller: _schoolNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama Sekolah (Custom/Manual)',
                        hintText: 'Misal: ${authProvider.activeSchoolName}',
                        prefixIcon: const Icon(Icons.school_rounded, size: 20),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _supervisorNameController,
                      decoration: InputDecoration(
                        labelText: 'Nama (Opsional)',
                        hintText: 'Misal: Dr. H. Ahmad Dahlan, M.Pd.',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _supervisorNipController,
                      decoration: InputDecoration(
                        labelText: 'NIP / ID (Opsional)',
                        hintText: 'Misal: 19780512 200312 1 002',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20.h),

              // Summary Result Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Jurnal Terpilih:',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            '${filteredJournals.length} Entri',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBadgeInfo(
                          'Terverifikasi',
                          '$verifiedCount',
                          const Color(0xFF10B981),
                        ),
                        _buildBadgeInfo(
                          'Menunggu',
                          '$pendingCount',
                          const Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPdfPreview(
                        context,
                        teacher,
                        filteredJournals,
                        masterProvider.classes,
                        masterProvider.subjects,
                        masterProvider,
                        authProvider,
                      ),
                      icon: const Icon(Icons.remove_red_eye_rounded),
                      label: Text(
                        'Pratinjau PDF',
                        style: GoogleFonts.hankenGrotesk(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        side: const BorderSide(
                          color: AppTheme.primaryColor,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _directDownloadOrPrint(
                        teacher,
                        filteredJournals,
                        masterProvider.classes,
                        masterProvider.subjects,
                        masterProvider,
                        authProvider,
                      ),
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Unduh / Cetak',
                        style: GoogleFonts.hankenGrotesk(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primaryColor),
              SizedBox(width: 8.w),
              Text(
                title,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }

  Widget _buildBadgeInfo(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Text(
          '$label: ',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11.5.sp,
            color: const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
