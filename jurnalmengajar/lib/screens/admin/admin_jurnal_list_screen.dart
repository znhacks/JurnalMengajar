import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/state_widgets.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../widgets/animated_widgets.dart';

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
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelectionMode({String? initialId}) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
      if (_isSelectionMode && initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _toggleSelectItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<JournalModel> journals) {
    setState(() {
      if (_selectedIds.length == journals.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(journals.map((j) => j.id));
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $count Jurnal', style: const TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menghapus $count data jurnal yang dipilih secara permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Massal', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      final idsToDelete = _selectedIds.toList();
      final success = await journalProvider.deleteMultipleJournals(idsToDelete);
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count data jurnal berhasil dihapus.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, journalProvider.errorMessage ?? 'Gagal menghapus jurnal.', isError: true);
      }
    }
  }

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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await Future.wait([
      journalProvider.loadAllJournals(authProvider.activeSchoolId),
      masterProvider.loadAllData(authProvider.activeSchoolId),
      scheduleProvider.loadAllSchedules(authProvider.activeSchoolId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    final validClassIds = masterProvider.classes.map((c) => c.id).toSet();
    final validSubjectIds = masterProvider.subjects.map((s) => s.id).toSet();

    final allJournals = journalProvider.journals.where((j) {
      return validClassIds.contains(j.classId) && validSubjectIds.contains(j.subjectId);
    }).toList();
    final pendingJournals = allJournals.where((j) => j.status == 'pending').toList();
    final verifiedJournals = allJournals.where((j) => j.status == 'verified').toList();

    // Get unfilled schedules
    final activeSchedules = scheduleProvider.schedules.where((s) {
      return s.isActive &&
          validClassIds.contains(s.classId) &&
          validSubjectIds.contains(s.subjectId);
    }).toList();
    final groupedDailySchedules = groupDailySchedules(activeSchedules);
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final unfilledGroups = groupedDailySchedules.where((group) {
      if (!group.date.isBefore(today)) return false;
      final hasJournal = allJournals.any(
        (j) => group.scheduleIds.contains(j.scheduleId),
      );
      return !hasJournal;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final isLoading = journalProvider.isLoading || masterProvider.isLoading || scheduleProvider.isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              title: Text('${_selectedIds.length} Terpilih', style: const TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedIds.length == allJournals.length ? Icons.deselect : Icons.select_all,
                    color: Colors.white,
                  ),
                  tooltip: _selectedIds.length == allJournals.length ? 'Batal Pilih Semua' : 'Pilih Semua',
                  onPressed: () => _selectAll(allJournals),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus Massal',
                  onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                ),
              ],
            )
          : AppBar(
              title: const Text('Jurnal Mengajar'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Pilih Massal',
                  onPressed: allJournals.isEmpty ? null : () => _toggleSelectionMode(),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(48.h),
                child: Container(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: const Color(0xFF2563EB),
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                    dividerHeight: 1,
                    tabs: [
                      _buildTab('Semua', allJournals.length,
                          badgeColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB)),
                      _buildTab('Belum Diisi', unfilledGroups.length,
                          badgeColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFF87171)
                              : const Color(0xFFBA1A1A)),
                      _buildTab('Menunggu', pendingJournals.length,
                          badgeColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706)),
                      _buildTab('Terverifikasi', verifiedJournals.length,
                          badgeColor: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB)),
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
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari guru, kelas, atau mapel...',
                        hintStyle: GoogleFonts.hankenGrotesk(
                          fontSize: 13.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 20.r,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  size: 18.r,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                            vertical: 8.h, horizontal: 16.w),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB), width: 1.5),
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
                            badgeColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB)),
                        _buildUnfilledList(unfilledGroups, masterProvider),
                        _buildJournalList(pendingJournals, masterProvider,
                            badgeColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFFBBF24)
                                : const Color(0xFFD97706)),
                        _buildJournalList(verifiedJournals, masterProvider,
                            badgeColor: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB)),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Tab _buildTab(String label, int count, {Color? badgeColor}) {
    final color = badgeColor ?? const Color(0xFF2563EB);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count > 0) ...[
            SizedBox(width: 5.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: isDark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
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
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
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
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      backgroundImage: teacher.photoUrl != null &&
                              teacher.photoUrl!.startsWith('http')
                          ? NetworkImage(teacher.photoUrl!)
                          : null,
                      child: teacher.photoUrl == null
                          ? Icon(Icons.person, size: 16.r, color: isDark ? const Color(0xFF94A3B8) : Colors.grey[450])
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
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            teacher.position.isNotEmpty ? teacher.position : 'Guru',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    color: isDark ? activeColor.withValues(alpha: 0.25) : activeColor.withValues(alpha: 0.1),
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
                    color: isDark
                        ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                        : const Color(0xFFF8FAFC),
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
    final isSelected = _selectedIds.contains(journal.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FadeSlideIn(
      delay: const Duration(milliseconds: 60),
      child: ScaleTap(
        onTap: _isSelectionMode
            ? () => _toggleSelectItem(journal.id)
            : () => context.push('/admin/journal/${journal.id}'),
        onLongPress: () {
          if (!_isSelectionMode) {
            _toggleSelectionMode(initialId: journal.id);
          } else {
            _toggleSelectItem(journal.id);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                    : const Color(0xFFEFF6FF))
                : (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
            children: [
              if (_isSelectionMode) ...[
                Padding(
                  padding: EdgeInsets.only(left: 8.w),
                  child: Checkbox(
                    value: isSelected,
                    activeColor: const Color(0xFF2563EB),
                    onChanged: (_) => _toggleSelectItem(journal.id),
                  ),
                ),
              ],
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
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  subject.name,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 13.sp,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              color: isDark
                                  ? statusColor.withValues(alpha: 0.25)
                                  : statusColor.withValues(alpha: 0.1),
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
                              size: 13.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          SizedBox(width: 4.w),
                          Expanded(
                            child: Text(
                              teacher.name,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12.sp,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          color: isDark
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          journal.material,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12.sp,
                            color: Theme.of(context).colorScheme.onSurface,
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
                          Icon(Icons.calendar_today_outlined,
                              size: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          SizedBox(width: 4.w),
                          Text(
                            AppHelper.formatDateShort(journal.date),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.people_outline,
                              size: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          SizedBox(width: 4.w),
                          Text(
                            'S:${journal.sickCount} I:${journal.permissionCount} A:${journal.alphaCount}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Row(
            children: [
              Text(
                'Terdeteksi ${filteredList.length} jadwal yang belum terisi jurnalnya',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF87171)
                      : const Color(0xFFBA1A1A),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sortedTeachers.isEmpty
              ? (_searchQuery.isNotEmpty
                  ? const AppEmptyWidget(
                      title: 'Tidak Ditemukan',
                      subtitle: 'Tidak ada jadwal belum diisi yang cocok dengan pencarian.',
                    )
                  : const AppEmptyWidget(
                      title: 'Semua Jurnal Terisi',
                      subtitle: 'Tidak ada jadwal yang belum diisi jurnalnya.',
                    ))
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: const Color(0xFF2563EB),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    itemCount: sortedTeachers.length,
                    itemBuilder: (context, teacherIndex) {
                      final teacher = sortedTeachers[teacherIndex];
                      final teacherItems = groups[teacher]!;
                      final isExpanded = _expandedTeacherIds.contains(teacher.id);
                      final isDark = Theme.of(context).brightness == Brightness.dark;

                      return Card(
                        margin: EdgeInsets.only(bottom: 12.h),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
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
                                  backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                  backgroundImage: teacher.photoUrl != null &&
                                          teacher.photoUrl!.startsWith('http')
                                      ? NetworkImage(teacher.photoUrl!)
                                      : null,
                                  child: teacher.photoUrl == null
                                      ? Icon(Icons.person, size: 16.r, color: isDark ? const Color(0xFF94A3B8) : Colors.grey[450])
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
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        teacher.position.isNotEmpty ? teacher.position : 'Guru',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 11.sp,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                color: isDark
                                    ? const Color(0xFFF87171).withValues(alpha: 0.25)
                                    : const Color(0xFFBA1A1A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${teacherItems.length}',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  color: isDark ? const Color(0xFFF87171) : const Color(0xFFBA1A1A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            children: [
                              Container(
                                color: isDark
                                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                    : const Color(0xFFF8FAFC),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = isDark ? const Color(0xFFF87171) : const Color(0xFFBA1A1A);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
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
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                subject.name,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13.sp,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            color: isDark
                                ? statusColor.withValues(alpha: 0.25)
                                : statusColor.withValues(alpha: 0.1),
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
                            size: 13.sp,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            teacher.name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        color: isDark
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Jurnal mengajar belum diisi oleh guru yang bersangkutan.',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          'Jam ke-${AppHelper.formatTeachingHours(group.teachingHours)}',
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
