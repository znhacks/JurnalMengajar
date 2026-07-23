import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/state_widgets.dart';

class GuruDaftarJurnalScreen extends StatefulWidget {
  const GuruDaftarJurnalScreen({super.key});

  @override
  State<GuruDaftarJurnalScreen> createState() => _GuruDaftarJurnalScreenState();
}

class _GuruDaftarJurnalScreenState extends State<GuruDaftarJurnalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadJournals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadJournals() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
        orElse: () => TeacherModel(
            id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
      );
      if (teacher.id.isNotEmpty) {
        await Future.wait([
          journalProvider.loadTeacherJournals(teacher.id),
          scheduleProvider.loadTeacherSchedules(teacher.id, DateTime.now()),
        ]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    final teacherJournals = journalProvider.teacherJournals;
    final pendingJournals =
        teacherJournals.where((j) => j.status == 'pending').toList();
    final verifiedJournals =
        teacherJournals.where((j) => j.status == 'verified').toList();

    final List<JournalModel> allItems = List.from(teacherJournals);
    allItems.sort((a, b) => b.date.compareTo(a.date));

    final isLoading = journalProvider.isLoading || scheduleProvider.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () {
              final rootScaffold = ctx.findRootAncestorStateOfType<ScaffoldState>();
              if (rootScaffold != null && rootScaffold.hasDrawer) {
                rootScaffold.openDrawer();
              } else {
                Scaffold.maybeOf(ctx)?.openDrawer();
              }
            },
          ),
        ),
        title: const Text('Riwayat Jurnal'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppTheme.outlineVariant,
              dividerHeight: 1,
              tabs: [
                _buildTab('Semua', allItems.length),
                _buildTab('Menunggu', pendingJournals.length),
                _buildTab('Terverifikasi', verifiedJournals.length),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildJournalList(allItems, masterProvider),
                  _buildJournalList(pendingJournals, masterProvider),
                  _buildJournalList(verifiedJournals, masterProvider),
                ],
              ),
      ),
    );
  }

  Tab _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          if (count > 0) ...[
            SizedBox(width: 5.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor),
              ),
            ),
          ],
        ],
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
      color: AppTheme.primaryColor,
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: list.length,
        separatorBuilder: (context, _) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          return _buildJournalCard(list[index], master);
        },
      ),
    );
  }



  Widget _buildJournalCard(JournalModel journal, MasterDataProvider master) {
    final cls = master.classes.firstWhere(
      (c) => c.id == journal.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == journal.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final statusColor = AppHelper.getStatusColor(journal.status);

    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final groupSchedules = scheduleProvider.cachedTeacherSchedules.where((s) {
      return s.date.year == journal.date.year &&
          s.date.month == journal.date.month &&
          s.date.day == journal.date.day &&
          s.classId == journal.classId &&
          s.subjectId == journal.subjectId;
    }).toList();
    final hoursList = groupSchedules.map((s) => s.teachingHour).toList()..sort();
    final hoursStr = hoursList.isNotEmpty
        ? AppHelper.formatTeachingHours(hoursList)
        : '${journal.teachingHour}';

    return InkWell(
      onTap: () => context.push('/guru/journal/${journal.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4.w,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${cls.name} • Jam Ke-$hoursStr',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.onBackground,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppHelper.getStatusLabel(journal.status),
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 9.sp,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${subject.name} — ${journal.material}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.sp,
                          color: AppTheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.outline),
                          SizedBox(width: 4.w),
                          Text(
                            AppHelper.formatDateShort(journal.date),
                            style: GoogleFonts.hankenGrotesk(fontSize: 10.sp, color: AppTheme.outline),
                          ),
                          const Spacer(),
                          const Icon(Icons.people_outline, size: 11, color: AppTheme.outline),
                          SizedBox(width: 4.w),
                          Text(
                            'S:${journal.sickCount} I:${journal.permissionCount} A:${journal.alphaCount}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 10.sp,
                              color: AppTheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
