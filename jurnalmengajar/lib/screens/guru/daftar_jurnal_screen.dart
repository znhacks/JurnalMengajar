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
import '../../core/utils/schedule_grouper.dart';
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

    // Group active schedules up to today with no journal entries
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final groupedSchedules = groupDailySchedules(scheduleProvider.cachedTeacherSchedules);
    final unfilledGroups = groupedSchedules.where((group) {
      if (!group.isActive) return false;
      final sDateOnly = DateTime(group.date.year, group.date.month, group.date.day);
      if (sDateOnly.isAfter(todayOnly)) return false;
      
      // Check if there is any journal that matches any schedule in the group
      return !teacherJournals.any((j) => group.scheduleIds.contains(j.scheduleId));
    }).toList();

    final List<dynamic> allItems = [];
    allItems.addAll(teacherJournals);
    allItems.addAll(unfilledGroups);

    // Sort by date descending (newest first)
    allItems.sort((a, b) {
      final dateA = a is JournalModel ? a.date : (a as GroupedDailySchedule).date;
      final dateB = b is JournalModel ? b.date : (b as GroupedDailySchedule).date;
      final comp = dateB.compareTo(dateA);
      if (comp != 0) return comp;

      final hourA = a is JournalModel ? 0 : (a as GroupedDailySchedule).primarySchedule.teachingHour;
      final hourB = b is JournalModel ? 0 : (b as GroupedDailySchedule).primarySchedule.teachingHour;
      return hourB.compareTo(hourA);
    });

    final isLoading = journalProvider.isLoading || scheduleProvider.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Riwayat Jurnal'),
        backgroundColor: Colors.white,
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

  Widget _buildJournalList(List<dynamic> list, MasterDataProvider master) {
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
          final item = list[index];
          if (item is JournalModel) {
            return _buildJournalCard(item, master);
          } else {
            return _buildUnfilledGroupCard(item as GroupedDailySchedule, master);
          }
        },
      ),
    );
  }

  Widget _buildUnfilledGroupCard(GroupedDailySchedule group, MasterDataProvider master) {
    final schedule = group.primarySchedule;
    final cls = master.classes.firstWhere(
      (c) => c.id == schedule.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == schedule.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    const statusColor = Color(0xFFEA580C); // Warning Orange
    final hoursStr = group.teachingHours.join(', ');

    return InkWell(
      onTap: () => context.push('/guru/journal-form?scheduleId=${schedule.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFED7AA), width: 1.5), // Orange tint border
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Status left bar
              Container(
                width: 4.w,
                decoration: const BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.only(
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
                          // Pill status badge
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Belum Diisi',
                              style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      // Instruction preview
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED), // Light orange bg
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_note, color: statusColor, size: 20),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'Jadwal mengajar jam ke-$hoursStr belum diisi. Ketuk untuk isi sekarang.',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12.sp,
                                  color: const Color(0xFFC2410C),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
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
                            AppHelper.formatDateShort(group.date),
                            style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp, color: AppTheme.outline),
                          ),
                          const Spacer(),
                          Text(
                            'Isi Jurnal',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          const Icon(Icons.arrow_forward,
                              size: 12, color: AppTheme.primaryColor),
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

    return InkWell(
      onTap: () => context.push('/guru/journal/${journal.id}'),
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
              // Status left bar
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
                          // Pill status badge
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
                                  letterSpacing: 0.2),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
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
