import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/admin_search_filter_bar.dart';
import '../../widgets/state_widgets.dart';
import '../../core/utils/helper.dart';
import '../../widgets/app_scaffold.dart';

class ApprovalJurnalScreen extends StatefulWidget {
  const ApprovalJurnalScreen({super.key});

  @override
  State<ApprovalJurnalScreen> createState() => _ApprovalJurnalScreenState();
}

class _ApprovalJurnalScreenState extends State<ApprovalJurnalScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedClassId = 'all';
  final Set<String> _selectedJournalIds = {};
  bool _isBatchProcessing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await Future.wait([
      journalProvider.loadAllJournals(authProvider.activeSchoolId),
      masterProvider.loadAllData(authProvider.activeSchoolId),
    ]);
  }

  void _toggleSelectJournal(String id) {
    setState(() {
      if (_selectedJournalIds.contains(id)) {
        _selectedJournalIds.remove(id);
      } else {
        _selectedJournalIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<dynamic> visibleJournals) {
    setState(() {
      final visibleIds = visibleJournals.map((j) => j.id as String).toSet();
      if (_selectedJournalIds.containsAll(visibleIds)) {
        _selectedJournalIds.removeAll(visibleIds);
      } else {
        _selectedJournalIds.addAll(visibleIds);
      }
    });
  }

  Future<void> _handleBulkApprove(List<String> ids) async {
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Setujui Massal',
                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ),
          ],
        ),
        content: Text(
          'Setujui ${ids.length} jurnal yang dipilih sekaligus?\nSemua jurnal ini akan berstatus diverifikasi.',
          style: GoogleFonts.hankenGrotesk(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            child: Text('Ya, Setujui (${ids.length})'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBatchProcessing = true);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final success = await journalProvider.verifyMultipleJournals(ids, 'verified');

    if (mounted) {
      setState(() {
        _isBatchProcessing = false;
        if (success) {
          _selectedJournalIds.removeAll(ids);
        }
      });
      if (success) {
        AppHelper.showSnackBar(context, '${ids.length} jurnal berhasil diverifikasi');
      } else {
        AppHelper.showSnackBar(
          context,
          journalProvider.errorMessage ?? 'Gagal memverifikasi jurnal.',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleBulkReject(List<String> ids) async {
    if (ids.isEmpty) return;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFE11D48)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Tolak Massal',
                style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold, fontSize: 16.sp),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tolak ${ids.length} jurnal yang dipilih?',
              style: GoogleFonts.hankenGrotesk(fontSize: 13.sp),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: 'Alasan penolakan (opsional)',
                hintStyle: TextStyle(fontSize: 12.sp),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
            ),
            child: Text('Tolak (${ids.length})'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBatchProcessing = true);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final note = noteController.text.trim();
    final success = await journalProvider.verifyMultipleJournals(
      ids,
      'rejected',
      rejectionNote: note.isNotEmpty ? note : null,
    );

    if (mounted) {
      setState(() {
        _isBatchProcessing = false;
        if (success) {
          _selectedJournalIds.removeAll(ids);
        }
      });
      if (success) {
        AppHelper.showSnackBar(context, '${ids.length} jurnal telah ditolak');
      } else {
        AppHelper.showSnackBar(
          context,
          journalProvider.errorMessage ?? 'Gagal memproses penolakan jurnal.',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleApprove(String journalId, String teacherId) async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final success = await journalProvider.verifyJournal(journalId, 'verified', teacherId: teacherId);
    if (success && mounted) {
      _selectedJournalIds.remove(journalId);
      AppHelper.showSnackBar(context, 'Jurnal berhasil diverifikasi (Disetujui)');
    } else if (mounted) {
      AppHelper.showSnackBar(context, journalProvider.errorMessage ?? 'Gagal memverifikasi jurnal.', isError: true);
    }
  }

  Future<void> _handleReject(String journalId, String teacherId) async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final success = await journalProvider.verifyJournal(journalId, 'rejected', teacherId: teacherId);
    if (success && mounted) {
      _selectedJournalIds.remove(journalId);
      AppHelper.showSnackBar(context, 'Jurnal berhasil ditolak');
    } else if (mounted) {
      AppHelper.showSnackBar(context, journalProvider.errorMessage ?? 'Gagal memverifikasi jurnal.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();

    final schoolTeacherIds = masterProvider.teachers.map((t) => t.id).toSet();

    final pendingJournals = journalProvider.journals.where((j) {
      return j.status == 'pending' &&
          (schoolTeacherIds.isEmpty || schoolTeacherIds.contains(j.teacherId));
    }).toList();

    final filteredPendingJournals = pendingJournals.where((j) {
      if (_selectedClassId != 'all' && j.classId != _selectedClassId) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final cls = masterProvider.classes.firstWhere(
        (c) => c.id == j.classId,
        orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
      );
      final subject = masterProvider.subjects.firstWhere(
        (s) => s.id == j.subjectId,
        orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
      );
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.id == j.teacherId,
        orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
      );
      return teacher.name.toLowerCase().contains(query) ||
          cls.name.toLowerCase().contains(query) ||
          subject.name.toLowerCase().contains(query) ||
          j.material.toLowerCase().contains(query);
    }).toList();

    final filterItems = [
      AdminFilterItem(id: 'all', label: 'Semua Kelas', count: pendingJournals.length),
      ...masterProvider.classes.where((c) => pendingJournals.any((j) => j.classId == c.id)).map((c) => AdminFilterItem(
        id: c.id,
        label: c.name,
        count: pendingJournals.where((j) => j.classId == c.id).length,
      )),
    ];

    final isLoading = journalProvider.isLoading || masterProvider.isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        scrolledUnderElevation: 0,
        title: Text(
          'Persetujuan Jurnal',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/journals'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingJournals.isEmpty
              ? const AppEmptyWidget(
                  title: 'Semua Jurnal Bersih',
                  subtitle: 'Tidak ada jurnal mengajar yang menunggu verifikasi saat ini.',
                  icon: Icons.done_all_rounded,
                )
              : Column(
                  children: [
                    AdminSearchFilterBar(
                      hintText: 'Cari guru, kelas, atau mapel...',
                      searchController: _searchController,
                      onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                      filterItems: filterItems,
                      selectedFilterId: _selectedClassId,
                      onFilterSelected: (id) => setState(() => _selectedClassId = id),
                    ),
                    if (filteredPendingJournals.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => _toggleSelectAll(filteredPendingJournals),
                              borderRadius: BorderRadius.circular(8.r),
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 22.w,
                                      height: 22.w,
                                      child: Checkbox(
                                        value: filteredPendingJournals.isNotEmpty &&
                                            filteredPendingJournals.every((j) => _selectedJournalIds.contains(j.id)),
                                        onChanged: (_) => _toggleSelectAll(filteredPendingJournals),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
                                        activeColor: const Color(0xFF2563EB),
                                      ),
                                    ),
                                    SizedBox(width: 6.w),
                                    Text(
                                      'Pilih Semua (${filteredPendingJournals.length})',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 12.5.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_selectedJournalIds.isNotEmpty)
                              TextButton(
                                onPressed: () => setState(() => _selectedJournalIds.clear()),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.symmetric(horizontal: 8.w),
                                ),
                                child: Text(
                                  'Batal Pilih (${_selectedJournalIds.length})',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12.sp,
                                    color: const Color(0xFF2563EB),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _refreshData,
                        color: const Color(0xFF2563EB),
                        child: filteredPendingJournals.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(height: 60.h),
                                  const AppEmptyWidget(
                                    title: 'Jurnal Tidak Ditemukan',
                                    subtitle: 'Tidak ada jurnal menunggu verifikasi yang cocok dengan pencarian atau filter.',
                                    icon: Icons.search_off_rounded,
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                                itemCount: filteredPendingJournals.length,
                                separatorBuilder: (context, _) => SizedBox(height: 12.h),
                                itemBuilder: (context, index) {
                                  final journal = filteredPendingJournals[index];
                                  final isSelected = _selectedJournalIds.contains(journal.id);

                      final cls = masterProvider.classes.firstWhere(
                        (c) => c.id == journal.classId,
                        orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
                      );

                      final subject = masterProvider.subjects.firstWhere(
                        (s) => s.id == journal.subjectId,
                        orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
                      );

                      final teacher = masterProvider.teachers.firstWhere(
                        (t) => t.id == journal.teacherId,
                        orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
                      );

                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.18) : const Color(0xFFEFF6FF))
                              : (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                            width: isSelected ? 1.8 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24.w,
                                    height: 24.w,
                                    child: Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => _toggleSelectJournal(journal.id),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
                                      activeColor: const Color(0xFF2563EB),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      cls.name,
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (journal.isTeacherAbsence) ...[
                                        Container(
                                          margin: EdgeInsets.only(right: 6.w),
                                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                          decoration: BoxDecoration(
                                            color: journal.isTeacherSick
                                                ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2))
                                                : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7)),
                                            borderRadius: BorderRadius.circular(20.r),
                                            border: Border.all(
                                              color: journal.isTeacherSick ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                journal.isTeacherSick ? Icons.local_hospital_rounded : Icons.assignment_outlined,
                                                size: 11.sp,
                                                color: journal.isTeacherSick ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                                              ),
                                              SizedBox(width: 3.w),
                                              Text(
                                                journal.isTeacherSick ? 'SAKIT' : 'IZIN',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 9.5.sp,
                                                  fontWeight: FontWeight.w800,
                                                  color: journal.isTeacherSick ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF78350F).withValues(alpha: 0.4)
                                              : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(20.r),
                                          border: Border.all(
                                            color: isDark
                                                ? const Color(0xFF92400E)
                                                : const Color(0xFFFDE68A),
                                          ),
                                        ),
                                        child: Text(
                                          'MENUNGGU',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 10.sp,
                                            color: isDark
                                                ? const Color(0xFFFDE68A)
                                                : const Color(0xFFD97706),
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                subject.name,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13.5.sp,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 10.h),

                              // Meta Row
                              Row(
                                children: [
                                  Icon(Icons.person_rounded, size: 15, color: Theme.of(context).colorScheme.outline),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Text(
                                      'Oleh: ${teacher.name}',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 12.sp,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Icon(Icons.calendar_month_rounded, size: 14, color: Theme.of(context).colorScheme.outline),
                                  SizedBox(width: 4.w),
                                  Text(
                                    AppHelper.formatDateShort(journal.date),
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(
                                height: 20,
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),

                              Text(
                                journal.isTeacherAbsence
                                    ? (journal.isTeacherSick ? 'Surat Keterangan Sakit Guru:' : 'Surat Keterangan Izin Guru:')
                                    : 'Materi Diajarkan:',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  color: journal.isTeacherAbsence
                                      ? (journal.isTeacherSick ? const Color(0xFFDC2626) : const Color(0xFFD97706))
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: journal.isTeacherAbsence
                                      ? (journal.isTeacherSick
                                          ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : const Color(0xFFFEF2F2))
                                          : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB)))
                                      : (isDark
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                                          : const Color(0xFFF8FAFC)),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: journal.isTeacherAbsence
                                        ? (journal.isTeacherSick
                                            ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA))
                                            : (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)))
                                        : (isDark
                                            ? const Color(0xFF334155)
                                            : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      journal.material,
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 12.5.sp,
                                        fontWeight: journal.isTeacherAbsence ? FontWeight.w700 : FontWeight.normal,
                                        color: journal.isTeacherAbsence
                                            ? (journal.isTeacherSick ? const Color(0xFFDC2626) : const Color(0xFFB45309))
                                            : Theme.of(context).colorScheme.onSurface,
                                        height: 1.4,
                                      ),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (journal.isTeacherAbsence) ...[
                                      SizedBox(height: 4.h),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.attach_file_rounded,
                                            size: 13.sp,
                                            color: journal.isTeacherSick ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                                          ),
                                          SizedBox(width: 4.w),
                                          Text(
                                            'Lampiran surat tersedia untuk ditinjau',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 11.sp,
                                              fontStyle: FontStyle.italic,
                                              color: journal.isTeacherSick ? const Color(0xFFEF4444) : const Color(0xFFD97706),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Divider(
                                height: 20,
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        context.push('/admin/journal/${journal.id}');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: Size(0, 38.h),
                                        padding: EdgeInsets.symmetric(vertical: 6.h),
                                        side: BorderSide(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                      ),
                                      child: Text(
                                        'Detail',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _handleApprove(journal.id, journal.teacherId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        minimumSize: Size(0, 38.h),
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(vertical: 6.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                      ),
                                      child: Text(
                                        'Setujui',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => _handleReject(journal.id, journal.teacherId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFE11D48),
                                        foregroundColor: Colors.white,
                                        minimumSize: Size(0, 38.h),
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(vertical: 6.h),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                      ),
                                      child: Text(
                                        'Tolak',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
      bottomNavigationBar: _selectedJournalIds.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selectedJournalIds.length} Jurnal Terpilih',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Pilih aksi persetujuan massal',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isBatchProcessing
                          ? null
                          : () => _handleBulkReject(_selectedJournalIds.toList()),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: Text(
                        'Tolak',
                        style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        foregroundColor: const Color(0xFFE11D48),
                        side: const BorderSide(color: Color(0xFFE11D48), width: 1.2),
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    ElevatedButton.icon(
                      onPressed: _isBatchProcessing
                          ? null
                          : () => _handleBulkApprove(_selectedJournalIds.toList()),
                      icon: _isBatchProcessing
                          ? SizedBox(
                              width: 15.w,
                              height: 15.w,
                              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        _isBatchProcessing ? 'Memproses...' : 'Setujui (${_selectedJournalIds.length})',
                        style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
