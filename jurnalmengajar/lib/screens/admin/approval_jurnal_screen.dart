import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
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
    await Provider.of<JournalProvider>(context, listen: false).loadAllJournals();
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
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
      appBar: AppBar(
        title: const Text('Persetujuan Jurnal'),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/approvals'),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0D9488),
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
                    separatorBuilder: (context, index) => SizedBox(height: 16.h),
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
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    cls.name,
                                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'MENUNGGU',
                                    style: TextStyle(fontSize: 10.sp, color: Colors.amber[800], fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              subject.name,
                              style: TextStyle(fontSize: 14.sp, color: Colors.grey[750], fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 8.h),
                            
                            // Meta Row
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 14.w, color: Colors.grey),
                                SizedBox(width: 4.w),
                                Text(
                                  'Oleh: ${teacher.name}',
                                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                ),
                                const Spacer(),
                                Icon(Icons.calendar_today_outlined, size: 12.w, color: Colors.grey),
                                SizedBox(width: 4.w),
                                Text(
                                  AppHelper.formatDateShort(journal.date),
                                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                            const Divider(height: 24),

                            Text(
                              'Materi Diajarkan:',
                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              journal.material,
                              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Divider(height: 24),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      // Reuse the Guru journal details view for simplicity
                                      context.push('/guru/journal/${journal.id}');
                                    },
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: Size(0, 36.h),
                                      side: const BorderSide(color: Color(0xFF0F172A)),
                                      foregroundColor: const Color(0xFF0F172A),
                                      padding: EdgeInsets.symmetric(vertical: 8.h),
                                    ),
                                    child: const Text('Detail'),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _handleApprove(journal.id, journal.teacherId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981), // Emerald Green
                                      minimumSize: Size(0, 36.h),
                                      padding: EdgeInsets.symmetric(vertical: 8.h),
                                    ),
                                    child: const Text('Setujui'),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _handleReject(journal.id, journal.teacherId),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[600],
                                      minimumSize: Size(0, 36.h),
                                      padding: EdgeInsets.symmetric(vertical: 8.h),
                                    ),
                                    child: const Text('Tolak'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
