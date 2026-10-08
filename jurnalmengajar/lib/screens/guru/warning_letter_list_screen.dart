import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/journal_model.dart';
import '../../models/schedule_model.dart';
import '../../models/warning_letter_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';
import '../../widgets/guru_drawer.dart';

class GuruWarningLetterListScreen extends StatefulWidget {
  const GuruWarningLetterListScreen({super.key});

  @override
  State<GuruWarningLetterListScreen> createState() => _GuruWarningLetterListScreenState();
}

class _GuruWarningLetterListScreenState extends State<GuruWarningLetterListScreen> {
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 8;
  int _displayedCount = _pageSize;
  int _currentTotalCount = 0;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _loadData();
    });
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
    if (_isLoadingMore || _displayedCount >= _currentTotalCount) return;

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _displayedCount = (_displayedCount + _pageSize).clamp(0, _currentTotalCount);
        _isLoadingMore = false;
      });
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final warningProvider = Provider.of<WarningLetterProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      await masterProvider.loadAllData(authProvider.activeSchoolId);
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
        orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
      );

      if (teacher.id.isNotEmpty) {
        final activeSchoolId = authProvider.activeSchoolId;
        scheduleProvider.setSchoolId(activeSchoolId);
        journalProvider.setSchoolId(activeSchoolId);
        await Future.wait([
          warningProvider.loadTeacherWarningLetters(teacher.id, activeSchoolId),
          scheduleProvider.loadTeacherSchedules(teacher.id, DateTime.now()),
          journalProvider.loadTeacherJournals(teacher.id),
        ]);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatReason(String reason) {
    return reason.replaceAllMapped(
      RegExp(r'Jam ke-([0-9,\s]+)', caseSensitive: false),
      (match) {
        final raw = match.group(1);
        if (raw == null) return match.group(0) ?? '';
        final numbers = RegExp(r'\d+')
            .allMatches(raw)
            .map((m) => int.tryParse(m.group(0) ?? ''))
            .whereType<int>()
            .toList();
        if (numbers.isEmpty) return match.group(0) ?? '';
        final formatted = AppHelper.formatTeachingHours(numbers);
        return 'Jam ke-${formatted.replaceAll('-', ' - ')}';
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasJournalForSchedule({
    required ScheduleModel schedule,
    required List<JournalModel> journals,
  }) {
    for (final j in journals) {
      // Jurnal yang ditolak (perlu revisi) belum dianggap mengisi.
      if (j.status == 'rejected') continue;
      if (j.scheduleId == schedule.id) {
        if (_isSameDay(j.date, schedule.date)) return true;
        // scheduleId cocok walau tanggal geser sedikit tetap dianggap mengisi.
        return true;
      }
      if (_isSameDay(j.date, schedule.date) &&
          j.classId == schedule.classId &&
          j.subjectId == schedule.subjectId) {
        return true;
      }
    }
    return false;
  }

  /// True bila SELURUH jadwal mengajar pada [groupDate] sudah memiliki jurnal
  /// (non-rejected). Satu pengingat bisa mencakup beberapa kelas sekaligus,
  /// sehingga pengecekan dilakukan per tanggal, bukan per satu scheduleId.
  /// Bila jadwal tanggal tersebut tidak ada di cache, fallback ke
  /// pencocokan scheduleId tiap pengingat; bila tetap tidak terbukti terisi,
  /// kembalikan false (fail-closed: belum bisa dikonfirmasi/dihapus).
  bool _isGroupJournalFilled({
    required DateTime groupDate,
    required List<WarningLetterModel> groupWarnings,
    required List<ScheduleModel> schedules,
    required List<JournalModel> journals,
  }) {
    final daySchedules = schedules.where((s) => _isSameDay(s.date, groupDate)).toList();
    if (daySchedules.isNotEmpty) {
      for (final s in daySchedules) {
        if (!_hasJournalForSchedule(schedule: s, journals: journals)) return false;
      }
      return true;
    }
    for (final w in groupWarnings) {
      final found = journals.any((j) => j.status != 'rejected' && j.scheduleId == w.scheduleId);
      if (!found) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final warningProvider = context.watch<WarningLetterProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final isLoading = warningProvider.isLoading || scheduleProvider.isLoading;
    final activeSchoolId = AppHelper.parseSingleCleanSchoolId(context.watch<AuthProvider>().activeSchoolId);
    final schoolWarnings = warningProvider.warningLetters.where((w) {
      if (activeSchoolId != null && activeSchoolId.isNotEmpty) {
        final wSchoolId = AppHelper.parseSingleCleanSchoolId(w.schoolId);
        if (wSchoolId != activeSchoolId) return false;
      }
      if (w.reason.contains('Kelas--')) return false;
      return true;
    }).toList();

    // Group warnings by schedule date (fallback to issuedAt date)
    final Map<String, List<WarningLetterModel>> groupedMap = {};
    final Map<String, DateTime> dateMap = {};

    for (final warning in schoolWarnings) {
      final schedule = scheduleProvider.cachedTeacherSchedules.firstWhere(
        (s) => s.id == warning.scheduleId,
        orElse: () => ScheduleModel(
          id: '',
          teacherId: '',
          classId: '',
          subjectId: '',
          periodId: '',
          date: warning.issuedAt,
          teachingHour: 0,
          isActive: false,
        ),
      );

      final dateKey = '${schedule.date.year}-${schedule.date.month}-${schedule.date.day}';
      groupedMap.putIfAbsent(dateKey, () => []).add(warning);
      dateMap.putIfAbsent(dateKey, () => DateTime(schedule.date.year, schedule.date.month, schedule.date.day));
    }

    final sortedGroups = groupedMap.entries.toList()
      ..sort((a, b) {
        final dateA = dateMap[a.key]!;
        final dateB = dateMap[b.key]!;
        return dateB.compareTo(dateA);
      });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const GuruDrawer(currentRoute: '/guru/warning-letters'),
      appBar: AppBar( 
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () {
              Scaffold.of(ctx).openDrawer();
            },
          ),
        ),
        title: Text(
          'Pengingat Saya',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
              final currentUser = authProvider.currentUser;
              if (currentUser != null) {
                TeacherModel? teacher;
                try {
                  teacher = masterProvider.teachers.firstWhere(
                    (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
                  );
                } catch (_) {
                  teacher = null;
                }
                if (teacher == null) {
                  if (context.mounted) {
                    AppHelper.showSnackBar(context, 'Data guru tidak ditemukan. Coba muat ulang.', isError: true);
                  }
                  return;
                }
                if (value == 'confirm_all') {
                  final journalProvider = Provider.of<JournalProvider>(context, listen: false);
                  final schedProvider = Provider.of<ScheduleProvider>(context, listen: false);
                  final journals = journalProvider.teacherJournals;
                  final schedules = schedProvider.cachedTeacherSchedules;
                  final List<String> fillableIds = [];
                  int skippedGroups = 0;
                  for (final entry in groupedMap.entries) {
                    final gDate = dateMap[entry.key]!;
                    final gWarnings = entry.value;
                    final unread = gWarnings.where((w) => w.status == 'unread').toList();
                    if (unread.isEmpty) continue;
                    final filled = _isGroupJournalFilled(
                      groupDate: gDate,
                      groupWarnings: gWarnings,
                      schedules: schedules,
                      journals: journals,
                    );
                    if (filled) {
                      fillableIds.addAll(unread.map((w) => w.id));
                    } else {
                      skippedGroups++;
                    }
                  }
                  if (fillableIds.isEmpty) {
                    if (context.mounted) {
                      AppHelper.showSnackBar(
                        context,
                        'Belum bisa dikonfirmasi. Isi jurnal mengajar terlebih dahulu sampai tuntas.',
                        isError: true,
                      );
                    }
                    return;
                  }
                  bool allOk = true;
                  for (final id in fillableIds) {
                    final ok = await warningProvider.markWarningLetterAsRead(id);
                    if (!ok) allOk = false;
                  }
                  if (!context.mounted) return;
                  if (allOk && warningProvider.errorMessage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          skippedGroups > 0
                              ? 'Pengingat yang jurnalnya sudah diisi berhasil dikonfirmasi. $skippedGroups pengingat lain dilewati karena jurnalnya belum diisi.'
                              : 'Semua pengingat berhasil dikonfirmasi.',
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(warningProvider.errorMessage ?? 'Gagal mengonfirmasi pengingat.'), backgroundColor: Colors.red),
                    );
                  }
                } else if (value == 'delete_all') {
                  final journalProvider = Provider.of<JournalProvider>(context, listen: false);
                  final schedProvider = Provider.of<ScheduleProvider>(context, listen: false);
                  final journals = journalProvider.teacherJournals;
                  final schedules = schedProvider.cachedTeacherSchedules;
                  final List<String> deletableIds = [];
                  int blockedConfirmed = 0;
                  for (final entry in groupedMap.entries) {
                    final gDate = dateMap[entry.key]!;
                    final gWarnings = entry.value;
                    final filled = _isGroupJournalFilled(
                      groupDate: gDate,
                      groupWarnings: gWarnings,
                      schedules: schedules,
                      journals: journals,
                    );
                    for (final w in gWarnings) {
                      if (w.status != 'read') continue;
                      if (filled) {
                        deletableIds.add(w.id);
                      } else {
                        blockedConfirmed++;
                      }
                    }
                  }
                  final unreadCount = schoolWarnings.where((w) => w.status == 'unread').length;
                  if (deletableIds.isEmpty) {
                    if (context.mounted) {
                      AppHelper.showSnackBar(
                        context,
                        unreadCount > 0
                            ? 'Belum bisa dihapus. Pastikan jurnal sudah diisi dan pengingat sudah dikonfirmasi.'
                            : (blockedConfirmed > 0
                                ? 'Belum bisa dihapus. Jurnal pada pengingat yang dikonfirmasi belum terisi lengkap.'
                                : 'Belum ada riwayat pengingat yang bisa dihapus.'),
                        isError: true,
                      );
                    }
                    return;
                  }
                  final confirmDelete = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Hapus Riwayat Pengingat'),
                      content: Text(
                        'Hanya ${deletableIds.length} pengingat yang jurnalnya sudah diisi & sudah dikonfirmasi yang akan dihapus.'
                        '${blockedConfirmed > 0 ? ' $blockedConfirmed pengingat dikonfirmasi lainnya dilewati karena jurnalnya belum terisi lengkap.' : ''}'
                        '${unreadCount > 0 ? ' Pengingat yang belum dikonfirmasi tidak akan dihapus.' : ''}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmDelete == true && context.mounted) {
                    final ok = await warningProvider.deleteWarningsByIds(deletableIds);
                    if (!context.mounted) return;
                    if (ok && warningProvider.errorMessage == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pengingat yang dikonfirmasi berhasil dihapus.')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(warningProvider.errorMessage ?? 'Gagal menghapus pengingat.'), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'confirm_all',
                child: Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Konfirmasi Semua'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus Riwayat Pengingat', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _displayedCount = _pageSize;
                  });
                  await _loadData();
                },
                color: AppTheme.primaryColor,
                child: schoolWarnings.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: 120.h),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(20.w),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 64,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                Text(
                                  'Kinerja Luar Biasa!',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                                  child: Text(
                                    'Anda tidak memiliki pengingat. Terus pertahankan kedisiplinan dalam mengisi jurnal mengajar!',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Builder(
                        builder: (context) {
                          _currentTotalCount = sortedGroups.length;
                          final visibleGroups = sortedGroups.take(_displayedCount).toList();
                          final hasMore = _displayedCount < sortedGroups.length;
                          final journals = journalProvider.teacherJournals;
                          final allSchedules = scheduleProvider.cachedTeacherSchedules;

                          return ListView.separated(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: EdgeInsets.all(16.w),
                            itemCount: visibleGroups.length + (_isLoadingMore || hasMore ? 1 : 0),
                            separatorBuilder: (context, index) {
                              if (index >= visibleGroups.length - 1) return const SizedBox.shrink();
                              return SizedBox(height: 16.h);
                            },
                            itemBuilder: (context, index) {
                              if (index == visibleGroups.length) {
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
                              final group = visibleGroups[index];
                              final groupDate = dateMap[group.key]!;
                              final groupWarnings = group.value;

                              final hasUnread = groupWarnings.any((w) => w.status == 'unread');
                              final unreadList = groupWarnings.where((w) => w.status == 'unread').toList();
                              // Kunci konfirmasi: hanya bisa dikonfirmasi bila seluruh
                              // jurnal pada tanggal ini sudah terisi (non-rejected).
                              final isJournalFilled = _isGroupJournalFilled(
                                groupDate: groupDate,
                                groupWarnings: groupWarnings,
                                schedules: allSchedules,
                                journals: journals,
                              );

                              final theme = Theme.of(context);
                              return Card(
                                margin: EdgeInsets.zero,
                                color: theme.colorScheme.surface,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  side: BorderSide(
                                    color: hasUnread
                                        ? const Color(0xFFFECACA)
                                        : theme.colorScheme.outlineVariant,
                                    width: hasUnread ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16.w),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8.w),
                                            decoration: BoxDecoration(
                                              color: hasUnread
                                                  ? const Color(0xFFFEE2E2)
                                                  : const Color(0xFFF1F5F9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.warning_amber_rounded,
                                              color: hasUnread
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF64748B),
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Text(
                                              AppHelper.formatDate(groupDate),
                                              style: GoogleFonts.hankenGrotesk(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.sp,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ),
                                          if (!hasUnread)
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDCFCE7),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Dikonfirmasi',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 9.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF15803D),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: groupWarnings.map((w) {
                                          return Padding(
                                            padding: EdgeInsets.only(bottom: 8.h),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '• ',
                                                  style: TextStyle(
                                                    color: w.status == 'unread' ? const Color(0xFFB91C1C) : const Color(0xFF64748B),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    _formatReason(w.reason),
                                                    style: GoogleFonts.hankenGrotesk(
                                                      fontSize: 13.sp,
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      if (hasUnread) ...[
                                        SizedBox(height: 12.h),
                                        if (!isJournalFilled)
                                          Padding(
                                            padding: EdgeInsets.only(bottom: 8.h),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.info_outline_rounded,
                                                  size: 14,
                                                  color: Color(0xFFB91C1C),
                                                ),
                                                SizedBox(width: 6.w),
                                                Expanded(
                                                  child: Text(
                                                    'Jurnal belum diisi. Isi jurnal mengajar terlebih dahulu sebelum konfirmasi.',
                                                    style: GoogleFonts.hankenGrotesk(
                                                      fontSize: 11.5.sp,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFFB91C1C),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: (warningProvider.isLoading || !isJournalFilled)
                                                ? null
                                                : () async {
                                                    bool allOk = true;
                                                    for (final w in unreadList) {
                                                      final ok = await warningProvider.markWarningLetterAsRead(w.id);
                                                      if (!ok) allOk = false;
                                                    }
                                                    if (!allOk && context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(warningProvider.errorMessage ?? 'Gagal mengonfirmasi sebagian pengingat.'),
                                                          backgroundColor: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  },
                                            icon: const Icon(Icons.check_circle_outline, size: 16),
                                            label: const Text('Konfirmasi'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryColor,
                                              foregroundColor: Colors.white,
                                              padding: EdgeInsets.symmetric(vertical: 10.h),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12.r),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
    );
  }
}
