import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/state_widgets.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';

class AdminJurnalListScreen extends StatefulWidget {
  /// If non-null, jump directly to a specific tab index (0=Semua, 1=Belum Disetujui, 2=Terverifikasi)
  final int initialTabIndex;
  const AdminJurnalListScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AdminJurnalListScreen> createState() => _AdminJurnalListScreenState();
}

class _AdminJurnalListScreenState extends State<AdminJurnalListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

    await Future.wait([
      journalProvider.loadAllJournals(),
      masterProvider.loadAllData(),
      scheduleProvider.loadAllSchedules(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();

    final allJournals = journalProvider.journals;
    final pendingJournals = allJournals.where((j) => j.status == 'pending').toList();
    final verifiedJournals = allJournals.where((j) => j.status == 'verified').toList();

    final isLoading = journalProvider.isLoading || masterProvider.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Jurnal Mengajar'),
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
                _buildTab('Semua', allJournals.length),
                _buildTab('Menunggu', pendingJournals.length,
                    badgeColor: const Color(0xFF825100)),
                _buildTab('Terverifikasi', verifiedJournals.length,
                    badgeColor: AppTheme.primaryColor),
              ],
            ),
          ),
        ),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/journals'),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildJournalList(allJournals, masterProvider),
                  _buildJournalList(pendingJournals, masterProvider),
                  _buildJournalList(verifiedJournals, masterProvider),
                ],
              ),
      ),
    );
  }

  Tab _buildTab(String label, int count, {Color? badgeColor}) {
    final color = badgeColor ?? AppTheme.primaryColor;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (count > 0) ...[
            SizedBox(width: 5.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
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

    final sorted = List<JournalModel>.from(list)
      ..sort((a, b) => b.date.compareTo(a.date));

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryColor,
      child: ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: sorted.length,
        separatorBuilder: (context, _) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          return _buildJournalCard(sorted[index], master);
        },
      ),
    );
  }

  Widget _buildJournalCard(JournalModel journal, MasterDataProvider master) {
    final cls = master.classes.firstWhere(
      (c) => c.id == journal.classId,
      orElse: () =>
          ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == journal.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );
    final teacher = master.teachers.firstWhere(
      (t) => t.id == journal.teacherId,
      orElse: () => TeacherModel(
          id: '',
          name: 'Guru--',
          position: '',
          address: '',
          phoneNumber: '',
          email: ''),
    );

    final statusColor = AppHelper.getStatusColor(journal.status);

    return InkWell(
      onTap: () => context.push('/admin/journal/${journal.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.outlineVariant),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Status left accent bar
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
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cls.name,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.onBackground,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  subject.name,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 13.sp,
                                    color: AppTheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppHelper.getStatusLabel(journal.status),
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 10.sp,
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      // Teacher name
                      Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 13.sp, color: AppTheme.outline),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              teacher.name,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12.sp,
                                color: AppTheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      // Material preview
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          journal.material,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.sp,
                            color: AppTheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      // Footer row
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: AppTheme.outline),
                          SizedBox(width: 4.w),
                          Text(
                            AppHelper.formatDateShort(journal.date),
                            style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp, color: AppTheme.outline),
                          ),
                          const Spacer(),
                          const Icon(Icons.people_outline,
                              size: 12, color: AppTheme.outline),
                          SizedBox(width: 4.w),
                          Text(
                            'S:${journal.sickCount} I:${journal.permissionCount} A:${journal.alphaCount}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
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
