import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/journal_model.dart';
import '../../models/teacher_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/admin_drawer.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/state_widgets.dart';

enum StatTimeFilter {
  last30Days,
  thisMonth,
  lastMonth,
  thisSemester,
  lastSemester,
  thisYear,
  lastYear,
  custom,
  all,
}

class TeacherPunctualityStat {
  final TeacherModel teacher;
  final int totalJournals;
  final int onTimeCount;
  final int lateCount;
  final int unsubmittedCount;
  final int totalSessions; // onTimeCount + lateCount + unsubmittedCount
  final double onTimeRate; // percentage (0 - 100)
  final double averageLateDays;
  final List<JournalModel> lateJournals;
  final List<JournalModel> onTimeJournals;

  TeacherPunctualityStat({
    required this.teacher,
    required this.totalJournals,
    required this.onTimeCount,
    required this.lateCount,
    required this.unsubmittedCount,
    required this.totalSessions,
    required this.onTimeRate,
    required this.averageLateDays,
    required this.lateJournals,
    required this.onTimeJournals,
  });
}

class AdminTeacherStatisticsScreen extends StatefulWidget {
  const AdminTeacherStatisticsScreen({super.key});

  @override
  State<AdminTeacherStatisticsScreen> createState() =>
      _AdminTeacherStatisticsScreenState();
}

class _AdminTeacherStatisticsScreenState
    extends State<AdminTeacherStatisticsScreen> {
  StatTimeFilter _timeFilter = StatTimeFilter.last30Days;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refreshData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentSchoolId = authProvider.activeSchoolId;
    if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
      await Future.wait([
        Provider.of<MasterDataProvider>(
          context,
          listen: false,
        ).loadAllData(currentSchoolId),
        Provider.of<ScheduleProvider>(
          context,
          listen: false,
        ).loadAllSchedules(currentSchoolId),
        Provider.of<JournalProvider>(
          context,
          listen: false,
        ).loadAllJournals(currentSchoolId),
      ]);
    }
  }

  bool _matchesTimeFilter(DateTime date) {
    final now = DateTime.now();
    final checkDate = DateTime(date.year, date.month, date.day);

    switch (_timeFilter) {
      case StatTimeFilter.last30Days:
        final thirtyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
        return !checkDate.isBefore(thirtyDaysAgo) && !checkDate.isAfter(DateTime(now.year, now.month, now.day));

      case StatTimeFilter.thisMonth:
        return date.year == now.year && date.month == now.month;

      case StatTimeFilter.lastMonth:
        final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final lastMonth = now.month == 1 ? 12 : now.month - 1;
        return date.year == lastMonthYear && date.month == lastMonth;

      case StatTimeFilter.thisSemester:
        // Semester Ganjil: Jul - Des, Semester Genap: Jan - Jun
        final isGanjil = now.month >= 7 && now.month <= 12;
        if (isGanjil) {
          return date.year == now.year && date.month >= 7 && date.month <= 12;
        } else {
          return date.year == now.year && date.month >= 1 && date.month <= 6;
        }

      case StatTimeFilter.lastSemester:
        final isGanjil = now.month >= 7 && now.month <= 12;
        if (isGanjil) {
          return date.year == now.year && date.month >= 1 && date.month <= 6;
        } else {
          return date.year == now.year - 1 && date.month >= 7 && date.month <= 12;
        }

      case StatTimeFilter.thisYear:
        return date.year == now.year;

      case StatTimeFilter.lastYear:
        return date.year == now.year - 1;

      case StatTimeFilter.custom:
        if (_customDateRange == null) return true;
        final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
        final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day);
        return !checkDate.isBefore(start) && !checkDate.isAfter(end);

      case StatTimeFilter.all:
        return true;
    }
  }

  int _getDaysDifference(DateTime teachingDate, DateTime? submittedAt) {
    if (submittedAt == null) return 0;
    final teachDay = DateTime(
      teachingDate.year,
      teachingDate.month,
      teachingDate.day,
    );
    final submitDay = DateTime(
      submittedAt.year,
      submittedAt.month,
      submittedAt.day,
    );
    return submitDay.difference(teachDay).inDays;
  }

  List<TeacherPunctualityStat> _calculateStatistics({
    required List<TeacherModel> teachers,
    required List<JournalModel> allJournals,
    required ScheduleProvider scheduleProvider,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final schoolSchedules = scheduleProvider.schedules;

    final List<TeacherPunctualityStat> statsList = [];

    for (final teacher in teachers) {
      // 1. Ambil jurnal guru yang sesuai filter waktu
      final teacherJournals = allJournals.where((j) {
        if (j.teacherId != teacher.id) return false;
        return _matchesTimeFilter(j.date);
      }).toList();

      int onTimeCount = 0;
      int lateCount = 0;
      int totalLateDays = 0;
      final List<JournalModel> lateList = [];
      final List<JournalModel> onTimeList = [];

      for (final j in teacherJournals) {
        final diff = _getDaysDifference(j.date, j.createdAt);
        if (diff <= 0) {
          onTimeCount++;
          onTimeList.add(j);
        } else {
          lateCount++;
          totalLateDays += diff;
          lateList.add(j);
        }
      }

      // Sort late journals by days late descending
      lateList.sort((a, b) {
        final diffA = _getDaysDifference(a.date, a.createdAt);
        final diffB = _getDaysDifference(b.date, b.createdAt);
        return diffB.compareTo(diffA);
      });

      // 2. Hitung sesi jadwal mengajar di masa lampau yang belum diisi jurnal
      int unsubmittedCount = 0;
      final teacherSchedules = schoolSchedules.where((s) {
        if (s.teacherId != teacher.id || !s.isActive) return false;
        final schedDate = DateTime(s.date.year, s.date.month, s.date.day);
        if (schedDate.isAfter(today)) return false; // Abaikan jadwal masa depan
        return _matchesTimeFilter(s.date);
      }).toList();

      for (final s in teacherSchedules) {
        final hasJournal = allJournals.any(
          (j) =>
              j.teacherId == teacher.id &&
              j.scheduleId == s.id &&
              j.date.year == s.date.year &&
              j.date.month == s.date.month &&
              j.date.day == s.date.day,
        );
        if (!hasJournal) {
          unsubmittedCount++;
        }
      }

      final totalJournals = onTimeCount + lateCount;
      final totalSessions = totalJournals + unsubmittedCount;

      double onTimeRate = 0.0;
      if (totalSessions > 0) {
        onTimeRate = (onTimeCount / totalSessions) * 100.0;
      } else if (totalJournals > 0) {
        onTimeRate = (onTimeCount / totalJournals) * 100.0;
      }

      final double avgLateDays = lateCount > 0
          ? (totalLateDays / lateCount)
          : 0.0;

      statsList.add(
        TeacherPunctualityStat(
          teacher: teacher,
          totalJournals: totalJournals,
          onTimeCount: onTimeCount,
          lateCount: lateCount,
          unsubmittedCount: unsubmittedCount,
          totalSessions: totalSessions,
          onTimeRate: onTimeRate,
          averageLateDays: avgLateDays,
          lateJournals: lateList,
          onTimeJournals: onTimeList,
        ),
      );
    }

    return statsList;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color.fromARGB(255, 37, 99, 235);
    final surfaceColor =
        Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    final teachers = masterProvider.teachers;
    final schoolJournals = journalProvider.journals;
    final isLoading =
        masterProvider.isLoading ||
        scheduleProvider.isLoading ||
        journalProvider.isLoading;
    final loadError =
        masterProvider.errorMessage ??
        scheduleProvider.errorMessage ??
        journalProvider.errorMessage;

    final allStats = _calculateStatistics(
      teachers: teachers,
      allJournals: schoolJournals,
      scheduleProvider: scheduleProvider,
    );

    // Peringkat Guru Paling Tepat Waktu (Leaderboard)
    final topOnTimeTeachers =
        allStats.where((s) => s.totalJournals > 0).toList()..sort((a, b) {
          if (b.onTimeRate != a.onTimeRate) {
            return b.onTimeRate.compareTo(a.onTimeRate);
          }
          if (b.onTimeCount != a.onTimeCount) {
            return b.onTimeCount.compareTo(a.onTimeCount);
          }
          return a.lateCount.compareTo(b.lateCount);
        });

    // Peringkat Guru Paling Sering Terlambat / Ada Tunggakan
    final topLateTeachers =
        allStats
            .where((s) => s.lateCount > 0 || s.unsubmittedCount > 0)
            .toList()
          ..sort((a, b) {
            final penaltyA =
                (a.lateCount * 2) +
                (a.unsubmittedCount * 3) +
                a.averageLateDays.toInt();
            final penaltyB =
                (b.lateCount * 2) +
                (b.unsubmittedCount * 3) +
                b.averageLateDays.toInt();
            return penaltyB.compareTo(penaltyA);
          });

    // Agregat Keseluruhan Sekolah
    final totalSchoolJournals = allStats.fold<int>(
      0,
      (sum, s) => sum + s.totalJournals,
    );
    final totalSchoolOnTime = allStats.fold<int>(
      0,
      (sum, s) => sum + s.onTimeCount,
    );
    final totalSchoolLate = allStats.fold<int>(
      0,
      (sum, s) => sum + s.lateCount,
    );
    final totalSchoolUnsubmitted = allStats.fold<int>(
      0,
      (sum, s) => sum + s.unsubmittedCount,
    );
    final totalSchoolSessions = totalSchoolJournals + totalSchoolUnsubmitted;
    final schoolPunctualityRate = totalSchoolSessions > 0
        ? ((totalSchoolOnTime / totalSchoolSessions) * 100.0)
        : (totalSchoolJournals > 0
              ? ((totalSchoolOnTime / totalSchoolJournals) * 100.0)
              : 0.0);

    return AppScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Statistik Guru',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: kIsWeb ? 17 : 18.sp,
          ),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/teacher-statistics'),
      body: isLoading && teachers.isEmpty
          ? const AppLoadingWidget(message: 'Memuat statistik guru...')
          : loadError != null && teachers.isEmpty
          ? AppErrorWidget(message: loadError, onRetry: _refreshData)
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: kIsWeb ? 24.w : 16.w,
                  vertical: 16.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Banner sekolah dan filter waktu
                    _buildHeaderSection(
                      context,
                      authProvider,
                      isDark,
                      primaryColor,
                      surfaceColor,
                      borderColor,
                    ),
                    SizedBox(height: 16.h),

                    // Ringkasan disiplin sekolah
                    _buildKpiSection(
                      context,
                      isDark,
                      teachersCount: teachers.length,
                      onTimeRate: schoolPunctualityRate,
                      totalOnTime: totalSchoolOnTime,
                      totalLate: totalSchoolLate,
                      totalUnsubmitted: totalSchoolUnsubmitted,
                    ),
                    SizedBox(height: 20.h),

                    // Papan peringkat Top 10 tepat waktu dan perlu perhatian
                    _buildHighlightsSection(
                      context,
                      isDark,
                      topOnTimeTeachers: topOnTimeTeachers.take(10).toList(),
                      topLateTeachers: topLateTeachers.take(10).toList(),
                    ),
                    SizedBox(height: 36.h),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF2563EB),
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _timeFilter = StatTimeFilter.custom;
      });
    }
  }

  // Header dan filter rentang waktu
  Widget _buildHeaderSection(
    BuildContext context,
    AuthProvider authProvider,
    bool isDark,
    Color primaryColor,
    Color surfaceColor,
    Color borderColor,
  ) {
    final schoolName = authProvider.activeSchoolName.isNotEmpty
        ? authProvider.activeSchoolName
        : 'Sekolah';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schoolName,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 10.h),
          Text(
            'Periode',
            style: TextStyle(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildTimeFilterChip(
                  '30 Hari Terakhir',
                  StatTimeFilter.last30Days,
                  isDark,
                  primaryColor,
                ),
                SizedBox(width: 6.w),
                _buildTimeFilterChip(
                  'Bulan Ini',
                  StatTimeFilter.thisMonth,
                  isDark,
                  primaryColor,
                ),
                SizedBox(width: 6.w),
                _buildTimeFilterChip(
                  'Bulan Lalu',
                  StatTimeFilter.lastMonth,
                  isDark,
                  primaryColor,
                ),
                SizedBox(width: 6.w),
                _buildTimeFilterChip(
                  'Semester Ini',
                  StatTimeFilter.thisSemester,
                  isDark,
                  primaryColor,
                ),
                SizedBox(width: 6.w),
                _buildTimeFilterChip(
                  'Semester Lalu',
                  StatTimeFilter.lastSemester,
                  isDark,
                  primaryColor,
                ),
                SizedBox(width: 6.w),
                _buildTimeFilterChip(
                  'Tahun Ini',
                  StatTimeFilter.thisYear,
                  isDark,
                  primaryColor,
                ),
                SizedBox(width: 6.w),
                _buildTimeFilterChip(
                  'Tahun Lalu',
                  StatTimeFilter.lastYear,
                  isDark,
                  primaryColor,
                ),
                SizedBox(width: 6.w),
                _buildCustomDateFilterChip(isDark, primaryColor),
                SizedBox(width: 6.w),
                _buildTimeFilterChip(
                  'Semua',
                  StatTimeFilter.all,
                  isDark,
                  primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDateFilterChip(bool isDark, Color primaryColor) {
    final isSelected = _timeFilter == StatTimeFilter.custom;
    final label = isSelected && _customDateRange != null
        ? '${DateFormat("dd/MM").format(_customDateRange!.start)} - ${DateFormat("dd/MM").format(_customDateRange!.end)}'
        : 'Pilih Tanggal';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickCustomDateRange,
        borderRadius: BorderRadius.circular(9.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          constraints: BoxConstraints(minHeight: 36.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9.r),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFFCBD5E1)),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 14.r,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
              ),
              SizedBox(width: 5.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeFilterChip(
    String label,
    StatTimeFilter filter,
    bool isDark,
    Color primaryColor,
  ) {
    final isSelected = _timeFilter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _timeFilter = filter),
        borderRadius: BorderRadius.circular(9.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          constraints: BoxConstraints(minHeight: 36.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9.r),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : const Color(0xFFCBD5E1)),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  // Ringkasan angka disiplin: hero rate plus tiga hitungan pendukung
  Widget _buildKpiSection(
    BuildContext context,
    bool isDark, {
    required int teachersCount,
    required double onTimeRate,
    required int totalOnTime,
    required int totalLate,
    required int totalUnsubmitted,
  }) {
    final disciplineColor = onTimeRate >= 80
        ? const Color(0xFF2563EB)
        : const Color(0xFFD97706);
    final totalFilled = totalOnTime + totalLate;
    final onTimeShare = totalFilled > 0 ? totalOnTime / totalFilled : 0.0;
    final titleColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : const Color(0xFF0F172A);
    final mutedColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF64748B);
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F2537) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark
                  ? disciplineColor.withValues(alpha: 0.35)
                  : disciplineColor.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(9.r),
                    decoration: BoxDecoration(
                      color: disciplineColor.withValues(
                        alpha: isDark ? 0.18 : 0.12,
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.speed_rounded,
                      color: disciplineColor,
                      size: 20.r,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disiplin Sekolah',
                          style: TextStyle(
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          '$totalOnTime dari $totalFilled jurnal tepat',
                          style: TextStyle(fontSize: 11.sp, color: mutedColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '${onTimeRate.toStringAsFixed(1)}%',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                      color: valueColor,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(99.r),
                child: Container(
                  height: 8.h,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.14)
                      : const Color(0xFFE2E8F0),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: onTimeShare.clamp(0.0, 1.0),
                    child: Container(color: disciplineColor),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '$teachersCount guru • periode ini',
                style: TextStyle(fontSize: 11.sp, color: mutedColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        // Tiga indikator tepat/telat/kosong digabung dalam 1 card ringkas
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF15202B) : Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildKpiItem(
                  title: 'Tepat',
                  value: '$totalOnTime',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              Container(
                height: 40.h,
                width: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _buildKpiItem(
                  title: 'Telat',
                  value: '$totalLate',
                  icon: Icons.history_toggle_off_rounded,
                  color: const Color(0xFFD97706),
                  isDark: isDark,
                ),
              ),
              Container(
                height: 40.h,
                width: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0),
              ),
              Expanded(
                child: _buildKpiItem(
                  title: 'Kosong',
                  value: '$totalUnsubmitted',
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFE11D48),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _accessibleTextColor(Color color) {
    if (color == const Color(0xFFD97706)) return const Color(0xFFB45309);
    if (color == const Color(0xFF2563EB)) return const Color(0xFF1E40AF);
    if (color == const Color(0xFFE11D48)) return const Color(0xFFBE123C);
    return color;
  }

  Widget _buildKpiItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Icon card badge
        Container(
          padding: EdgeInsets.all(6.r),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 16.r),
        ),
        SizedBox(height: 6.h),

        // 2. Teks judul singkat
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: _accessibleTextColor(color),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4.h),

        // 3. Baru angkanya
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              height: 1.0,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  // Papan peringkat tepat waktu dan perlu perhatian
  Widget _buildHighlightsSection(
    BuildContext context,
    bool isDark, {
    required List<TeacherPunctualityStat> topOnTimeTeachers,
    required List<TeacherPunctualityStat> topLateTeachers,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTopOnTimeCard(context, isDark, topOnTimeTeachers),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: _buildTopLateCard(context, isDark, topLateTeachers),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildTopOnTimeCard(context, isDark, topOnTimeTeachers),
            SizedBox(height: 16.h),
            _buildTopLateCard(context, isDark, topLateTeachers),
          ],
        );
      },
    );
  }

  // Kartu Guru Paling Tepat Waktu (Leaderboard)
  Widget _buildTopOnTimeCard(
    BuildContext context,
    bool isDark,
    List<TeacherPunctualityStat> teachers,
  ) {
    const headerColor = Color(0xFF2563EB);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: headerColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 10 Paling Tepat Waktu',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.bold,
                        color: headerColor,
                      ),
                    ),
                    Text(
                      'Guru paling disiplin mengisi jurnal',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          const Divider(height: 1),
          SizedBox(height: 10.h),
          if (teachers.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: Text(
                  'Belum ada data jurnal pada periode ini',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Column(
              children: teachers.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final stat = entry.value;
                return _buildTopTeacherItem(
                  context,
                  rank: rank,
                  stat: stat,
                  isDark: isDark,
                  isPositive: true,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // Kartu Guru Paling Sering Terlambat
  Widget _buildTopLateCard(
    BuildContext context,
    bool isDark,
    List<TeacherPunctualityStat> teachers,
  ) {
    const headerColor = Color(0xFFD97706);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: headerColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: headerColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top 10 Perlu Perhatian',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                    Text(
                      'Perlu perhatian kedisiplinan',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          const Divider(height: 1),
          SizedBox(height: 10.h),
          if (teachers.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF2563EB),
                      size: 18,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Bagus! Tidak ada guru yang terlambat',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: teachers.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final stat = entry.value;
                return _buildTopTeacherItem(
                  context,
                  rank: rank,
                  stat: stat,
                  isDark: isDark,
                  isPositive: false,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTopTeacherItem(
    BuildContext context, {
    required int rank,
    required TeacherPunctualityStat stat,
    required bool isDark,
    required bool isPositive,
  }) {
    Color medalColor;
    if (isPositive) {
      if (rank == 1) {
        medalColor = const Color(0xFFD97706);
      } else if (rank == 2) {
        medalColor = const Color(0xFF94A3B8);
      } else {
        medalColor = const Color(0xFFD97706);
      }
    } else {
      medalColor = rank == 1
          ? const Color(0xFFE11D48)
          : const Color(0xFFD97706);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30.r,
            height: 30.r,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: medalColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.teacher.name,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  stat.teacher.position,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
