import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/utils/helper.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../models/class_model.dart';
import '../../models/journal_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';

class GuruJadwalBulanIniScreen extends StatefulWidget {
  final DateTime? initialMonth;

  const GuruJadwalBulanIniScreen({
    super.key,
    this.initialMonth,
  });

  @override
  State<GuruJadwalBulanIniScreen> createState() => _GuruJadwalBulanIniScreenState();
}

class _GuruJadwalBulanIniScreenState extends State<GuruJadwalBulanIniScreen> {
  late DateTime _currentMonth;
  String _selectedFilter = 'all'; // 'all', 'unfilled', 'filled'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = widget.initialMonth ?? DateTime(now.year, now.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);

      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        final teacher = masterProvider.teachers.firstWhere(
          (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
          orElse: () => TeacherModel(
            id: currentUser.id,
            name: currentUser.fullName,
            position: 'Guru',
            address: '',
            phoneNumber: '',
            email: currentUser.email,
          ),
        );

        if (teacher.id.isNotEmpty) {
          final schoolId = authProvider.activeSchoolId;
          scheduleProvider.setSchoolId(schoolId);
          journalProvider.setSchoolId(schoolId);
          await Future.wait([
            scheduleProvider.loadTeacherSchedules(teacher.id, _currentMonth),
            journalProvider.loadTeacherJournals(teacher.id),
          ]);
        }
      }
    } catch (_) {
      // Keep existing cache if network fails
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeMonth(int monthDelta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + monthDelta, 1);
    });
    _loadData();
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month, 1);
    });
    _loadData();
  }

  JournalModel? _findMatchingJournal(
    GroupedDailySchedule group,
    List<JournalModel> journals,
  ) {
    final s = group.primarySchedule;
    for (final j in journals) {
      final sameDate = j.date.year == group.date.year &&
          j.date.month == group.date.month &&
          j.date.day == group.date.day;
      final sameSchedule = j.scheduleId == s.id ||
          group.scheduleIds.contains(j.scheduleId) ||
          (j.classId == s.classId && j.subjectId == s.subjectId);
      if (sameDate && sameSchedule) {
        return j;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final masterProvider = context.watch<MasterDataProvider>();

    final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(authProvider.activeSchoolId) ??
        authProvider.activeSchoolId?.trim();

    // Filter schedules active in this month & for active school
    final activeSchedulesThisMonth = scheduleProvider.cachedTeacherSchedules.where((s) {
      if (!s.isActive) return false;
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final sSchoolId = AppHelper.parseSingleCleanSchoolId(s.schoolId) ?? s.schoolId?.trim();
        if (sSchoolId != null && sSchoolId.isNotEmpty && sSchoolId != cleanActiveSchoolId) {
          return false;
        }
      }
      return s.date.year == _currentMonth.year && s.date.month == _currentMonth.month;
    }).toList();

    // Group the schedules by date, class, and subject session
    final groupedMonthSchedules = groupDailySchedules(activeSchedulesThisMonth);

    // Calculate filled vs unfilled
    int filledCount = 0;
    int unfilledCount = 0;
    for (final group in groupedMonthSchedules) {
      final j = _findMatchingJournal(group, journalProvider.teacherJournals);
      if (j != null) {
        filledCount++;
      } else {
        unfilledCount++;
      }
    }
    final totalCount = groupedMonthSchedules.length;

    // Filter by tab selection & search query
    final filteredSchedules = groupedMonthSchedules.where((group) {
      final j = _findMatchingJournal(group, journalProvider.teacherJournals);
      final isFilled = j != null;

      if (_selectedFilter == 'unfilled' && isFilled) return false;
      if (_selectedFilter == 'filled' && !isFilled) return false;

      if (_searchQuery.isNotEmpty) {
        final cls = masterProvider.classes.firstWhere(
          (c) => c.id == group.classId,
          orElse: () => ClassModel(id: '', name: '', periodId: '', studentCount: 0),
        );
        final subject = masterProvider.subjects.firstWhere(
          (s) => s.id == group.subjectId,
          orElse: () => SubjectModel(id: '', name: '', isActive: false),
        );

        final matchesClass = cls.name.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesSubject = subject.name.toLowerCase().contains(_searchQuery.toLowerCase());
        if (!matchesClass && !matchesSubject) {
          return false;
        }
      }

      return true;
    }).toList()
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        final hA = a.teachingHours.isNotEmpty ? a.teachingHours.first : 0;
        final hB = b.teachingHours.isNotEmpty ? b.teachingHours.first : 0;
        return hA.compareTo(hB);
      });

    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;
    final monthTitle = DateFormat('MMMM yyyy', 'id_ID').format(_currentMonth);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali ke Dashboard',
        ),
        title: Text(
          'Jadwal Mengajar Bulan Ini',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (!isCurrentMonth)
            TextButton.icon(
              onPressed: _resetToCurrentMonth,
              icon: Icon(Icons.today_rounded, size: 16.sp, color: const Color(0xFF4F7CFF)),
              label: Text(
                'Bulan Ini',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF4F7CFF),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: _loadData,
          ),
          SizedBox(width: 6.w),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF4F7CFF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Month Selector Banner ──────────────────────────────────
              _buildMonthNavigator(monthTitle, isDark),

              SizedBox(height: 14.h),

              // ── Summary Cards (Total, Belum Diisi, Sudah Terisi) ───────
              _buildMetricCards(totalCount, unfilledCount, filledCount, isDark),

              SizedBox(height: 16.h),

              // ── Search & Filter Chips ──────────────────────────────────
              _buildSearchAndFilters(totalCount, unfilledCount, filledCount, isDark),

              SizedBox(height: 16.h),

              // ── Schedule List / Empty State ────────────────────────────
              if (_isLoading && groupedMonthSchedules.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.h),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F7CFF)),
                  ),
                )
              else if (filteredSchedules.isEmpty)
                _buildEmptyState(isDark)
              else
                Column(
                  children: [
                    for (int i = 0; i < filteredSchedules.length; i++) ...[
                      _buildScheduleCard(
                        context: context,
                        group: filteredSchedules[i],
                        matchingJournal: _findMatchingJournal(
                          filteredSchedules[i],
                          journalProvider.teacherJournals,
                        ),
                        master: masterProvider,
                        isDark: isDark,
                      ),
                      if (i < filteredSchedules.length - 1)
                        SizedBox(height: 12.h),
                    ],
                  ],
                ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(String monthTitle, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => _changeMonth(-1),
            tooltip: 'Bulan Sebelumnya',
            color: Theme.of(context).colorScheme.onSurface,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 20.sp,
                color: const Color(0xFF4F7CFF),
              ),
              SizedBox(width: 8.w),
              Text(
                monthTitle,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _changeMonth(1),
            tooltip: 'Bulan Berikutnya',
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards(int total, int unfilled, int filled, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricTile(
            label: 'Total Jadwal',
            count: total,
            icon: Icons.calendar_today_rounded,
            color: const Color(0xFF4F7CFF),
            isDark: isDark,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildMetricTile(
            label: 'Belum Diisi',
            count: unfilled,
            icon: Icons.pending_actions_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _buildMetricTile(
            label: 'Sudah Terisi',
            count: filled,
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Icon(icon, size: 16.sp, color: color),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(int total, int unfilled, int filled, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search TextField
        TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          decoration: InputDecoration(
            hintText: 'Cari mata pelajaran atau kelas...',
            hintStyle: GoogleFonts.hankenGrotesk(
              fontSize: 12.5.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(
                color: Color(0xFF4F7CFF),
                width: 1.5,
              ),
            ),
          ),
        ),

        SizedBox(height: 12.h),

        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('all', 'Semua ($total)', isDark),
              SizedBox(width: 8.w),
              _buildFilterChip('unfilled', 'Belum Diisi ($unfilled)', isDark, color: const Color(0xFFF59E0B)),
              SizedBox(width: 8.w),
              _buildFilterChip('filled', 'Sudah Terisi ($filled)', isDark, color: const Color(0xFF10B981)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label, bool isDark, {Color? color}) {
    final isSelected = _selectedFilter == key;
    final activeColor = color ?? const Color(0xFF4F7CFF);

    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 12.sp,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard({
    required BuildContext context,
    required GroupedDailySchedule group,
    required JournalModel? matchingJournal,
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

    final matchedHours = master.hours
        .where((h) => group.teachingHours.contains(h.teachingHour))
        .toList()
      ..sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

    final hrStart = matchedHours.isNotEmpty ? matchedHours.first.startTime : '';
    final hrEnd = matchedHours.isNotEmpty ? matchedHours.last.endTime : '';
    final timeStr = hrStart.isNotEmpty
        ? (hrEnd.isNotEmpty ? '$hrStart - $hrEnd WIB' : '$hrStart WIB')
        : '';
    final hoursStr = AppHelper.formatTeachingHours(group.teachingHours);
    final dateFormatted = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(group.date);

    final isFilled = matchingJournal != null;
    Color statusBg;
    Color statusText;
    String statusTitle;
    IconData statusIcon;

    if (isFilled) {
      if (matchingJournal.isTeacherAbsence) {
        if (matchingJournal.status == 'verified') {
          statusBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12);
          statusText = const Color(0xFF10B981);
          statusTitle = matchingJournal.isTeacherSick ? 'Sakit (Disetujui)' : 'Izin (Disetujui)';
          statusIcon = Icons.check_circle_rounded;
        } else if (matchingJournal.status == 'rejected') {
          statusBg = Colors.red.withValues(alpha: isDark ? 0.2 : 0.12);
          statusText = Colors.red;
          statusTitle = 'Surat Ditolak';
          statusIcon = Icons.cancel_rounded;
        } else {
          statusBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12);
          statusText = const Color(0xFFF59E0B);
          statusTitle = matchingJournal.isTeacherSick ? 'Sakit (Menunggu)' : 'Izin (Menunggu)';
          statusIcon = Icons.access_time_rounded;
        }
      } else if (matchingJournal.status == 'verified') {
        statusBg = const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.12);
        statusText = const Color(0xFF10B981);
        statusTitle = 'Sudah Diisi (Disetujui)';
        statusIcon = Icons.check_circle_rounded;
      } else if (matchingJournal.status == 'rejected') {
        statusBg = Colors.red.withValues(alpha: isDark ? 0.2 : 0.12);
        statusText = Colors.red;
        statusTitle = 'Perlu Revisi';
        statusIcon = Icons.error_rounded;
      } else {
        statusBg = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.12);
        statusText = const Color(0xFF3B82F6);
        statusTitle = 'Sudah Diisi (Menunggu)';
        statusIcon = Icons.hourglass_top_rounded;
      }
    } else {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12);
      statusText = const Color(0xFFF59E0B);
      statusTitle = 'Belum Diisi';
      statusIcon = Icons.pending_actions_rounded;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(group.date);

    return InkWell(
      onTap: () async {
        if (matchingJournal != null) {
          if (matchingJournal.status == 'rejected') {
            await context.push('/guru/journal-form?scheduleId=${schedule.id}&journalId=${matchingJournal.id}&date=$dateStr');
          } else {
            await context.push('/guru/journal/${matchingJournal.id}');
          }
        } else {
          await context.push('/guru/journal-form?scheduleId=${schedule.id}&date=$dateStr');
        }
        if (mounted) {
          _loadData();
        }
      },
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Date Pill & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 15.sp,
                      color: const Color(0xFF4F7CFF),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      dateFormatted,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12.sp, color: statusText),
                      SizedBox(width: 4.w),
                      Text(
                        statusTitle,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w800,
                          color: statusText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            // Subject Title
            Text(
              subject.name,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),

            SizedBox(height: 8.h),

            // Class and Hours Info Row
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                // Class Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F7CFF).withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 13.sp, color: const Color(0xFF4F7CFF)),
                      SizedBox(width: 4.w),
                      Text(
                        cls.name,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF4F7CFF),
                        ),
                      ),
                    ],
                  ),
                ),

                // Teaching Hours Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'Jam Ke $hoursStr${timeStr.isNotEmpty ? ' ($timeStr)' : ''}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Bottom Action Divider & Button
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            SizedBox(height: 10.h),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isFilled)
                  InkWell(
                    onTap: () async {
                      if (matchingJournal.status == 'rejected') {
                        await context.push('/guru/journal-form?scheduleId=${schedule.id}&journalId=${matchingJournal.id}&date=$dateStr');
                      } else {
                        await context.push('/guru/journal/${matchingJournal.id}');
                      }
                      if (mounted) _loadData();
                    },
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: (matchingJournal.status == 'rejected' ? Colors.red : const Color(0xFF4F7CFF)).withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            matchingJournal.status == 'rejected' ? Icons.edit_note_rounded : Icons.visibility_rounded,
                            size: 15.sp,
                            color: matchingJournal.status == 'rejected' ? Colors.red : const Color(0xFF4F7CFF),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            matchingJournal.status == 'rejected' ? 'Revisi Jurnal' : 'Lihat Jurnal',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: matchingJournal.status == 'rejected' ? Colors.red : const Color(0xFF4F7CFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () async {
                      await context.push('/guru/journal-form?scheduleId=${schedule.id}&date=$dateStr');
                      if (mounted) _loadData();
                    },
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F7CFF),
                        borderRadius: BorderRadius.circular(8.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F7CFF).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_task_rounded, size: 15.sp, color: Colors.white),
                          SizedBox(width: 6.w),
                          Text(
                            'Isi Jurnal',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
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

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 48.sp,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          SizedBox(height: 12.h),
          Text(
            _searchQuery.isNotEmpty
                ? 'Tidak ada jadwal yang cocok dengan "$_searchQuery"'
                : (_selectedFilter == 'unfilled'
                    ? 'Luar biasa! Semua jadwal di bulan ini telah diisi.'
                    : 'Tidak ada jadwal mengajar pada filter ini.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Gunakan tombol navigasi bulan di atas untuk memeriksa bulan lain.',
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
