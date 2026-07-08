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
import '../../core/theme/app_theme.dart';

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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Persetujuan Jurnal'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/approvals'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryColor,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : pendingJournals.isEmpty
                ? const AppEmptyWidget(
                    title: 'Semua Jurnal Bersih',
                    subtitle: 'Tidak ada jurnal mengajar yang menunggu verifikasi saat ini.',
                    icon: Icons.done_all_rounded,
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(16.w),
                    itemCount: pendingJournals.length,
                    separatorBuilder: (context, _) => SizedBox(height: 16.h),
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

                      final statusColor = const Color(0xFF825100); // Amber pending

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.outlineVariant),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              // Left border accent
                              Container(
                                width: 4.w,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                              Expanded(
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
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.onBackground),
                                            ),
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'MENUNGGU',
                                              style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 10.sp,
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 0.2),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        subject.name,
                                        style: GoogleFonts.hankenGrotesk(
                                            fontSize: 14.sp,
                                            color: AppTheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      SizedBox(height: 10.h),

                                      // Meta Row
                                      Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 14, color: AppTheme.outline),
                                          SizedBox(width: 4.w),
                                          Expanded(
                                            child: Text(
                                              'Oleh: ${teacher.name}',
                                              style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 12.sp, color: AppTheme.outline, fontWeight: FontWeight.w500),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(width: 16.w),
                                          const Icon(Icons.calendar_today_outlined, size: 12, color: AppTheme.outline),
                                          SizedBox(width: 4.w),
                                          Text(
                                            AppHelper.formatDateShort(journal.date),
                                            style: GoogleFonts.hankenGrotesk(
                                                fontSize: 12.sp, color: AppTheme.outline, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),

                                      Text(
                                        'Materi Diajarkan:',
                                        style: GoogleFonts.hankenGrotesk(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.onBackground),
                                      ),
                                      SizedBox(height: 6.h),
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(10.w),
                                        decoration: BoxDecoration(
                                          color: AppTheme.surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          journal.material,
                                          style: GoogleFonts.hankenGrotesk(
                                              fontSize: 13.sp, color: AppTheme.onSurfaceVariant, height: 1.4),
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Divider(height: 24),

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
                                                side: const BorderSide(color: AppTheme.outlineVariant),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                'Detail',
                                                style: GoogleFonts.hankenGrotesk(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.onBackground),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _handleApprove(journal.id, journal.teacherId),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF00685F),
                                                minimumSize: Size(0, 38.h),
                                                padding: EdgeInsets.symmetric(vertical: 6.h),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                'Setujui',
                                                style: GoogleFonts.hankenGrotesk(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _handleReject(journal.id, journal.teacherId),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFFBA1A1A),
                                                minimumSize: Size(0, 38.h),
                                                padding: EdgeInsets.symmetric(vertical: 6.h),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text(
                                                'Tolak',
                                                style: GoogleFonts.hankenGrotesk(
                                                    fontSize: 13.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
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
