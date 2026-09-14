import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/utils/helper.dart';
import '../../models/journal_model.dart';
import '../../models/teacher_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../widgets/admin_drawer.dart';

enum StatTimeFilter { all, thisMonth, thisSemester }
enum TeacherFilterCategory { all, onTime, lateOnly, unsubmittedOnly }

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
  State<AdminTeacherStatisticsScreen> createState() => _AdminTeacherStatisticsScreenState();
}

class _AdminTeacherStatisticsScreenState extends State<AdminTeacherStatisticsScreen> {
  final TextEditingController _searchController = TextEditingController();
  StatTimeFilter _timeFilter = StatTimeFilter.all;
  TeacherFilterCategory _categoryFilter = TeacherFilterCategory.all;
  String _searchQuery = '';
  final Set<String> _expandedTeacherIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentSchoolId = authProvider.activeSchoolId;
    if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
      await Future.wait([
        Provider.of<MasterDataProvider>(context, listen: false).loadAllData(currentSchoolId),
        Provider.of<ScheduleProvider>(context, listen: false).loadAllSchedules(currentSchoolId),
        Provider.of<JournalProvider>(context, listen: false).loadAllJournals(currentSchoolId),
      ]);
    }
  }

  bool _matchesTimeFilter(DateTime date) {
    final now = DateTime.now();
    switch (_timeFilter) {
      case StatTimeFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case StatTimeFilter.thisSemester:
        // Semester Ganjil: Jul - Des, Semester Genap: Jan - Jun
        final isGanjil = now.month >= 7 && now.month <= 12;
        if (isGanjil) {
          return date.year == now.year && date.month >= 7 && date.month <= 12;
        } else {
          return date.year == now.year && date.month >= 1 && date.month <= 6;
        }
      case StatTimeFilter.all:
        return true;
    }
  }

  int _getDaysDifference(DateTime teachingDate, DateTime? submittedAt) {
    if (submittedAt == null) return 0;
    final teachDay = DateTime(teachingDate.year, teachingDate.month, teachingDate.day);
    final submitDay = DateTime(submittedAt.year, submittedAt.month, submittedAt.day);
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
        final hasJournal = allJournals.any((j) =>
            j.teacherId == teacher.id &&
            j.scheduleId == s.id &&
            j.date.year == s.date.year &&
            j.date.month == s.date.month &&
            j.date.day == s.date.day);
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

      final double avgLateDays = lateCount > 0 ? (totalLateDays / lateCount) : 0.0;

      statsList.add(TeacherPunctualityStat(
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
      ));
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
    final surfaceColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    final teachers = masterProvider.teachers;
    final schoolJournals = journalProvider.journals;

    final allStats = _calculateStatistics(
      teachers: teachers,
      allJournals: schoolJournals,
      scheduleProvider: scheduleProvider,
    );

    // Filter berdasarkan kategori
    List<TeacherPunctualityStat> filteredStats = allStats.where((s) {
      if (_searchQuery.isNotEmpty) {
        final matchesName = s.teacher.name.toLowerCase().contains(_searchQuery);
        final matchesPos = s.teacher.position.toLowerCase().contains(_searchQuery);
        if (!matchesName && !matchesPos) return false;
      }

      switch (_categoryFilter) {
        case TeacherFilterCategory.onTime:
          return s.onTimeRate >= 80.0 && s.totalJournals > 0;
        case TeacherFilterCategory.lateOnly:
          return s.lateCount > 0;
        case TeacherFilterCategory.unsubmittedOnly:
          return s.unsubmittedCount > 0;
        case TeacherFilterCategory.all:
          return true;
      }
    }).toList();

    // Urutkan default: Guru yang memiliki aktivitas jurnal & jadwal di atas
    filteredStats.sort((a, b) {
      if (a.totalSessions != b.totalSessions) {
        return b.totalSessions.compareTo(a.totalSessions);
      }
      return a.teacher.name.compareTo(b.teacher.name);
    });

    // Peringkat Guru Paling Tepat Waktu (Leaderboard)
    final topOnTimeTeachers = allStats.where((s) => s.totalJournals > 0).toList()
      ..sort((a, b) {
        if (b.onTimeRate != a.onTimeRate) {
          return b.onTimeRate.compareTo(a.onTimeRate);
        }
        if (b.onTimeCount != a.onTimeCount) {
          return b.onTimeCount.compareTo(a.onTimeCount);
        }
        return a.lateCount.compareTo(b.lateCount);
      });

    // Peringkat Guru Paling Sering Terlambat / Ada Tunggakan
    final topLateTeachers = allStats.where((s) => s.lateCount > 0 || s.unsubmittedCount > 0).toList()
      ..sort((a, b) {
        final penaltyA = (a.lateCount * 2) + (a.unsubmittedCount * 3) + a.averageLateDays.toInt();
        final penaltyB = (b.lateCount * 2) + (b.unsubmittedCount * 3) + b.averageLateDays.toInt();
        return penaltyB.compareTo(penaltyA);
      });

    // Agregat Keseluruhan Sekolah
    final totalSchoolJournals = allStats.fold<int>(0, (sum, s) => sum + s.totalJournals);
    final totalSchoolOnTime = allStats.fold<int>(0, (sum, s) => sum + s.onTimeCount);
    final totalSchoolLate = allStats.fold<int>(0, (sum, s) => sum + s.lateCount);
    final totalSchoolUnsubmitted = allStats.fold<int>(0, (sum, s) => sum + s.unsubmittedCount);
    final totalSchoolSessions = totalSchoolJournals + totalSchoolUnsubmitted;
    final schoolPunctualityRate = totalSchoolSessions > 0
        ? ((totalSchoolOnTime / totalSchoolSessions) * 100.0)
        : (totalSchoolJournals > 0 ? ((totalSchoolOnTime / totalSchoolJournals) * 100.0) : 0.0);

    final isLoading = masterProvider.isLoading || journalProvider.isLoading || scheduleProvider.isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Statistik & Disiplin Guru',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: kIsWeb ? 17 : 18.sp,
          ),
        ),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: isLoading ? null : _refreshData,
          ),
          SizedBox(width: 8.w),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/teacher-statistics'),
      body: RefreshIndicator(
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
              // 1. Time Filter Bar & School Banner
              _buildHeaderSection(context, authProvider, isDark, primaryColor, surfaceColor, borderColor),
              SizedBox(height: 16.h),

              // 2. KPI Summary Cards
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

              // 3. Highlighted Dual Section: Paling Tepat Waktu vs Paling Sering Telat
              _buildHighlightsSection(
                context,
                isDark,
                topOnTimeTeachers: topOnTimeTeachers.take(3).toList(),
                topLateTeachers: topLateTeachers.take(3).toList(),
              ),
              SizedBox(height: 24.h),

              // 4. Daftar & Pencarian Seluruh Guru
              _buildTeacherListSection(
                context,
                isDark,
                primaryColor,
                surfaceColor,
                borderColor,
                stats: filteredStats,
                totalCount: allStats.length,
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header & Time Filter ──────────────────────────────────────────────────
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(Icons.analytics_rounded, color: primaryColor, size: 24.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pemantauan Kedisiplinan Guru',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      schoolName,
                      style: TextStyle(
                        fontSize: 12.5.sp,
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
          SizedBox(height: 14.h),
          const Divider(height: 1),
          SizedBox(height: 12.h),
          Row(
            children: [
              Text(
                'Rentang Waktu:',
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 6.h,
                  children: [
                    _buildTimeFilterChip('Semua Waktu', StatTimeFilter.all, isDark, primaryColor),
                    _buildTimeFilterChip('Bulan Ini', StatTimeFilter.thisMonth, isDark, primaryColor),
                    _buildTimeFilterChip('Semester Ini', StatTimeFilter.thisSemester, isDark, primaryColor),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterChip(String label, StatTimeFilter filter, bool isDark, Color primaryColor) {
    final isSelected = _timeFilter == filter;
    return InkWell(
      onTap: () => setState(() => _timeFilter = filter),
      borderRadius: BorderRadius.circular(10.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.grey[800] : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // ── KPI Summary Cards ─────────────────────────────────────────────────────
  Widget _buildKpiSection(
    BuildContext context,
    bool isDark, {
    required int teachersCount,
    required double onTimeRate,
    required int totalOnTime,
    required int totalLate,
    required int totalUnsubmitted,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        return Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: [
            SizedBox(
              width: isNarrow ? (constraints.maxWidth - 12.w) / 2 : (constraints.maxWidth - 36.w) / 4,
              child: _buildKpiCard(
                title: 'Tingkat Disiplin',
                value: '${onTimeRate.toStringAsFixed(1)}%',
                subtitle: '$totalOnTime dari ${totalOnTime + totalLate} jurnal',
                icon: Icons.speed_rounded,
                color: onTimeRate >= 80 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: isNarrow ? (constraints.maxWidth - 12.w) / 2 : (constraints.maxWidth - 36.w) / 4,
              child: _buildKpiCard(
                title: 'Tepat Waktu',
                value: '$totalOnTime',
                subtitle: 'Diisi pada hari H',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: isNarrow ? (constraints.maxWidth - 12.w) / 2 : (constraints.maxWidth - 36.w) / 4,
              child: _buildKpiCard(
                title: 'Terlambat',
                value: '$totalLate',
                subtitle: 'Diisi setelah hari H',
                icon: Icons.history_toggle_off_rounded,
                color: const Color(0xFFF59E0B),
                isDark: isDark,
              ),
            ),
            SizedBox(
              width: isNarrow ? (constraints.maxWidth - 12.w) / 2 : (constraints.maxWidth - 36.w) / 4,
              child: _buildKpiCard(
                title: 'Belum Terisi',
                value: '$totalUnsubmitted',
                subtitle: 'Jadwal lampau kosong',
                icon: Icons.warning_amber_rounded,
                color: const Color(0xFFEF4444),
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Icon(icon, color: color, size: 18.r),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5.sp,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Highlighted Sections: Paling Tepat Waktu & Paling Sering Telat ─────────
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
    const headerColor = Color(0xFF10B981); // Emerald Green

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                child: const Icon(Icons.emoji_events_rounded, color: headerColor, size: 20),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paling Sering Tepat Waktu',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.bold,
                        color: headerColor,
                      ),
                    ),
                    Text(
                      'Guru dengan disiplin pengisian terbaik',
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
    const headerColor = Color(0xFFF59E0B); // Amber / Warning

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: headerColor.withValues(alpha: isDark ? 0.1 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
                child: const Icon(Icons.warning_amber_rounded, color: headerColor, size: 20),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paling Sering Terlambat',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14.5.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                    Text(
                      'Perlu perhatian & pembinaan kedisiplinan',
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
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 6.w),
                    Text(
                      'Bagus! Tidak ada guru yang terlambat',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
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
        medalColor = const Color(0xFFF59E0B); // Gold
      } else if (rank == 2) {
        medalColor = const Color(0xFF94A3B8); // Silver
      } else {
        medalColor = const Color(0xFFD97706); // Bronze
      }
    } else {
      medalColor = rank == 1 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 26.r,
            height: 26.r,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: medalColor,
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          // Teacher Info
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
          SizedBox(width: 8.w),
          // Metric Chip
          if (isPositive)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stat.onTimeRate.toStringAsFixed(0)}% Tepat',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  Text(
                    '${stat.onTimeCount} jurnal',
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stat.lateCount}x Telat',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  if (stat.averageLateDays > 0)
                    Text(
                      'Rerata ~${stat.averageLateDays.toStringAsFixed(1)} hr',
                      style: TextStyle(
                        fontSize: 9.5.sp,
                        color: const Color(0xFFB91C1C),
                      ),
                    )
                  else if (stat.unsubmittedCount > 0)
                    Text(
                      '${stat.unsubmittedCount} blm isi',
                      style: TextStyle(
                        fontSize: 9.5.sp,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Daftar Lengkap Seluruh Guru ───────────────────────────────────────────
  Widget _buildTeacherListSection(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    Color surfaceColor,
    Color borderColor, {
    required List<TeacherPunctualityStat> stats,
    required int totalCount,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daftar Statistik Guru ($totalCount)',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),

          // Search Field
          TextField(
            controller: _searchController,
            style: TextStyle(
              fontSize: 13.5.sp,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: 'Cari guru berdasarkan nama atau mapel...',
              hintStyle: TextStyle(
                fontSize: 13.sp,
                color: isDark ? const Color(0xFF64748B) : Colors.grey[400],
              ),
              prefixIcon: Icon(Icons.search, color: primaryColor, size: 20.r),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: isDark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            ),
          ),
          SizedBox(height: 10.h),

          // Category Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryChip('Semua (${stats.length})', TeacherFilterCategory.all, isDark, primaryColor),
                SizedBox(width: 8.w),
                _buildCategoryChip('Tepat Waktu (≥80%)', TeacherFilterCategory.onTime, isDark, const Color(0xFF10B981)),
                SizedBox(width: 8.w),
                _buildCategoryChip('Ada Keterlambatan', TeacherFilterCategory.lateOnly, isDark, const Color(0xFFF59E0B)),
                SizedBox(width: 8.w),
                _buildCategoryChip('Ada Tunggakan', TeacherFilterCategory.unsubmittedOnly, isDark, const Color(0xFFEF4444)),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // List of Teachers
          if (stats.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 36.h),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 40.r,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Tidak ada data guru yang cocok dengan filter',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              separatorBuilder: (context, index) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final stat = stats[index];
                return _buildTeacherCard(context, stat, isDark, primaryColor);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, TeacherFilterCategory category, bool isDark, Color activeColor) {
    final isSelected = _categoryFilter == category;
    return InkWell(
      onTap: () => setState(() => _categoryFilter = category),
      borderRadius: BorderRadius.circular(20.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.18)
              : (isDark ? Colors.grey[800] : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? activeColor
                : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherCard(
    BuildContext context,
    TeacherPunctualityStat stat,
    bool isDark,
    Color primaryColor,
  ) {
    final isExpanded = _expandedTeacherIds.contains(stat.teacher.id);

    // Status Level
    String statusLabel;
    Color statusColor;
    if (stat.totalSessions == 0 && stat.totalJournals == 0) {
      statusLabel = 'Belum Ada Jadwal';
      statusColor = const Color(0xFF64748B);
    } else if (stat.onTimeRate >= 85.0 && stat.unsubmittedCount == 0) {
      statusLabel = 'Sangat Disiplin';
      statusColor = const Color(0xFF10B981);
    } else if (stat.onTimeRate >= 65.0) {
      statusLabel = 'Cukup Disiplin';
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusLabel = 'Perlu Pembinaan';
      statusColor = const Color(0xFFEF4444);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: stat.lateCount > 0 && stat.onTimeRate < 60
              ? const Color(0xFFEF4444).withValues(alpha: 0.25)
              : (isDark ? Colors.grey[800]! : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(14.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, Info & Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20.r,
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      backgroundImage: (stat.teacher.photoUrl != null && stat.teacher.photoUrl!.isNotEmpty)
                          ? NetworkImage(stat.teacher.photoUrl!)
                          : null,
                      child: (stat.teacher.photoUrl == null || stat.teacher.photoUrl!.isEmpty)
                          ? Text(
                              stat.teacher.name.isNotEmpty ? stat.teacher.name[0].toUpperCase() : 'G',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.teacher.name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            stat.teacher.position,
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Progress Bar Kedisiplinan
                if (stat.totalSessions > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: SizedBox(
                      height: 6.h,
                      child: Row(
                        children: [
                          if (stat.onTimeCount > 0)
                            Expanded(
                              flex: stat.onTimeCount,
                              child: Container(color: const Color(0xFF10B981)),
                            ),
                          if (stat.lateCount > 0)
                            Expanded(
                              flex: stat.lateCount,
                              child: Container(color: const Color(0xFFF59E0B)),
                            ),
                          if (stat.unsubmittedCount > 0)
                            Expanded(
                              flex: stat.unsubmittedCount,
                              child: Container(color: const Color(0xFFEF4444)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                ],

                // Detail Metrics Strip
                Row(
                  children: [
                    _buildStatPill('Tepat Waktu', '${stat.onTimeCount}', const Color(0xFF10B981)),
                    SizedBox(width: 8.w),
                    _buildStatPill('Terlambat', '${stat.lateCount}', const Color(0xFFF59E0B)),
                    SizedBox(width: 8.w),
                    _buildStatPill('Belum Diisi', '${stat.unsubmittedCount}', const Color(0xFFEF4444)),
                    const Spacer(),
                    if (stat.lateCount > 0)
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedTeacherIds.remove(stat.teacher.id);
                            } else {
                              _expandedTeacherIds.add(stat.teacher.id);
                            }
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isExpanded ? 'Tutup Rincian' : 'Rincian Telat (${stat.lateCount})',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                              size: 16.r,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Expandable Late Journals List
          if (isExpanded && stat.lateJournals.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(14.r)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Riwayat Keterlambatan Pengisian Jurnal:',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Column(
                    children: stat.lateJournals.map((j) {
                      final diff = _getDaysDifference(j.date, j.createdAt);
                      final teachDateStr = AppHelper.formatDateShort(j.date);
                      final submitDateStr = j.createdAt != null
                          ? AppHelper.formatDateShort(j.createdAt!)
                          : 'Tidak tercatat';

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 3.h),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFF59E0B)),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                'Tgl Mengajar: $teachDateStr  →  Diisi: $submitDateStr',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'Telat $diff hari',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD97706),
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
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.r,
            height: 6.r,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 5.w),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
