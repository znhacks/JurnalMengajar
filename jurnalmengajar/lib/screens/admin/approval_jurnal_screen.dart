import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/state_widgets.dart';
import '../../core/utils/helper.dart';

class ApprovalJurnalScreen extends StatefulWidget {
  const ApprovalJurnalScreen({super.key});

  @override
  State<ApprovalJurnalScreen> createState() => _ApprovalJurnalScreenState();
}

class _ApprovalJurnalScreenState extends State<ApprovalJurnalScreen> {
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

    await Future.wait([
      journalProvider.loadAllJournals(),
      masterProvider.loadAllData(),
    ]);
  }

  Future<void> _handleApprove(String journalId, String teacherId) async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final success = await journalProvider.verifyJournal(journalId, 'verified', teacherId: teacherId);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Jurnal berhasil diverifikasi (Disetujui)');
    } else if (mounted) {
      AppHelper.showSnackBar(context, journalProvider.errorMessage ?? 'Gagal memverifikasi jurnal.', isError: true);
    }
  }

  Future<void> _handleReject(String journalId, String teacherId) async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final success = await journalProvider.verifyJournal(journalId, 'rejected', teacherId: teacherId);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Jurnal berhasil ditolak');
    } else if (mounted) {
      AppHelper.showSnackBar(context, journalProvider.errorMessage ?? 'Gagal memverifikasi jurnal.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();

    final pendingJournals = journalProvider.journals.where((j) => j.status == 'pending').toList();
    final isLoading = journalProvider.isLoading || masterProvider.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          'Persetujuan Jurnal',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/journals'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF2563EB),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : pendingJournals.isEmpty
                ? const AppEmptyWidget(
                    title: 'Semua Jurnal Bersih',
                    subtitle: 'Tidak ada jurnal mengajar yang menunggu verifikasi saat ini.',
                    icon: Icons.done_all_rounded,
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    itemCount: pendingJournals.length,
                    separatorBuilder: (context, _) => SizedBox(height: 14.h),
                    itemBuilder: (context, index) {
                      final journal = pendingJournals[index];

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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
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
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      cls.name,
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(20.r),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Text(
                                      'MENUNGGU',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 10.sp,
                                        color: const Color(0xFFD97706),
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                subject.name,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13.5.sp,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 10.h),

                              // Meta Row
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 15, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Text(
                                      'Oleh: ${teacher.name}',
                                      style: GoogleFonts.hankenGrotesk(
                                        fontSize: 12.sp,
                                        color: const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  const Icon(Icons.calendar_month_rounded, size: 14, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 4.w),
                                  Text(
                                    AppHelper.formatDateShort(journal.date),
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      color: const Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: Color(0xFFE2E8F0)),

                              Text(
                                'Materi Diajarkan:',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  journal.material,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 12.5.sp,
                                    color: const Color(0xFF334155),
                                    height: 1.4,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Divider(height: 20, color: Color(0xFFE2E8F0)),

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
                                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                      ),
                                      child: Text(
                                        'Detail',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
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
    );
  }
}
