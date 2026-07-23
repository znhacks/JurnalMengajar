import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'main_shell.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/journal_model.dart';
import '../../models/schedule_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../widgets/animated_widgets.dart';

class GuruDashboardScreen extends StatefulWidget {
  const GuruDashboardScreen({super.key});

  @override
  State<GuruDashboardScreen> createState() => _GuruDashboardScreenState();
}

class _GuruDashboardScreenState extends State<GuruDashboardScreen> {
  final DateTime _selectedDay = DateTime.now();
  bool _hasCheckedReminder = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeTabFilter = 'Semua'; // 'Semua', 'Belum Diisi', 'Selesai'

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
    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    final scheduleProvider = Provider.of<ScheduleProvider>(
      context,
      listen: false,
    );
    final journalProvider = Provider.of<JournalProvider>(
      context,
      listen: false,
    );

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      await masterProvider.loadAllData();

      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
        orElse: () => TeacherModel(
          id: '',
          name: currentUser.fullName,
          position: currentUser.position ?? 'Guru',
          address: currentUser.address ?? '',
          phoneNumber: currentUser.phoneNumber ?? '',
          email: currentUser.email,
        ),
      );

      if (teacher.id.isNotEmpty) {
        await Future.wait([
          scheduleProvider.loadTeacherSchedules(teacher.id, _selectedDay),
          journalProvider.loadTeacherJournals(teacher.id),
        ]);

        if (!mounted) return;

        // Run Warning Letters Check & Issue if late
        final settingsProvider = Provider.of<SettingsProvider>(
          context,
          listen: false,
        );
        await settingsProvider.loadSettings();
        if (!mounted) return;
        final maxDays = settingsProvider.settings?.maxJournalInputDays ?? 3;

        final warningProvider = Provider.of<WarningLetterProvider>(
          context,
          listen: false,
        );
        await warningProvider.checkAndIssueWarnings(
          schedules: scheduleProvider.cachedTeacherSchedules,
          journals: journalProvider.teacherJournals,
          maxDays: maxDays,
          masterProvider: masterProvider,
        );
        await warningProvider.loadTeacherWarningLetters(teacher.id);

        if (!_hasCheckedReminder) {
          _hasCheckedReminder = true;
          _checkAndShowReminder(
            teacher,
            scheduleProvider,
            journalProvider,
            masterProvider,
          );
        }
      }
    }
  }

  void _checkAndShowReminder(
    TeacherModel teacher,
    ScheduleProvider scheduleProvider,
    JournalProvider journalProvider,
    MasterDataProvider masterProvider,
  ) {
    final today = DateTime.now();
    final activeSchedulesToday = scheduleProvider.cachedTeacherSchedules.where((
      s,
    ) {
      return s.isActive &&
          s.date.year == today.year &&
          s.date.month == today.month &&
          s.date.day == today.day;
    }).toList();

    if (activeSchedulesToday.isEmpty) return;

    final unfinishedSchedules = activeSchedulesToday.where((schedule) {
      return !journalProvider.teacherJournals.any(
        (j) => j.scheduleId == schedule.id,
      );
    }).toList();

    if (unfinishedSchedules.isEmpty) return;

    final Map<String, List<int>> groupedHours = {};
    final Map<String, ScheduleModel> groupedRepresentative = {};
    for (final s in unfinishedSchedules) {
      final key = '${s.classId}|${s.subjectId}';
      groupedHours.putIfAbsent(key, () => []).add(s.teachingHour);
      groupedRepresentative.putIfAbsent(key, () => s);
    }
    for (final k in groupedHours.keys) {
      groupedHours[k]!.sort();
    }
    final groupedKeys = groupedHours.keys.toList();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
          elevation: 8,
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFED7AA),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.assignment_late_rounded,
                    color: Color(0xFFEA580C),
                    size: 36,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Pengingat Jurnal Mengajar',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  'Halo ${teacher.name}, Anda memiliki ${groupedKeys.length} jadwal mengajar hari ini yang belum diisi jurnalnya. Silakan segera melengkapi:',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.sp,
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.all(12.w),
                      itemCount: groupedKeys.length,
                      separatorBuilder: (context, _) =>
                          const Divider(color: Color(0xFFE2E8F0), height: 12),
                      itemBuilder: (context, index) {
                        final key = groupedKeys[index];
                        final schedule = groupedRepresentative[key]!;
                        final hours = groupedHours[key]!;
                        final cls = masterProvider.classes.firstWhere(
                          (c) => c.id == schedule.classId,
                          orElse: () => ClassModel(
                            id: '',
                            name: 'Kelas--',
                            periodId: '',
                            studentCount: 0,
                          ),
                        );
                        final subject = masterProvider.subjects.firstWhere(
                          (s) => s.id == schedule.subjectId,
                          orElse: () => SubjectModel(
                            id: '',
                            name: 'Mapel--',
                            isActive: false,
                          ),
                        );
                        final hoursLabel = hours.length == 1
                            ? 'Jam ${hours.first}'
                            : 'Jam ${hours.join(', ')}';
                        return Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                hoursLabel,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cls.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    subject.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.sp,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'Oke, Saya Isi Jurnal',
                    style: GoogleFonts.hankenGrotesk(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User session not found')),
      );
    }

    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
      orElse: () => TeacherModel(
        id: '',
        name: currentUser.fullName,
        position: currentUser.position ?? 'Guru',
        address: currentUser.address ?? '',
        phoneNumber: currentUser.phoneNumber ?? '',
        email: currentUser.email,
        photoUrl: currentUser.photoUrl,
      ),
    );

    final pendingJournals = journalProvider.teacherJournals
        .where((j) => j.status == 'pending')
        .length;

    final now = DateTime.now();
    final Set<String> uniqueMonthlySessions = {};
    for (final s in scheduleProvider.cachedTeacherSchedules) {
      if (s.isActive && s.date.year == now.year && s.date.month == now.month) {
        uniqueMonthlySessions.add(
          '${s.date.year}-${s.date.month}-${s.date.day}|${s.classId}|${s.subjectId}',
        );
      }
    }
    final monthlyScheduleCount = uniqueMonthlySessions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppTheme.primaryColor,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Section (Direct Design Match to Reference) ─────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 50),
                  child: _buildModernHeader(
                    teacher,
                    monthlyScheduleCount,
                    pendingJournals,
                  ),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),

                      // ── Quick Filter Tabs (Dynamic UI) ─────────────────────
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: _buildFilterChips(),
                      ),

                      SizedBox(height: 20.h),

                      // ── Today's Schedule Section ───────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionTitle('Jadwal Mengajar Hari Ini'),
                          GestureDetector(
                            onTap: () => context.push('/guru/jadwal'),
                            child: Text(
                              'Lihat Semua',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildHorizontalScheduleSection(
                        masterProvider,
                        scheduleProvider,
                        journalProvider,
                      ),

                      SizedBox(height: 28.h),

                      // ── Recent Journals Timeline Section ───────────────────
                      _buildJournalTimelineSection(
                        journalProvider,
                        masterProvider,
                      ),

                      SizedBox(height: 36.h),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header matching Reference Image exactly ──────────────────────────────
  Widget _buildModernHeader(
    TeacherModel teacher,
    int monthlyScheduleCount,
    int pendingCount,
  ) {
    // Extract first name for a friendly greeting
    final firstName = teacher.name.split(' ').first;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation Row: Circular Menu Icon (Left) & Avatar Square (Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Hamburger Menu Button (Circular Container with soft shadow)
              Builder(
                builder: (ctx) {
                  return InkWell(
                    onTap: () {
                      final rootScaffold = ctx
                          .findRootAncestorStateOfType<ScaffoldState>();
                      if (rootScaffold != null && rootScaffold.hasDrawer) {
                        rootScaffold.openDrawer();
                      } else {
                        final scaffoldState = Scaffold.maybeOf(ctx);
                        if (scaffoldState != null && scaffoldState.hasDrawer) {
                          scaffoldState.openDrawer();
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(50.r),
                    child: Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.menu_rounded,
                          color: Color(0xFF1E293B),
                          size: 22,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Avatar with soft yellow glow / rounded background matching reference
              InkWell(
                onTap: () {
                  final shellState = context
                      .findAncestorStateOfType<GuruMainShellState>();
                  if (shellState != null) {
                    shellState.switchToTab(3);
                  } else {
                    context.go('/guru/dashboard?tab=3');
                  }
                },
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFFACC15,
                    ), // Yellow background from image
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.4),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child:
                        teacher.photoUrl != null &&
                            teacher.photoUrl!.startsWith('http')
                        ? Image.network(
                            teacher.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF1E293B),
                                  size: 28,
                                ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.face_rounded,
                              color: Color(0xFF1E293B),
                              size: 28,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 20.h),

          // Greeting Subtitle
          Text(
            'Selamat Datang, $firstName! 👋',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),

          SizedBox(height: 6.h),

          // Big Bold Headline Text matching design: "You have 49 tasks this month 👍"
          RichText(
            text: TextSpan(
              style: GoogleFonts.hankenGrotesk(
                fontSize: 22.sp,
                height: 1.25,
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
              ),
              children: [
                const TextSpan(text: 'Anda memiliki '),
                TextSpan(
                  text: '$monthlyScheduleCount jadwal ',
                  style: const TextStyle(
                    color: Color(0xFF4F46E5), // Indigo blue accent
                  ),
                ),
                const TextSpan(text: 'bulan ini 👍'),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // ── Gradient Border Capsule Search Bar (Clean Single-Surface) ────────
          Container(
            height: 48.h,
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999.r),
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF00C6FF), // Bright Cyan Blue
                  Color(0xFF8A2BE2), // Purple
                  Color(0xFFE10098), // Vivid Pink / Magenta
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF2C2C2C),
                    size: 20,
                  ),
                  SizedBox(width: 10.w),
                  // Thin vertical divider line
                  Container(
                    width: 1.w,
                    height: 18.h,
                    color: const Color(0xFFE5E7EB),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C2C2C),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari jadwal, kelas, atau mapel...',
                        hintStyle: GoogleFonts.hankenGrotesk(
                          fontSize: 13.sp,
                          color: const Color(0xFF8E8E93),
                          fontWeight: FontWeight.w400,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                      },
                      child: const Icon(
                        Icons.cancel_rounded,
                        color: Color(0xFF8E8E93),
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter Chips ─────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = ['Semua', 'Belum Diisi', 'Selesai'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _activeTabFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ScaleTap(
              onTap: () {
                setState(() {
                  _activeTabFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF4F46E5,
                            ).withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Section Title ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 16.sp,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0F172A),
      ),
    );
  }

  // ─── Horizontal Schedule Section ──────────────────────────────────────────
  Widget _buildHorizontalScheduleSection(
    MasterDataProvider master,
    ScheduleProvider scheduleProvider,
    JournalProvider journalProvider,
  ) {
    if (scheduleProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    var list = scheduleProvider.teacherSchedulesForSelectedDate;

    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_available_outlined,
              color: const Color(0xFF94A3B8),
              size: 40.w,
            ),
            SizedBox(height: 8.h),
            Text(
              'Tidak ada jadwal mengajar hari ini',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Nikmati hari Anda atau periksa jadwal di hari lainnya.',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.sp,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    var groupedSchedules = groupDailySchedules(list);

    // Apply Filter & Search
    if (_searchQuery.isNotEmpty || _activeTabFilter != 'Semua') {
      groupedSchedules = groupedSchedules.where((group) {
        final s = group.primarySchedule;
        final cls = master.classes.firstWhere(
          (c) => c.id == s.classId,
          orElse: () =>
              ClassModel(id: '', name: '', periodId: '', studentCount: 0),
        );
        final subject = master.subjects.firstWhere(
          (sb) => sb.id == s.subjectId,
          orElse: () => SubjectModel(id: '', name: '', isActive: false),
        );

        final matchesSearch =
            _searchQuery.isEmpty ||
            cls.name.toLowerCase().contains(_searchQuery) ||
            subject.name.toLowerCase().contains(_searchQuery);

        final hasJournal = journalProvider.teacherJournals.any(
          (j) =>
              j.scheduleId == s.id || group.scheduleIds.contains(j.scheduleId),
        );

        if (_activeTabFilter == 'Belum Diisi' && hasJournal) return false;
        if (_activeTabFilter == 'Selesai' && !hasJournal) return false;

        return matchesSearch;
      }).toList();
    }

    if (groupedSchedules.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Text(
            'Tidak ada jadwal yang cocok dengan filter.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13.sp,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        height: 104.h,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: groupedSchedules.length,
          separatorBuilder: (context, _) => SizedBox(width: 12.w),
          itemBuilder: (context, index) {
            final scheduleGroup = groupedSchedules[index];
            return _buildHorizontalScheduleCard(
              scheduleGroup,
              master,
              journalProvider,
              index,
            );
          },
        ),
      ),
    );
  }

  Widget _buildHorizontalScheduleCard(
    GroupedDailySchedule scheduleGroup,
    MasterDataProvider master,
    JournalProvider journalProvider,
    int index,
  ) {
    final schedule = scheduleGroup.primarySchedule;
    final cls = master.classes.firstWhere(
      (c) => c.id == schedule.classId,
      orElse: () =>
          ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == schedule.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final hoursStr = AppHelper.formatTeachingHours(scheduleGroup.teachingHours);

    JournalModel? matchingJournal;
    for (final j in journalProvider.teacherJournals) {
      final sameDate =
          j.date.year == _selectedDay.year &&
          j.date.month == _selectedDay.month &&
          j.date.day == _selectedDay.day;
      if (sameDate &&
          (j.scheduleId == schedule.id ||
              scheduleGroup.scheduleIds.contains(j.scheduleId))) {
        matchingJournal = j;
        break;
      }
    }

    final List<List<Color>> cardGradients = [
      [const Color(0xFF4F46E5), const Color(0xFF3730A3)], // Indigo / Royal Blue
      [const Color(0xFF0284C7), const Color(0xFF075985)], // Cyan / Teal
      [const Color(0xFF7C3AED), const Color(0xFF5B21B6)], // Purple
      [const Color(0xFF059669), const Color(0xFF065F46)], // Emerald
    ];
    final gradientColors = cardGradients[index % cardGradients.length];

    double progressValue = 0.0;
    String progressLabel = '0%';
    String statusText = 'Belum Diisi';
    if (matchingJournal != null) {
      if (matchingJournal.status == 'verified') {
        progressValue = 1.0;
        progressLabel = '100%';
        statusText = 'Verified';
      } else if (matchingJournal.status == 'rejected') {
        progressValue = 0.2;
        progressLabel = 'Ditolak';
        statusText = 'Revisi';
      } else {
        progressValue = 0.6;
        progressLabel = '60%';
        statusText = 'Menunggu';
      }
    }

    final emojis = ['📚', '🎨', '💻', '🧪', '⚡'];
    final emoji = emojis[index % emojis.length];

    return ScaleTap(
      onTap: () {
        if (matchingJournal != null) {
          if (matchingJournal.status == 'rejected') {
            context.push(
              '/guru/journal-form?scheduleId=${schedule.id}&journalId=${matchingJournal.id}&date=${DateFormat('yyyy-MM-dd').format(_selectedDay)}',
            );
          } else {
            context.push('/guru/journal/${matchingJournal.id}');
          }
        } else {
          context.push(
            '/guru/journal-form?scheduleId=${schedule.id}&date=${DateFormat('yyyy-MM-dd').format(_selectedDay)}',
          );
        }
      },
      child: Container(
        width: 175.w,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${cls.name} $emoji',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  statusText,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            Text(
              '${subject.name} ▪ Jam #$hoursStr',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      progressLabel,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 3.5.h,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Colors.white,
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

  // ─── Timeline Recent Journals Section ─────────────────────────────────────
  Widget _buildJournalTimelineSection(
    JournalProvider journalProvider,
    MasterDataProvider masterProvider,
  ) {
    var journals = journalProvider.teacherJournals;

    if (_searchQuery.isNotEmpty) {
      journals = journals.where((j) {
        final cls = masterProvider.classes.firstWhere(
          (c) => c.id == j.classId,
          orElse: () =>
              ClassModel(id: '', name: '', periodId: '', studentCount: 0),
        );
        final subject = masterProvider.subjects.firstWhere(
          (s) => s.id == j.subjectId,
          orElse: () => SubjectModel(id: '', name: '', isActive: false),
        );

        return cls.name.toLowerCase().contains(_searchQuery) ||
            subject.name.toLowerCase().contains(_searchQuery) ||
            j.material.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // Outer Container Base Wrapper Card
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Heading (Top Left)
          Text(
            'Jurnal Terbaru Saya',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A202C),
            ),
          ),

          SizedBox(height: 20.h),

          if (journals.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 40.w,
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Belum ada jurnal',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Jurnal yang Anda isi akan ditampilkan secara otomatis di sini.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.sp,
                        color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Builder(
              builder: (context) {
                final list = journals.length > 5 ? journals.sublist(0, 5) : journals;
                return Column(
                  children: List.generate(list.length, (index) {
                    final journal = list[index];
                    final isLast = index == list.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Timeline Vertical Track Column
                          SizedBox(
                            width: 24.w,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                // Connecting Solid Red Line
                                if (!isLast)
                                  Positioned(
                                    top: 14.h,
                                    bottom: 0,
                                    child: Container(
                                      width: 2.w,
                                      color: const Color(0xFFEF4444),
                                    ),
                                  ),

                                // Timeline Node
                                Positioned(
                                  top: 12.h,
                                  child: index == 0
                                      // Latest Node (Glowing Solid Red)
                                      ? Container(
                                          width: 14.w,
                                          height: 14.w,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFFEF4444),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFEF4444)
                                                    .withValues(alpha: 0.45),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        )
                                      // History Node (Grey Ring Circle)
                                      : Container(
                                          width: 10.w,
                                          height: 10.w,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.white,
                                            border: Border.all(
                                              color: const Color(0xFFD1D5DB),
                                              width: 2.5,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 10.w),

                          // Card Entry Column
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
                              child: index == 0
                                  ? _buildLatestTimelineCard(journal, masterProvider)
                                  : _buildHistoryTimelineCard(journal, masterProvider),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─── Latest Timeline Card (Prominent & Detailed) ─────────────────────────
  Widget _buildLatestTimelineCard(JournalModel journal, MasterDataProvider master) {
    final cls = master.classes.firstWhere(
      (c) => c.id == journal.classId,
      orElse: () =>
          ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == journal.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final statusColor = AppHelper.getStatusColor(journal.status);

    final scheduleProvider = Provider.of<ScheduleProvider>(
      context,
      listen: false,
    );
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

    return InkWell(
      onTap: () => context.push('/guru/journal/${journal.id}'),
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Vertical Left Accent Bar
              Container(
                width: 4.5.w,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14.r),
                    bottomLeft: Radius.circular(14.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Date & Attendance Pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: Color(0xFF718096),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                AppHelper.formatDateShort(journal.date),
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF718096),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildAttendancePill('S', journal.sickCount, const Color(0xFFF59E0B)),
                              SizedBox(width: 5.w),
                              _buildAttendancePill('I', journal.permissionCount, const Color(0xFF3B82F6)),
                              SizedBox(width: 5.w),
                              _buildAttendancePill('A', journal.alphaCount, const Color(0xFFEF4444)),
                            ],
                          ),
                        ],
                      ),

                      SizedBox(height: 8.h),

                      // Main Content: Class Name & Subject — Material
                      Text(
                        '${cls.name} ▪ Jam Ke-$hoursStr',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2D3748),
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${subject.name} — ${journal.material}',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF4A5568),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      SizedBox(height: 8.h),

                      // Status Badge Pill
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            AppHelper.getStatusLabel(journal.status),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 10.sp,
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
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

  // ─── History Timeline Card (Compact & Streamlined) ────────────────────────
  Widget _buildHistoryTimelineCard(JournalModel journal, MasterDataProvider master) {
    final cls = master.classes.firstWhere(
      (c) => c.id == journal.classId,
      orElse: () =>
          ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );
    final subject = master.subjects.firstWhere(
      (s) => s.id == journal.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final statusColor = AppHelper.getStatusColor(journal.status);

    return InkWell(
      onTap: () => context.push('/guru/journal/${journal.id}'),
      borderRadius: BorderRadius.circular(10.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: const Color(0xFFEDF2F7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 11,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      AppHelper.formatDateShort(journal.date),
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.sp,
                        color: const Color(0xFF718096),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6.r),
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
            SizedBox(height: 4.h),
            Text(
              '${cls.name} ▪ ${subject.name} — ${journal.material}',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A5568),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Attendance Micro-Pill ─────────────────────────────────────────────────
  Widget _buildAttendancePill(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        '$label:$count',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: color.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}
