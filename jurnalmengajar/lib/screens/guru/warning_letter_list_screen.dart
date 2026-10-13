import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/journal_model.dart';
import '../../models/schedule_model.dart';
import '../../models/warning_letter_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';
import '../../core/utils/schedule_grouper.dart';
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

  /// Terisi bila seluruh jadwal [groupDate] punya jurnal non-rejected.
  /// Tanpa cache jadwal, fallback ke scheduleId dan fail-closed bila tak terbukti.
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

  JournalModel? _findJournalForGroup(
    GroupedDailySchedule group,
    List<JournalModel> journals,
  ) {
    final s = group.primarySchedule;
    for (final j in journals) {
      final sameDate = _isSameDay(j.date, group.date);
      if (!sameDate) continue;
      final sameSchedule = j.scheduleId == s.id ||
          group.scheduleIds.contains(j.scheduleId) ||
          (j.classId == s.classId && j.subjectId == s.subjectId);
      if (sameSchedule) return j;
    }
    return null;
  }

  Future<void> _handleDayScheduleTap({
    required BuildContext sheetContext,
    required ScheduleModel schedule,
    required JournalModel? matchingJournal,
    required DateTime day,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    Navigator.pop(sheetContext);
    if (!mounted) return;
    if (matchingJournal != null) {
      if (matchingJournal.status == 'rejected') {
        await context.push(
          '/guru/journal-form?scheduleId=${schedule.id}&journalId=${matchingJournal.id}&date=$dateStr',
        );
      } else {
        await context.push('/guru/journal/${matchingJournal.id}');
      }
    } else {
      final now = DateTime.now();
      final todayOnly = DateTime(now.year, now.month, now.day);
      final targetOnly = DateTime(day.year, day.month, day.day);
      if (targetOnly.isAfter(todayOnly)) {
        if (!mounted) return;
        AppHelper.showSnackBar(
          context,
          'Belum bisa mengisi jurnal mengajar, tunggu sampai hari tersebut tiba.',
          isError: false,
        );
        return;
      }
      await context.push(
        '/guru/journal-form?scheduleId=${schedule.id}&date=$dateStr',
      );
    }
    if (mounted) await _loadData();
  }

  void _openDayJournals({
    required DateTime groupDate,
    required List<WarningLetterModel> groupWarnings,
  }) {
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);

    final daySchedules = scheduleProvider.cachedTeacherSchedules
        .where((s) => _isSameDay(s.date, groupDate))
        .toList();
    final activeDaySchedules = daySchedules.where((s) => s.isActive).toList();
    final journals = journalProvider.teacherJournals;
    final grouped = groupDailySchedules(
      activeDaySchedules.isNotEmpty ? activeDaySchedules : daySchedules,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = AppHelper.formatDate(groupDate);
    final dateStr = DateFormat('yyyy-MM-dd').format(groupDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (ctx, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.calendar_today_rounded,
                            size: 16.sp,
                            color: isDark ? const Color(0xFF93C5FD) : AppTheme.primaryColor,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formattedDate,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                grouped.isNotEmpty
                                    ? '${grouped.length} jadwal'
                                    : 'Jurnal hari ini',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                      children: [
                        if (grouped.isNotEmpty)
                          for (int i = 0; i < grouped.length; i++)
                            _buildDayJournalTile(
                              sheetContext: sheetContext,
                              group: grouped[i],
                              journals: journals,
                              master: masterProvider,
                              isDark: isDark,
                            )
                        else
                          for (final w in groupWarnings)
                            _buildFallbackWarningTile(
                              sheetContext: sheetContext,
                              warning: w,
                              journals: journals,
                              master: masterProvider,
                              groupDate: groupDate,
                              dateStr: dateStr,
                              isDark: isDark,
                            ),
                        if (grouped.isEmpty && groupWarnings.isEmpty)
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 32.h),
                            child: Center(
                              child: Text(
                                'Tidak ada jadwal pada tanggal ini.',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13.sp,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayJournalTile({
    required BuildContext sheetContext,
    required GroupedDailySchedule group,
    required List<JournalModel> journals,
    required MasterDataProvider master,
    required bool isDark,
  }) {
    final schedule = group.primarySchedule;
    final cls = master.classes.firstWhere(
      (c) => c.id == group.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas --', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == group.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mata Pelajaran', isActive: false),
    );
    final matchingJournal = _findJournalForGroup(group, journals);
    final hoursStr = AppHelper.formatTeachingHours(group.teachingHours);

    String statusText = 'Belum Diisi';
    Color statusBg = isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFF1F5F9);
    Color statusColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    if (matchingJournal != null) {
      if (matchingJournal.status == 'verified') {
        statusText = 'Terverifikasi';
        statusBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.12);
        statusColor = const Color(0xFF10B981);
      } else if (matchingJournal.status == 'pending') {
        statusText = 'Menunggu Verifikasi';
        statusBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.12);
        statusColor = const Color(0xFFF59E0B);
      } else if (matchingJournal.status == 'rejected') {
        statusText = 'Perlu Revisi';
        statusBg = Colors.red.withValues(alpha: isDark ? 0.22 : 0.12);
        statusColor = Colors.red;
      }
    }

    return InkWell(
      onTap: () => _handleDayScheduleTap(
        sheetContext: sheetContext,
        schedule: schedule,
        matchingJournal: matchingJournal,
        day: group.date,
      ),
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subject.name,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    statusText,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'Kelas ${cls.name} • Jam ke-$hoursStr',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              matchingJournal != null
                  ? 'Jurnal: ${matchingJournal.material}'
                  : 'Belum diisi.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.5.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: matchingJournal == null
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        matchingJournal == null
                            ? Icons.edit_note_rounded
                            : (matchingJournal.status == 'rejected'
                                ? Icons.edit_note_rounded
                                : Icons.visibility_rounded),
                        size: 14.sp,
                        color: matchingJournal == null ? Colors.white : const Color(0xFF2563EB),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        matchingJournal == null
                            ? 'Isi Jurnal'
                            : (matchingJournal.status == 'rejected' ? 'Revisi Jurnal' : 'Lihat Jurnal'),
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: matchingJournal == null ? Colors.white : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackWarningTile({
    required BuildContext sheetContext,
    required WarningLetterModel warning,
    required List<JournalModel> journals,
    required MasterDataProvider master,
    required DateTime groupDate,
    required String dateStr,
    required bool isDark,
  }) {
    JournalModel? matching;
    for (final j in journals) {
      if (j.scheduleId == warning.scheduleId && j.status != 'rejected') {
        matching = j;
        break;
      }
    }
    // Kalau hanya ada versi rejected, tetap tampilkan agar bisa revisi.
    if (matching == null) {
      for (final j in journals) {
        if (j.scheduleId == warning.scheduleId) {
          matching = j;
          break;
        }
      }
    }
    final JournalModel? resolvedMatching = matching;

    return InkWell(
      onTap: () async {
        Navigator.pop(sheetContext);
        if (!mounted) return;
        if (resolvedMatching != null && resolvedMatching.status != 'rejected') {
          await context.push('/guru/journal/${resolvedMatching.id}');
        } else if (resolvedMatching != null && resolvedMatching.status == 'rejected') {
          await context.push(
            '/guru/journal-form?scheduleId=${warning.scheduleId}&journalId=${resolvedMatching.id}&date=$dateStr',
          );
        } else {
          await context.push(
            '/guru/journal-form?scheduleId=${warning.scheduleId}&date=$dateStr',
          );
        }
        if (mounted) await _loadData();
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatReason(warning.reason),
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.5.sp,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: resolvedMatching == null
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    resolvedMatching == null ? 'Isi Jurnal' : 'Lihat Jurnal',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w700,
                      color: resolvedMatching == null ? Colors.white : const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  side: BorderSide(
                                    color: hasUnread
                                        ? const Color(0xFFFECACA)
                                        : theme.colorScheme.outlineVariant,
                                    width: hasUnread ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () => _openDayJournals(
                                        groupDate: groupDate,
                                        groupWarnings: groupWarnings,
                                      ),
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                                      child: Padding(
                                        padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 12.w),
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
                                          ],
                                        ),
                                      ),
                                    ),
                                      if (hasUnread)
                                        Padding(
                                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.w),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
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
                                          ),
                                        ),
                                    ],
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
