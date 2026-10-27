import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/app_scaffold.dart';

class GuruDaftarJurnalScreen extends StatefulWidget {
  const GuruDaftarJurnalScreen({super.key});

  @override
  State<GuruDaftarJurnalScreen> createState() => _GuruDaftarJurnalScreenState();
}

class _GuruDaftarJurnalScreenState extends State<GuruDaftarJurnalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _lastLoadedSchoolId;
  String? _lastLoadedUserId;
  JournalTimeScope _timeScope = JournalTimeScope.month;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentSchoolId = authProvider.activeSchoolId;
      if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
        _lastLoadedSchoolId = currentSchoolId;
        _lastLoadedUserId = authProvider.currentUser?.id;
        _loadJournals();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final currentSchoolId = authProvider.activeSchoolId;
    final currentUserId = authProvider.currentUser?.id;

    final hasSchoolChanged = _lastLoadedSchoolId != currentSchoolId;
    final hasUserChanged = _lastLoadedUserId != currentUserId;

    if (hasSchoolChanged || hasUserChanged) {
      _lastLoadedSchoolId = currentSchoolId;
      _lastLoadedUserId = currentUserId;
      if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadJournals();
          }
        });
      }
    }
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
    final schoolId = authProvider.activeSchoolId;
    if (currentUser == null || schoolId == null || schoolId.isEmpty) return;

    journalProvider.setSchoolId(schoolId);
    scheduleProvider.setSchoolId(schoolId);

    final teacherId = currentUser.id;
    await Future.wait([
      masterProvider.loadAllData(schoolId),
      journalProvider.loadTeacherJournals(teacherId),
      scheduleProvider.loadTeacherSchedules(teacherId, DateTime.now()),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(authProvider.activeSchoolId) ??
        authProvider.activeSchoolId?.trim();
    final allTeacherJournals = journalProvider.teacherJournals.where((j) {
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final jSchoolId = AppHelper.parseSingleCleanSchoolId(j.schoolId) ?? j.schoolId?.trim();
        if (jSchoolId != null && jSchoolId.isNotEmpty && jSchoolId != cleanActiveSchoolId) {
          return false;
        }
      }
      return true;
    }).toList();

    // Saring berdasarkan cakupan waktu (Bulan, Minggu Ini, Semua)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentWeekMonday = today.subtract(Duration(days: today.weekday - 1));
    final currentWeekSunday = currentWeekMonday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    final List<JournalModel> scopedJournals;
    switch (_timeScope) {
      case JournalTimeScope.month:
        scopedJournals = allTeacherJournals.where((j) {
          return j.date.year == _selectedMonth.year && j.date.month == _selectedMonth.month;
        }).toList();
        break;
      case JournalTimeScope.week:
        scopedJournals = allTeacherJournals.where((j) {
          final d = DateTime(j.date.year, j.date.month, j.date.day);
          return !d.isBefore(currentWeekMonday) && !d.isAfter(currentWeekSunday);
        }).toList();
        break;
      case JournalTimeScope.all:
        scopedJournals = allTeacherJournals;
        break;
    }

    final pendingJournals =
        scopedJournals.where((j) => j.status == 'pending').toList();
    final verifiedJournals =
        scopedJournals.where((j) => j.status == 'verified' || j.status == 'approved').toList();

    final List<JournalModel> allItems = List.from(scopedJournals);
    allItems.sort((a, b) => b.date.compareTo(a.date));

    final hasData = allTeacherJournals.isNotEmpty;
    final isInitialLoading = (journalProvider.isLoading || scheduleProvider.isLoading) && !hasData;

    final emptySubtitle = _getEmptySubtitle();

    return AppScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: AppMenuButton(
          child: Builder(
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
        ),
        title: const Text('Riwayat Jurnal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Download / Cetak Jurnal',
            onPressed: () => context.push('/guru/download-jurnal'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48.h),
          child: Container(
            color: Theme.of(context).appBarTheme.backgroundColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: AppTheme.outlineVariant,
              dividerHeight: 1,
              tabs: [
                _buildTab('Semua', allItems.length),
                _buildTab('Pending', pendingJournals.length),
                _buildTab('Diterima', verifiedJournals.length),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: isInitialLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTimeFilterBar(context),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildJournalList(allItems, masterProvider, emptySubtitle: emptySubtitle),
                        _buildJournalList(pendingJournals, masterProvider, emptySubtitle: emptySubtitle),
                        _buildJournalList(verifiedJournals, masterProvider, emptySubtitle: emptySubtitle),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _getEmptySubtitle() {
    switch (_timeScope) {
      case JournalTimeScope.month:
        final monthStr = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);
        return 'Tidak ada riwayat jurnal pada bulan $monthStr.';
      case JournalTimeScope.week:
        return 'Tidak ada riwayat jurnal pada minggu ini.';
      case JournalTimeScope.all:
        return 'Belum ada riwayat jurnal yang tersimpan.';
    }
  }

  Widget _buildTimeFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final monthTitle = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);

    return Container(
      color: theme.colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildScopeChip('Bulan', JournalTimeScope.month, Icons.calendar_month_rounded),
              SizedBox(width: 8.w),
              _buildScopeChip('Minggu Ini', JournalTimeScope.week, Icons.date_range_rounded),
              SizedBox(width: 8.w),
              _buildScopeChip('Semua', JournalTimeScope.all, Icons.all_inclusive_rounded),
            ],
          ),
          if (_timeScope == JournalTimeScope.month) ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Bulan Sebelumnya',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(
                          _selectedMonth.year,
                          _selectedMonth.month - 1,
                          1,
                        );
                      });
                    },
                  ),
                  InkWell(
                    onTap: _showMonthPickerModal,
                    borderRadius: BorderRadius.circular(6.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            monthTitle,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 18.sp,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCurrentMonth)
                        IconButton(
                          icon: const Icon(Icons.today_rounded, size: 18),
                          tooltip: 'Kembali ke Bulan Ini',
                          visualDensity: VisualDensity.compact,
                          color: const Color(0xFF2563EB),
                          onPressed: () {
                            setState(() {
                              _selectedMonth = DateTime(now.year, now.month, 1);
                            });
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Bulan Berikutnya',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                              1,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeChip(String label, JournalTimeScope scope, IconData icon) {
    final isSelected = _timeScope == scope;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        setState(() {
          _timeScope = scope;
        });
      },
      borderRadius: BorderRadius.circular(20.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13.sp,
              color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.5.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPickerModal() {
    int pickerYear = _selectedMonth.year;
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final months = [
              'Januari', 'Februari', 'Maret', 'April',
              'Mei', 'Juni', 'Juli', 'Agustus',
              'September', 'Oktober', 'November', 'Desember'
            ];
            return Padding(
              padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setModalState(() => pickerYear--);
                        },
                      ),
                      Text(
                        '$pickerYear',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setModalState(() => pickerYear++);
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, i) {
                      final isSelected = pickerYear == _selectedMonth.year && (i + 1) == _selectedMonth.month;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedMonth = DateTime(pickerYear, i + 1, 1);
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(8.r),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            months[i],
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
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

  Widget _buildJournalList(
    List<JournalModel> list,
    MasterDataProvider master, {
    String? emptySubtitle,
  }) {
    return _InfiniteJournalListView(
      allJournals: list,
      masterProvider: master,
      emptySubtitle: emptySubtitle,
      onRefresh: _loadJournals,
      itemBuilder: (journal, m) => _buildJournalCard(journal, m),
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

    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;
    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;
    final outlineColor = theme.colorScheme.outline;

    return InkWell(
      onTap: () => context.push('/guru/journal/${journal.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
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
                                color: textColor,
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
                        '${subject.name}: ${journal.material}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.sp,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: outlineColor),
                          SizedBox(width: 4.w),
                          Text(
                            AppHelper.formatDateShort(journal.date),
                            style: GoogleFonts.hankenGrotesk(fontSize: 10.sp, color: outlineColor),
                          ),
                          const Spacer(),
                          Icon(Icons.people_outline, size: 11, color: outlineColor),
                          SizedBox(width: 4.w),
                          Text(
                            'S:${journal.sickCount} I:${journal.permissionCount} A:${journal.alphaCount}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 10.sp,
                              color: secondaryTextColor,
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

class _InfiniteJournalListView extends StatefulWidget {
  final List<JournalModel> allJournals;
  final MasterDataProvider masterProvider;
  final String? emptySubtitle;
  final Future<void> Function() onRefresh;
  final Widget Function(JournalModel, MasterDataProvider) itemBuilder;

  const _InfiniteJournalListView({
    required this.allJournals,
    required this.masterProvider,
    this.emptySubtitle,
    required this.onRefresh,
    required this.itemBuilder,
  });

  @override
  State<_InfiniteJournalListView> createState() => _InfiniteJournalListViewState();
}

class _InfiniteJournalListViewState extends State<_InfiniteJournalListView> {
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 12;
  int _displayedCount = _pageSize;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _displayedCount = widget.allJournals.length > _pageSize ? _pageSize : widget.allJournals.length;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _InfiniteJournalListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allJournals.length != widget.allJournals.length) {
      if (_displayedCount > widget.allJournals.length || _displayedCount < _pageSize) {
        _displayedCount = widget.allJournals.length > _pageSize ? _pageSize : widget.allJournals.length;
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll > 0 && currentScroll >= maxScroll - 120) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoadingMore || _displayedCount >= widget.allJournals.length) return;
    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _displayedCount = (_displayedCount + _pageSize).clamp(0, widget.allJournals.length);
        _isLoadingMore = false;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.allJournals.isEmpty) {
      return AppEmptyWidget(
        title: 'Jurnal Kosong',
        subtitle: widget.emptySubtitle ?? 'Tidak ada data jurnal dalam kategori ini.',
      );
    }

    final visibleItems = widget.allJournals.take(_displayedCount).toList();
    final hasMore = _displayedCount < widget.allJournals.length;

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _displayedCount = widget.allJournals.length > _pageSize ? _pageSize : widget.allJournals.length;
        });
        await widget.onRefresh();
      },
      color: AppTheme.primaryColor,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.all(16.w),
        itemCount: visibleItems.length + (_isLoadingMore || hasMore ? 1 : 0),
        separatorBuilder: (context, index) {
          if (index >= visibleItems.length - 1) return const SizedBox.shrink();
          return SizedBox(height: 12.h);
        },
        itemBuilder: (context, index) {
          if (index == visibleItems.length) {
            if (!_isLoadingMore && hasMore) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _loadMore();
              });
            }
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h),
              child: Center(
                child: SizedBox(
                  width: 22.w,
                  height: 22.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            );
          }

          final currentJournal = visibleItems[index];
          final isFirst = index == 0;
          final isNewDate = isFirst ||
              currentJournal.date.year != visibleItems[index - 1].date.year ||
              currentJournal.date.month != visibleItems[index - 1].date.month ||
              currentJournal.date.day != visibleItems[index - 1].date.day;

          final card = widget.itemBuilder(currentJournal, widget.masterProvider);
          if (isNewDate) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: isFirst ? 0 : 6.h, bottom: 8.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF334155)
                                : const Color(0xFFBFDBFE),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11.5.sp,
                              color: const Color(0xFF2563EB),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              AppHelper.formatDate(currentJournal.date),
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF93C5FD)
                                    : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                card,
              ],
            );
          }
          return card;
        },
      ),
    );
  }
}
