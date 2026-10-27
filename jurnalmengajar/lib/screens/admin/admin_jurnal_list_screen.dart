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
import '../../models/period_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/admin_selection_action_button.dart';
import '../../widgets/admin_search_filter_bar.dart';
import '../../widgets/admin_period_selector_bar.dart';
import '../../widgets/state_widgets.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_extensions.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../widgets/animated_widgets.dart';
import '../../services/excel_export_service.dart';
import '../../widgets/app_scaffold.dart';

class AdminJurnalListScreen extends StatefulWidget {
  /// If non-null, jump directly to a specific tab index (0=Semua, 1=Belum Diisi, 2=Menunggu, 3=Terverifikasi)
  final int initialTabIndex;

  /// When set, the list is scoped to this date (used by the dashboard stat cards).
  final DateTime? initialDate;

  /// When set, the list is scoped to this teacher (used by the dashboard stat cards).
  final String? initialTeacherId;

  const AdminJurnalListScreen({
    super.key,
    this.initialTabIndex = 0,
    this.initialDate,
    this.initialTeacherId,
  });

  @override
  State<AdminJurnalListScreen> createState() => _AdminJurnalListScreenState();
}

class _AdminJurnalListScreenState extends State<AdminJurnalListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedClassId = 'all';
  final Set<String> _expandedTeacherIds = {};
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  String? _selectedPeriodId;
  String? _lastSchoolId;
  DateTime? _filterDate;
  String? _filterTeacherId;

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

  void _selectByStatus(String? status, List<JournalModel> journals) {
    setState(() {
      if (status == null || status == 'all') {
        if (_selectedIds.length == journals.length) {
          _selectedIds.clear();
        } else {
          _selectedIds.addAll(journals.map((j) => j.id));
        }
      } else if (status == 'pending') {
        final targetIds = journals
            .where((j) => j.status == 'pending')
            .map((j) => j.id)
            .toSet();
        if (_selectedIds.containsAll(targetIds) && targetIds.isNotEmpty) {
          _selectedIds.removeAll(targetIds);
        } else {
          _selectedIds.addAll(targetIds);
        }
      } else if (status == 'rejected') {
        final targetIds = journals
            .where((j) => j.status == 'rejected')
            .map((j) => j.id)
            .toSet();
        if (_selectedIds.containsAll(targetIds) && targetIds.isNotEmpty) {
          _selectedIds.removeAll(targetIds);
        } else {
          _selectedIds.addAll(targetIds);
        }
      } else if (status == 'verified') {
        final targetIds = journals
            .where((j) => j.status == 'verified' || j.status == 'approved')
            .map((j) => j.id)
            .toSet();
        if (_selectedIds.containsAll(targetIds) && targetIds.isNotEmpty) {
          _selectedIds.removeAll(targetIds);
        } else {
          _selectedIds.addAll(targetIds);
        }
      }
    });
  }

  Widget _buildQuickSelectChip({
    required BuildContext context,
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final activeBg = isSelected ? color.withValues(alpha: context.isDarkMode ? 0.25 : 0.12) : context.containerBg;
    final inactiveBorder = context.borderOutline;
    final activeTextColor = isSelected ? color : (count == 0 ? context.textMuted : context.textPrimary);

    return InkWell(
      onTap: count == 0 ? null : onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: activeBg,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? color : inactiveBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 13.r, color: activeTextColor),
              SizedBox(width: 4.w),
            ],
            Text(
              '$label ($count)',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.5.sp,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: activeTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBatchApprove() async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final eligibleSelected = _selectedIds.where((id) {
      final matches = journalProvider.journals.where((item) => item.id == id);
      return matches.isNotEmpty && matches.first.status != 'verified';
    }).toList();
    if (eligibleSelected.isEmpty) return;

    final count = eligibleSelected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Terima $count Jurnal',
          style: const TextStyle(color: Color(0xFF2563EB)),
        ),
        content: Text('Apakah Anda yakin ingin menerima $count data jurnal yang dipilih?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Terima Semua'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await journalProvider.verifyMultipleJournals(eligibleSelected, 'verified');
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count jurnal berhasil diterima.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, 'Gagal menerima jurnal.', isError: true);
      }
    }
  }

  Future<void> _handleBatchReject() async {
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final eligibleSelected = _selectedIds.where((id) {
      final matches = journalProvider.journals.where((item) => item.id == id);
      return matches.isNotEmpty && matches.first.status != 'rejected';
    }).toList();
    if (eligibleSelected.isEmpty) return;

    final count = eligibleSelected.length;
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Tolak $count Jurnal',
          style: const TextStyle(color: Color(0xFFE11D48)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin menolak $count data jurnal yang dipilih?'),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Alasan Penolakan (Opsional)',
                hintText: 'Misal: Materi belum lengkap',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak Jurnal'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
      final success = await journalProvider.verifyMultipleJournals(
        eligibleSelected,
        'rejected',
        rejectionNote: note,
      );
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count jurnal telah ditolak.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, 'Gagal menolak jurnal.', isError: true);
      }
    }
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Hapus $count Jurnal',
          style: const TextStyle(color: Colors.red),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus $count data jurnal yang dipilih secara permanen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Hapus Massal',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final journalProvider = Provider.of<JournalProvider>(
        context,
        listen: false,
      );
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
        AppHelper.showSnackBar(
          context,
          journalProvider.errorMessage ?? 'Gagal menghapus jurnal.',
          isError: true,
        );
      }
    }
  }

  bool _isExporting = false;

  Future<void> _handleExportExcel(
    List<JournalModel> journals,
    MasterDataProvider master,
    AuthProvider auth,
  ) async {
    if (_isExporting) return;
    if (journals.isEmpty) {
      AppHelper.showSnackBar(
        context,
        'Tidak ada data jurnal untuk diekspor.',
        isError: true,
      );
      return;
    }

    setState(() => _isExporting = true);
    AppHelper.showSnackBar(context, 'Mempersiapkan file Excel...');

    try {
      final schoolName = auth.activeSchoolName.isNotEmpty
          ? auth.activeSchoolName
          : 'Sekolah';
      await ExcelExportService.exportJournals(
        journals: journals,
        masterProvider: master,
        schoolName: schoolName,
      );
      if (mounted) {
        AppHelper.showSnackBar(context, 'Data berhasil diekspor ke Excel.');
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(
          context,
          'Ekspor gagal. Silakan coba lagi.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _filterDate = widget.initialDate;
    _filterTeacherId = widget.initialTeacherId;
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

  Future<void> _refreshData({String? periodId}) async {
    if (!mounted) return;
    final journalProvider = Provider.of<JournalProvider>(
      context,
      listen: false,
    );
    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    final scheduleProvider = Provider.of<ScheduleProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await masterProvider.loadAllData(authProvider.activeSchoolId);

    final activeId =
        masterProvider.activePeriod?.id ??
        (masterProvider.periods.isNotEmpty
            ? masterProvider.periods.first.id
            : null);
    final targetPeriodId = periodId ?? _selectedPeriodId ?? activeId;
    if (_selectedPeriodId != targetPeriodId) {
      setState(() {
        _selectedPeriodId = targetPeriodId;
      });
    }

    await Future.wait([
      journalProvider.loadAllJournals(
        authProvider.activeSchoolId,
        targetPeriodId,
      ),
      scheduleProvider.loadAllSchedules(
        authProvider.activeSchoolId,
        targetPeriodId,
      ),
    ]);
  }

  Future<void> _onPeriodChanged(String newPeriodId) async {
    setState(() {
      _selectedPeriodId = newPeriodId;
      _selectedClassId = 'all';
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(
      context,
      listen: false,
    );
    final scheduleProvider = Provider.of<ScheduleProvider>(
      context,
      listen: false,
    );

    await Future.wait([
      journalProvider.loadAllJournals(authProvider.activeSchoolId, newPeriodId),
      scheduleProvider.loadAllSchedules(
        authProvider.activeSchoolId,
        newPeriodId,
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (_lastSchoolId != authProvider.activeSchoolId) {
      _lastSchoolId = authProvider.activeSchoolId;
      _selectedPeriodId = null;
    }

    final effectivePeriodId =
        _selectedPeriodId ??
        masterProvider.activePeriod?.id ??
        (masterProvider.periods.isNotEmpty
            ? masterProvider.periods.first.id
            : null);
    final currentPeriod = masterProvider.periods.firstWhere(
      (p) => p.id == effectivePeriodId,
      orElse: () =>
          masterProvider.activePeriod ??
          PeriodModel(id: '', name: '', isActive: true),
    );
    final isHistorical = !currentPeriod.isActive && currentPeriod.id.isNotEmpty;

    final providerJournals = journalProvider.journals;
    final filterDate = _filterDate;
    final filterTeacherId = _filterTeacherId;
    final scheduleTeacherById = {
      for (final s in scheduleProvider.schedules) s.id: s.teacherId,
    };

    final allJournals = providerJournals.where((j) {
      if (filterDate != null) {
        final sameDate =
            j.date.year == filterDate.year &&
            j.date.month == filterDate.month &&
            j.date.day == filterDate.day;
        if (!sameDate) return false;
      }
      if (filterTeacherId != null &&
          filterTeacherId.isNotEmpty &&
          j.teacherId != filterTeacherId &&
          scheduleTeacherById[j.scheduleId] != filterTeacherId) {
        return false;
      }
      return true;
    }).toList();

    final pendingJournals = allJournals
        .where((j) => j.status == 'pending')
        .toList();
    final verifiedJournals = allJournals
        .where((j) => j.status == 'verified' || j.status == 'approved')
        .toList();
    final rejectedJournals = allJournals
        .where((j) => j.status == 'rejected')
        .toList();

    // Get unfilled schedules
    final activeSchedules = scheduleProvider.schedules
        .where((s) => s.isActive)
        .toList();
    final groupedDailySchedules = groupDailySchedules(activeSchedules);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<GroupedDailySchedule> unfilledGroups;
    if (filterDate != null) {
      // Same-day view: mirror the dashboard cards exactly so the number of
      // items shown here matches the stat card that was tapped.
      final daySchedules = scheduleProvider.schedules.where((s) {
        if (s.date.year != filterDate.year ||
            s.date.month != filterDate.month ||
            s.date.day != filterDate.day) {
          return false;
        }
        if (filterTeacherId != null &&
            filterTeacherId.isNotEmpty &&
            s.teacherId != filterTeacherId) {
          return false;
        }
        return true;
      }).toList();
      final dayGroupedSchedules = groupDailySchedules(daySchedules);

      unfilledGroups = dayGroupedSchedules.where((group) {
        final hasCompletedJournal = providerJournals.any(
          (j) =>
              group.scheduleIds.contains(j.scheduleId) &&
              j.status != 'rejected',
        );
        return !hasCompletedJournal;
      }).toList()..sort((a, b) => b.date.compareTo(a.date));
    } else {
      unfilledGroups = groupedDailySchedules.where((group) {
        if (!group.date.isBefore(today)) return false;
        final hasJournal = allJournals.any(
          (j) => group.scheduleIds.contains(j.scheduleId),
        );
        return !hasJournal;
      }).toList()..sort((a, b) => b.date.compareTo(a.date));
    }

    final isLoading =
        journalProvider.isLoading ||
        masterProvider.isLoading ||
        scheduleProvider.isLoading;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedIds.clear();
          });
          return;
        }
        context.go('/admin/dashboard');
      },
      child: AppScaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor: context.surfaceColor,
                foregroundColor: context.textPrimary,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Batal Pilih',
                  onPressed: () => setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  }),
                ),
                title: Text(
                  '${_selectedIds.length} Terpilih',
                  style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                actions: [
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.checklist_rounded,
                      color: context.textPrimary,
                    ),
                    tooltip: 'Opsi Pilihan Massal',
                    onSelected: (val) {
                      if (val == 'clear') {
                        setState(() => _selectedIds.clear());
                      } else {
                        _selectByStatus(val, allJournals);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'all',
                        child: Row(
                          children: [
                            Icon(Icons.select_all_rounded, size: 18, color: context.statusColors.info),
                            SizedBox(width: 8.w),
                            Text('Semua (${allJournals.length})'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'pending',
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, size: 18, color: context.statusColors.pending),
                            SizedBox(width: 8.w),
                            Text('Pending (${pendingJournals.length})'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rejected',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, size: 18, color: context.statusColors.rejected),
                            SizedBox(width: 8.w),
                            Text('Ditolak (${rejectedJournals.length})'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'verified',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 18, color: context.statusColors.verified),
                            SizedBox(width: 8.w),
                            Text('Diterima (${verifiedJournals.length})'),
                          ],
                        ),
                      ),
                      if (_selectedIds.isNotEmpty) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'clear',
                          child: Row(
                            children: [
                              Icon(Icons.deselect_rounded, size: 18, color: context.textMuted),
                              SizedBox(width: 8.w),
                              const Text('Batal Pilih Semua'),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Builder(
                    builder: (context) {
                      final selectedApprovableCount = allJournals
                          .where((j) => _selectedIds.contains(j.id) && j.status != 'verified')
                          .length;
                      final selectedRejectableCount = allJournals
                          .where((j) => _selectedIds.contains(j.id) && j.status != 'rejected')
                          .length;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedApprovableCount > 0)
                            IconButton(
                              icon: Icon(Icons.check_circle_rounded, color: context.statusColors.verified),
                              tooltip: 'Terima ($selectedApprovableCount)',
                              onPressed: _handleBatchApprove,
                            ),
                          if (selectedRejectableCount > 0)
                            IconButton(
                              icon: Icon(Icons.cancel_rounded, color: context.statusColors.rejected),
                              tooltip: 'Tolak ($selectedRejectableCount)',
                              onPressed: _handleBatchReject,
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: context.colorScheme.error),
                    tooltip: 'Hapus Massal',
                    onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(42.h),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: context.scaffoldBg,
                      border: Border(
                        bottom: BorderSide(
                          color: context.borderOutline,
                        ),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickSelectChip(
                            context: context,
                            label: 'Semua',
                            count: allJournals.length,
                            isSelected: allJournals.isNotEmpty &&
                                allJournals.every((j) => _selectedIds.contains(j.id)),
                            color: context.statusColors.info,
                            onTap: () => _selectByStatus('all', allJournals),
                          ),
                          SizedBox(width: 8.w),
                          _buildQuickSelectChip(
                            context: context,
                            label: 'Pending',
                            count: pendingJournals.length,
                            isSelected: pendingJournals.isNotEmpty &&
                                pendingJournals.every((j) => _selectedIds.contains(j.id)),
                            color: context.statusColors.pending,
                            onTap: () => _selectByStatus('pending', allJournals),
                          ),
                          SizedBox(width: 8.w),
                          _buildQuickSelectChip(
                            context: context,
                            label: 'Ditolak',
                            count: rejectedJournals.length,
                            isSelected: rejectedJournals.isNotEmpty &&
                                rejectedJournals.every((j) => _selectedIds.contains(j.id)),
                            color: context.statusColors.rejected,
                            onTap: () => _selectByStatus('rejected', allJournals),
                          ),
                          SizedBox(width: 8.w),
                          _buildQuickSelectChip(
                            context: context,
                            label: 'Diterima',
                            count: verifiedJournals.length,
                            isSelected: verifiedJournals.isNotEmpty &&
                                verifiedJournals.every((j) => _selectedIds.contains(j.id)),
                            color: context.statusColors.verified,
                            onTap: () => _selectByStatus('verified', allJournals),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : AppBar(
                leading: AppMenuButton(
                  child: Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'Menu',
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
                ),
                title: const Text('Jurnal Mengajar'),
                actions: [
                  IconButton(
                    icon: _isExporting
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF2563EB),
                            ),
                          )
                        : const Icon(
                            Icons.table_view_rounded,
                            color: Color(0xFF10B981),
                          ),
                    tooltip: 'Ekspor Excel',
                    onPressed: (_isExporting || allJournals.isEmpty)
                        ? null
                        : () {
                            // Filter active journals according to tab and search
                            List<JournalModel> targetJournals = allJournals;
                            if (_tabController.index == 2) {
                              targetJournals = pendingJournals;
                            } else if (_tabController.index == 3) {
                              targetJournals = verifiedJournals;
                            }
                            if (_searchQuery.isNotEmpty) {
                              final query = _searchQuery.toLowerCase();
                              targetJournals = targetJournals.where((j) {
                                final t = masterProvider.teachers.firstWhere(
                                  (teacher) => teacher.id == j.teacherId,
                                  orElse: () => TeacherModel(
                                    id: '',
                                    name: '',
                                    position: '',
                                    address: '',
                                    phoneNumber: '',
                                    email: '',
                                  ),
                                );
                                final c = masterProvider.classes.firstWhere(
                                  (cls) => cls.id == j.classId,
                                  orElse: () => ClassModel(
                                    id: '',
                                    name: '',
                                    periodId: '',
                                    studentCount: 0,
                                  ),
                                );
                                final s = masterProvider.subjects.firstWhere(
                                  (subj) => subj.id == j.subjectId,
                                  orElse: () => SubjectModel(
                                    id: '',
                                    name: '',
                                    isActive: false,
                                  ),
                                );
                                return t.name.toLowerCase().contains(query) ||
                                    c.name.toLowerCase().contains(query) ||
                                    s.name.toLowerCase().contains(query) ||
                                    j.material.toLowerCase().contains(query);
                              }).toList();
                            }
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            _handleExportExcel(
                              targetJournals,
                              masterProvider,
                              authProvider,
                            );
                          },
                  ),
                  if (!isHistorical)
                    AdminSelectionActionButton(
                      onPressed: allJournals.isEmpty
                          ? null
                          : () => _toggleSelectionMode(),
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
                      dividerColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                      dividerHeight: 1,
                      tabs: [
                        _buildTab(
                          'Semua',
                          allJournals.length,
                          badgeColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                        ),
                        _buildTab(
                          'Belum Diisi',
                          unfilledGroups.length,
                          badgeColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFF87171)
                              : const Color(0xFFBA1A1A),
                        ),
                        _buildTab(
                          'Pending',
                          pendingJournals.length,
                          badgeColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706),
                        ),
                        _buildTab(
                          'Diterima',
                          verifiedJournals.length,
                          badgeColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF2563EB),
                        ),
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
                    AdminPeriodSelectorBar(
                      periods: masterProvider.periods,
                      selectedPeriodId: effectivePeriodId,
                      onPeriodChanged: _onPeriodChanged,
                    ),
                    if (_filterDate != null)
                      _buildDateFilterBanner(masterProvider),
                    AdminSearchFilterBar(
                      hintText: 'Cari guru, kelas, atau mapel...',
                      searchController: _searchController,
                      onSearchChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                          if (val.isNotEmpty) {
                            _expandedTeacherIds.addAll(
                              masterProvider.teachers.map((t) => t.id),
                            );
                          }
                        });
                      },
                      filterItems: [
                        AdminFilterItem(
                          id: 'all',
                          label: 'Semua Kelas',
                          count: allJournals.length,
                        ),
                        ...masterProvider.classes
                            .where((c) {
                              if (c.periodId == currentPeriod.id) return true;
                              return allJournals.any((j) => j.classId == c.id);
                            })
                            .map(
                              (c) => AdminFilterItem(
                                id: c.id,
                                label: c.name,
                                count: allJournals
                                    .where((j) => j.classId == c.id)
                                    .length,
                              ),
                            ),
                      ],
                      selectedFilterId: _selectedClassId,
                      onFilterSelected: (id) =>
                          setState(() => _selectedClassId = id),
                    ),
                    // ── Tab Content ──────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildJournalList(
                            allJournals,
                            masterProvider,
                            badgeColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB),
                          ),
                          _buildUnfilledList(unfilledGroups, masterProvider),
                          pendingJournals.isEmpty
                              ? _buildJournalList(
                                  pendingJournals,
                                  masterProvider,
                                  badgeColor:
                                      Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFFFBBF24)
                                      : const Color(0xFFD97706),
                                )
                              : Column(
                                  children: [
                                    Container(
                                      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 4.h),
                                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF78350F).withValues(alpha: 0.25)
                                            : const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(12.r),
                                        border: Border.all(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFFD97706).withValues(alpha: 0.5)
                                              : const Color(0xFFFDE68A),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.rule_folder_rounded, color: Color(0xFFD97706)),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Text(
                                              'Terdapat ${pendingJournals.length} jurnal yang perlu disetujui.',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w600,
                                                color: Theme.of(context).brightness == Brightness.dark
                                                    ? const Color(0xFFFDE68A)
                                                    : const Color(0xFF92400E),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          ElevatedButton(
                                            onPressed: () {
                                              setState(() {
                                                _isSelectionMode = true;
                                                _selectedIds.clear();
                                                _selectedIds.addAll(pendingJournals.map((j) => j.id));
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFD97706),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                            ),
                                            child: Text(
                                              'Pilih Massal',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 11.5.sp,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildJournalList(
                                        pendingJournals,
                                        masterProvider,
                                        badgeColor:
                                            Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFFFBBF24)
                                            : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ],
                                ),
                          _buildJournalList(
                            verifiedJournals,
                            masterProvider,
                            badgeColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDateFilterBanner(MasterDataProvider master) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final teacherId = _filterTeacherId;
    final teacherName = teacherId == null || teacherId.isEmpty
        ? ''
        : master.teachers
              .firstWhere(
                (t) => t.id == teacherId,
                orElse: () => TeacherModel(
                  id: '',
                  name: '',
                  position: '',
                  address: '',
                  phoneNumber: '',
                  email: '',
                ),
              )
              .name;
    final label = StringBuffer(
      'Menampilkan jurnal: ${AppHelper.formatDate(_filterDate!)}',
    );
    if (teacherName.isNotEmpty) {
      label.write(' • $teacherName');
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.25)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF1E40AF) : const Color(0xFFBFDBFE),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 16.r,
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label.toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFF1E40AF),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: () => setState(() {
              _filterDate = null;
              _filterTeacherId = null;
            }),
            child: Padding(
              padding: EdgeInsets.all(2.w),
              child: Icon(
                Icons.close_rounded,
                size: 18.r,
                color: isDark
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFF2563EB),
              ),
            ),
          ),
        ],
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
                color: isDark
                    ? color.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.1),
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
    // Apply universal search & class filter
    final filtered = list.where((j) {
      if (_selectedClassId != 'all' && j.classId != _selectedClassId) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final teacher = master.teachers.firstWhere(
        (t) => t.id == j.teacherId,
        orElse: () => TeacherModel(
          id: '',
          name: '',
          position: '',
          address: '',
          phoneNumber: '',
          email: '',
        ),
      );
      final cls = master.classes.firstWhere(
        (c) => c.id == j.classId,
        orElse: () =>
            ClassModel(id: '', name: '', periodId: '', studentCount: 0),
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
          email: '',
        ),
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
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
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
                      backgroundColor: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F5F9),
                      backgroundImage:
                          teacher.photoUrl != null &&
                              teacher.photoUrl!.startsWith('http')
                          ? NetworkImage(teacher.photoUrl!)
                          : null,
                      child: teacher.photoUrl == null
                          ? Icon(
                              Icons.person,
                              size: 16.r,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : Colors.grey[450],
                            )
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
                            teacher.position.isNotEmpty
                                ? teacher.position
                                : 'Guru',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                        ? activeColor.withValues(alpha: 0.25)
                        : activeColor.withValues(alpha: 0.1),
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
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5)
                        : const Color(0xFFF8FAFC),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 12.h,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teacherItems.length,
                      separatorBuilder: (context, _) => SizedBox(height: 10.h),
                      itemBuilder: (context, itemIndex) {
                        return _buildJournalCard(
                          teacherItems[itemIndex],
                          master,
                        );
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
        email: '',
      ),
    );

    final statusColor = AppHelper.getStatusColor(journal.status);
    final isSelected = _selectedIds.contains(journal.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isHistorical = master.periods.any(
      (p) =>
          p.id == (_selectedPeriodId ?? master.activePeriod?.id) && !p.isActive,
    );

    return ScaleTap(
      onTap: _isSelectionMode
            ? () => _toggleSelectItem(journal.id)
            : () => context.push('/admin/journal/${journal.id}'),
        onLongPress: isHistorical
            ? null
            : () {
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
                : (Theme.of(context).cardTheme.color ??
                      Theme.of(context).colorScheme.surface),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    subject.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (journal.isTeacherAbsence) ...[
                                  Container(
                                    margin: EdgeInsets.only(right: 6.w),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 3.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: journal.isTeacherSick
                                          ? (isDark
                                                ? const Color(
                                                    0xFF7F1D1D,
                                                  ).withValues(alpha: 0.5)
                                                : const Color(0xFFFEE2E2))
                                          : (isDark
                                                ? const Color(
                                                    0xFF78350F,
                                                  ).withValues(alpha: 0.5)
                                                : const Color(0xFFFEF3C7)),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: journal.isTeacherSick
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFF59E0B),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          journal.isTeacherSick
                                              ? Icons.local_hospital_rounded
                                              : Icons.assignment_outlined,
                                          size: 11.sp,
                                          color: journal.isTeacherSick
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFD97706),
                                        ),
                                        SizedBox(width: 3.w),
                                        Text(
                                          journal.isTeacherSick
                                              ? 'SAKIT'
                                              : 'IZIN',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 9.sp,
                                            color: journal.isTeacherSick
                                                ? const Color(0xFFEF4444)
                                                : const Color(0xFFD97706),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 4.h,
                                  ),
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
                          ],
                        ),
                        SizedBox(height: 4.h),
                        // Teacher name
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 13.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                teacher.name,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12.sp,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: journal.isTeacherAbsence
                                ? (journal.isTeacherSick
                                      ? (isDark
                                            ? const Color(
                                                0xFF450A0A,
                                              ).withValues(alpha: 0.3)
                                            : const Color(0xFFFEF2F2))
                                      : (isDark
                                            ? const Color(
                                                0xFF78350F,
                                              ).withValues(alpha: 0.3)
                                            : const Color(0xFFFFFBEB)))
                                : (isDark
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest
                                      : const Color(0xFFF8FAFC)),
                            borderRadius: BorderRadius.circular(8),
                            border: journal.isTeacherAbsence
                                ? Border.all(
                                    color: journal.isTeacherSick
                                        ? (isDark
                                              ? const Color(0xFF991B1B)
                                              : const Color(0xFFFECACA))
                                        : (isDark
                                              ? const Color(0xFF92400E)
                                              : const Color(0xFFFDE68A)),
                                  )
                                : null,
                          ),
                          child: Text(
                            journal.material,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: journal.isTeacherAbsence
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: journal.isTeacherAbsence
                                  ? (journal.isTeacherSick
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFFB45309))
                                  : Theme.of(context).colorScheme.onSurface,
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
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              AppHelper.formatDateShort(journal.date),
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.people_outline,
                              size: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'S:${journal.sickCount} I:${journal.permissionCount} A:${journal.alphaCount}',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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

  Widget _buildUnfilledList(
    List<GroupedDailySchedule> list,
    MasterDataProvider master,
  ) {
    // 1. Filter list by universal search & class filter
    final filteredList = list.where((group) {
      if (_selectedClassId != 'all' && group.classId != _selectedClassId) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final teacher = master.teachers.firstWhere(
        (t) => t.id == group.teacherId,
        orElse: () => TeacherModel(
          id: '',
          name: '',
          position: '',
          address: '',
          phoneNumber: '',
          email: '',
        ),
      );
      final cls = master.classes.firstWhere(
        (c) => c.id == group.classId,
        orElse: () =>
            ClassModel(id: '', name: '', periodId: '', studentCount: 0),
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
          email: '',
        ),
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
                        subtitle:
                            'Tidak ada jadwal belum diisi yang cocok dengan pencarian.',
                      )
                    : const AppEmptyWidget(
                        title: 'Semua Jurnal Terisi',
                        subtitle:
                            'Tidak ada jadwal yang belum diisi jurnalnya.',
                      ))
              : RefreshIndicator(
                  onRefresh: _refreshData,
                  color: const Color(0xFF2563EB),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    itemCount: sortedTeachers.length,
                    itemBuilder: (context, teacherIndex) {
                      final teacher = sortedTeachers[teacherIndex];
                      final teacherItems = groups[teacher]!;
                      final isExpanded = _expandedTeacherIds.contains(
                        teacher.id,
                      );
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;

                      return Card(
                        margin: EdgeInsets.only(bottom: 12.h),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
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
                                  backgroundColor: isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFF1F5F9),
                                  backgroundImage:
                                      teacher.photoUrl != null &&
                                          teacher.photoUrl!.startsWith('http')
                                      ? NetworkImage(teacher.photoUrl!)
                                      : null,
                                  child: teacher.photoUrl == null
                                      ? Icon(
                                          Icons.person,
                                          size: 16.r,
                                          color: isDark
                                              ? const Color(0xFF94A3B8)
                                              : Colors.grey[450],
                                        )
                                      : null,
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        teacher.name,
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        teacher.position.isNotEmpty
                                            ? teacher.position
                                            : 'Guru',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 11.sp,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(
                                        0xFFF87171,
                                      ).withValues(alpha: 0.25)
                                    : const Color(
                                        0xFFBA1A1A,
                                      ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${teacherItems.length}',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  color: isDark
                                      ? const Color(0xFFF87171)
                                      : const Color(0xFFBA1A1A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            children: [
                              Container(
                                color: isDark
                                    ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5)
                                    : const Color(0xFFF8FAFC),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12.w,
                                  vertical: 12.h,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: teacherItems.length,
                                  separatorBuilder: (context, _) =>
                                      SizedBox(height: 10.h),
                                  itemBuilder: (context, itemIndex) {
                                    return _buildUnfilledScheduleCard(
                                      teacherItems[itemIndex],
                                      master,
                                    );
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

  Widget _buildUnfilledScheduleCard(
    GroupedDailySchedule group,
    MasterDataProvider master,
  ) {
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
        email: '',
      ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = isDark
        ? const Color(0xFFF87171)
        : const Color(0xFFBA1A1A);

    return Container(
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                subject.name,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13.sp,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 4.h,
                          ),
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
                        Icon(
                          Icons.person_outline,
                          size: 13.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            teacher.name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest
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
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppTheme.outline,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          AppHelper.formatDateShort(group.date),
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 11.sp,
                            color: AppTheme.outline,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: AppTheme.outline,
                        ),
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
