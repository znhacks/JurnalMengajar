import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../core/utils/helper.dart';
import '../../widgets/state_widgets.dart';

class GuruDaftarJurnalScreen extends StatefulWidget {
  const GuruDaftarJurnalScreen({super.key});

  @override
  State<GuruDaftarJurnalScreen> createState() => _GuruDaftarJurnalScreenState();
}

class _GuruDaftarJurnalScreenState extends State<GuruDaftarJurnalScreen> {
  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  Future<void> _loadJournals() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    
    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
        orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
      );

      if (teacher.id.isNotEmpty) {
        await journalProvider.loadTeacherJournals(teacher.id);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();

    final teacherJournals = journalProvider.teacherJournals;

    final pendingJournals = teacherJournals.where((j) => j.status == 'pending').toList();
    final verifiedJournals = teacherJournals.where((j) => j.status == 'verified').toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Riwayat Jurnal'),
          bottom: const TabBar(
            indicatorColor: Color(0xFF0D9488),
            labelColor: Color(0xFF0D9488),
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Belum Verifikasi'),
              Tab(text: 'Terverifikasi'),
            ],
          ),
        ),
        body: SafeArea(
          child: journalProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _buildJournalList(teacherJournals, masterProvider),
                    _buildJournalList(pendingJournals, masterProvider),
                    _buildJournalList(verifiedJournals, masterProvider),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildJournalList(List<JournalModel> list, MasterDataProvider master) {
    if (list.isEmpty) {
      return const AppEmptyWidget(
        title: 'Jurnal Kosong',
        subtitle: 'Tidak ada data jurnal dalam kategori ini.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadJournals,
      color: const Color(0xFF0D9488),
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: list.length,
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final journal = list[index];

          final cls = master.classes.firstWhere(
            (c) => c.id == journal.classId,
            orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
          );

          final subject = master.subjects.firstWhere(
            (s) => s.id == journal.subjectId,
            orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
          );

          final teacher = master.teachers.firstWhere(
            (t) => t.id == journal.teacherId,
            orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
          );

          return InkWell(
            onTap: () => context.push('/guru/journal/${journal.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppHelper.getStatusColor(journal.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppHelper.getStatusLabel(journal.status),
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppHelper.getStatusColor(journal.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    subject.name,
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700], fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Pengajar: ${teacher.name}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppHelper.formatDateShort(journal.date),
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
                      ),
                      Row(
                        children: [
                          Icon(Icons.people_outline, size: 14.w, color: Colors.grey),
                          SizedBox(width: 4.w),
                          Text(
                            'S:${journal.sickCount} I:${journal.permissionCount} A:${journal.alphaCount}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
