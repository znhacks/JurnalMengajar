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
import '../../core/utils/schedule_grouper.dart';

class AdminJurnalListScreen extends StatefulWidget {
  /// If non-null, jump directly to a specific tab index (0=Semua, 1=Belum Diisi, 2=Menunggu, 3=Terverifikasi)
  final int initialTabIndex;
  const AdminJurnalListScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AdminJurnalListScreen> createState() => _AdminJurnalListScreenState();
}

class _AdminJurnalListScreenState extends State<AdminJurnalListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _expandedTeacherIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
    final scheduleProvider = context.watch<ScheduleProvider>();

    final allJournals = journalProvider.journals;
    final pendingJournals = allJournals.where((j) => j.status == 'pending').toList();
    final verifiedJournals = allJournals.where((j) => j.status == 'verified').toList();

    // Get unfilled schedules
    final activeSchedules = scheduleProvider.schedules.where((s) => s.isActive).toList();
    final groupedDailySchedules = groupDailySchedules(activeSchedules);
    final unfilledGroups = groupedDailySchedules.where((group) {
      final hasJournal = allJournals.any(
        (j) => group.scheduleIds.contains(j.scheduleId),
      );
      return !hasJournal;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final isLoading = journalProvider.isLoading || masterProvider.isLoading || scheduleProvider.isLoading;

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
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppTheme.outlineVariant,
              dividerHeight: 1,
              tabs: [
                _buildTab('Semua', allJournals.length),
                _buildTab('Belum Diisi', unfilledGroups.length,
                    badgeColor: const Color(0xFFBA1A1A)),
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
            : Column(
                children: [
                  // ── Universal Search Bar ──────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          // auto-expand all teachers when searching
                          if (val.isNotEmpty) {
                            _expandedTeacherIds.addAll(
                              masterProvider.teachers.map((t) => t.id),
                            );
                          }
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari guru, kelas, atau mapel...',
                        hintStyle: GoogleFonts.hankenGrotesk(
                            fontSize: 13.sp, color: Colors.grey[450]),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey[400], size: 20.r),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    size: 18.r, color: Colors.grey[400]),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 8.h, horizontal: 16.w),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  // ── Tab Content ──────────────────────────────────────
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildJournalList(allJournals, masterProvider,
                            badgeColor: AppTheme.primaryColor),
                        _buildUnfilledList(unfilledGroups, masterProvider),
                        _buildJournalList(pendingJournals, masterProvider,
                            badgeColor: const Color(0xFF825100)),
                        _buildJournalList(verifiedJournals, masterProvider,
                            badgeColor: AppTheme.primaryColor),
                      ],
                    ),
                  ),
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

  Widget _buildJournalList(
    List<JournalModel> list,
    MasterDataProvider master, {
    Color? badgeColor,
  }) {
    // Apply universal search filter
    final filtered = _searchQuery.isEmpty
        ? list
        : list.where((j) {
            final query = _searchQuery.toLowerCase();
            final teacher = master.teachers.firstWhere(
              (t) => t.id == j.teacherId,
              orElse: () => TeacherModel(
                  id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
            );
            final cls = master.classes.firstWhere(
              (c) => c.id == j.classId,
              orElse: () => ClassModel(id: '', name: '', periodId: '', studentCount: 0),
            );
            final subject = master.subjects.firstWhere(
              (s) => s.id == j.subjectId,
              orElse: () => SubjectModel(id: '', name: '', isActive: false),
            );
            return teacher.name.toLowerCase().contains(query) ||
                cls.name.toLowerCase().contains(query) ||
                subject.name.toLowerCase().contains(query) ||
                j.material.toLowerCase().contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return AppEmptyWidget(
        title: _searchQuery.isNotEmpty ? 'Tidak Ditemukan' : 'Jurnal Kosong',
        subtitle: _searchQuery.isNotEmpty
            ? 'Tidak ada hasil pencarian yang cocok.'
            : 'Tidak ada data jurnal dalam kategori ini.',
      );
    }

    // Group by teacher
    final Map<TeacherModel, List<JournalModel>> groups = {};
    for (final item in filtered) {
      final teacher = master.teachers.firstWhere(
        (t) => t.id == item.teacherId,
        orElse: () => TeacherModel(
            id: item.teacherId,
            name: 'Guru--',
            position: '',
            address: '',
            phoneNumber: '',
            email: ''),
      );
      groups.putIfAbsent(teacher, () => []).add(item);
    }

    // Sort teachers alphabetically by name
    final sortedTeachers = groups.keys.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final activeColor = badgeColor ?? AppTheme.primaryColor;

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        itemCount: sortedTeachers.length,
        itemBuilder: (context, teacherIndex) {
          final teacher = sortedTeachers[teacherIndex];
          final teacherItems = groups[teacher]!
            ..sort((a, b) => b.date.compareTo(a.date));
          final isExpanded = _expandedTeacherIds.contains(teacher.id);

          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppTheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey<String>('journal_teacher_${teacher.id}'),
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    if (expanded) {
                      _expandedTeacherIds.add(teacher.id);
                    } else {
                      _expandedTeacherIds.remove(teacher.id);
                    }
                  });
                },
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 16.r,
                      backgroundColor: const Color(0xFFF1F5F9),
                      backgroundImage: teacher.photoUrl != null &&
                              teacher.photoUrl!.startsWith('http')
                          ? NetworkImage(teacher.photoUrl!)
                          : null,
                      child: teacher.photoUrl == null
                          ? Icon(Icons.person, size: 16.r, color: Colors.grey[450])
                          : null,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacher.name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onBackground,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            teacher.position.isNotEmpty ? teacher.position : 'Guru',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              color: AppTheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${teacherItems.length}',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 10.sp,
                      color: activeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                children: [
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teacherItems.length,
                      separatorBuilder: (context, _) => SizedBox(height: 10.h),
                      itemBuilder: (context, itemIndex) {
                        return _buildJournalCard(teacherItems[itemIndex], master);
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
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
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
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
                      SizedBox(height: 4.h),
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
                      SizedBox(height: 5.h),
                      // Material preview
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
                      SizedBox(height: 6.h),
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

  Widget _buildUnfilledList(List<GroupedDailySchedule> list, MasterDataProvider master) {
    // 1. Filter list by universal search query
    final filteredList = list.where((group) {
      if (_searchQuery.isEmpty) return true;
      final teacher = master.teachers.firstWhere(
        (t) => t.id == group.teacherId,
        orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
      );
      final cls = master.classes.firstWhere(
        (c) => c.id == group.classId,
        orElse: () => ClassModel(id: '', name: '', periodId: '', studentCount: 0),
      );
      final subject = master.subjects.firstWhere(
        (s) => s.id == group.subjectId,
        orElse: () => SubjectModel(id: '', name: '', isActive: false),
      );
      
      final query = _searchQuery.toLowerCase();
      return teacher.name.toLowerCase().contains(query) ||
             cls.name.toLowerCase().contains(query) ||
             subject.name.toLowerCase().contains(query);
    }).toList();

    // 2. Group by teacher
    final Map<TeacherModel, List<GroupedDailySchedule>> groups = {};
    for (final item in filteredList) {
      final teacher = master.teachers.firstWhere(
        (t) => t.id == item.teacherId,
        orElse: () => TeacherModel(
            id: item.teacherId,
            name: 'Guru--',
            position: '',
            address: '',
            phoneNumber: '',
            email: ''),
      );
      groups.putIfAbsent(teacher, () => []).add(item);
    }

    // Sort teachers alphabetically by name
    final sortedTeachers = groups.keys.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      children: [
        
        Expanded(
          child: filteredList.isEmpty
              ? (_searchQuery.isNotEmpty
                  ? const AppEmptyWidget(
                      title: 'Tidak Ditemukan',
                      subtitle: 'Tidak ada hasil pencarian yang cocok.',
                    )
                  : const AppEmptyWidget(
                      title: 'Semua Jurnal Terisi',
                      subtitle: 'Tidak ada jadwal yang belum diisi jurnalnya.',
                    ))
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    itemCount: sortedTeachers.length,
                    itemBuilder: (context, teacherIndex) {
                      final teacher = sortedTeachers[teacherIndex];
                      final teacherItems = groups[teacher]!;
                      final isExpanded = _expandedTeacherIds.contains(teacher.id);

                      return Card(
                        margin: EdgeInsets.only(bottom: 12.h),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppTheme.outlineVariant),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: ValueKey<String>('teacher_${teacher.id}'),
                            initiallyExpanded: isExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                if (expanded) {
                                  _expandedTeacherIds.add(teacher.id);
                                } else {
                                  _expandedTeacherIds.remove(teacher.id);
                                }
                              });
                            },
                            title: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16.r,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  backgroundImage: teacher.photoUrl != null &&
                                          teacher.photoUrl!.startsWith('http')
                                      ? NetworkImage(teacher.photoUrl!)
                                      : null,
                                  child: teacher.photoUrl == null
                                      ? Icon(Icons.person, size: 16.r, color: Colors.grey[450])
                                      : null,
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        teacher.name,
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.onBackground,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        teacher.position.isNotEmpty ? teacher.position : 'Guru',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 11.sp,
                                          color: AppTheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBA1A1A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${teacherItems.length}',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  color: const Color(0xFFBA1A1A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            children: [
                              Container(
                                color: const Color(0xFFF8FAFC),
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: teacherItems.length,
                                  separatorBuilder: (context, _) => SizedBox(height: 10.h),
                                  itemBuilder: (context, itemIndex) {
                                    return _buildUnfilledScheduleCard(teacherItems[itemIndex], master);
                                  },
                                ),
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
    );
  }

  Widget _buildUnfilledScheduleCard(GroupedDailySchedule group, MasterDataProvider master) {
    final cls = master.classes.firstWhere(
      (c) => c.id == group.classId,
      orElse: () =>
          ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == group.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );
    final teacher = master.teachers.firstWhere(
      (t) => t.id == group.teacherId,
      orElse: () => TeacherModel(
          id: '',
          name: 'Guru--',
          position: '',
          address: '',
          phoneNumber: '',
          email: ''),
    );

    final statusColor = const Color(0xFFBA1A1A);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
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
                            'Belum Diisi',
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
                    SizedBox(height: 4.h),
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
                    SizedBox(height: 5.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Jurnal mengajar belum diisi oleh guru yang bersangkutan.',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.sp,
                          color: AppTheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
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
                        Icon(Icons.access_time,
                            size: 12, color: AppTheme.outline),
                        SizedBox(width: 4.w),
                        Text(
                          'Jam ke-${group.teachingHours.join(', ')}',
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
    );
  }
}
