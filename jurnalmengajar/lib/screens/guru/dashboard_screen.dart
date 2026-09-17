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
import '../../providers/holiday_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/journal_model.dart';
import '../../models/schedule_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../core/utils/helper.dart';
import '../../core/utils/schedule_grouper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../widgets/animated_widgets.dart';
import '../../widgets/role_badge.dart';
import '../../widgets/school_switcher_modal.dart';
import 'package:table_calendar/table_calendar.dart';

class GuruDashboardScreen extends StatefulWidget {
  const GuruDashboardScreen({super.key});

  /// Reset reminder status saat logout atau berganti akun
  static void resetReminderFlag() {
    _GuruDashboardScreenState._hasCheckedReminder = false;
  }

  @override
  State<GuruDashboardScreen> createState() => _GuruDashboardScreenState();
}

class _GuruDashboardScreenState extends State<GuruDashboardScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  static bool _hasCheckedReminder = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeTabFilter = 'Semua'; // 'Semua', 'Belum Diisi', 'Selesai'

  String? _lastLoadedSchoolId;
  String? _lastLoadedUserId;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context);
    final currentSchoolId = authProvider.activeSchoolId;
    final currentUserId = authProvider.currentUser?.id;

    if ((_lastLoadedSchoolId != null &&
            _lastLoadedSchoolId != currentSchoolId) ||
        (_lastLoadedUserId != null && _lastLoadedUserId != currentUserId)) {
      _lastLoadedSchoolId = currentSchoolId;
      _lastLoadedUserId = currentUserId;
      _hasCheckedReminder = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshData();
      });
    } else {
      _lastLoadedSchoolId = currentSchoolId;
      _lastLoadedUserId = currentUserId;
    }
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
    final holidayProvider = Provider.of<HolidayProvider>(
      context,
      listen: false,
    );
    final warningProvider = Provider.of<WarningLetterProvider>(
      context,
      listen: false,
    );

    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
      final schoolId = authProvider.activeSchoolId;
      await masterProvider.loadAllData(schoolId);

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
        final targetSchoolId =
            schoolId ?? 'a1111111-1111-1111-1111-111111111111';
        await Future.wait([
          scheduleProvider.loadTeacherSchedules(teacher.id, _selectedDay),
          journalProvider.loadTeacherJournals(teacher.id),
          holidayProvider.loadHolidays(targetSchoolId),
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

        await warningProvider.checkAndIssueWarnings(
          schedules: scheduleProvider.cachedTeacherSchedules,
          journals: journalProvider.teacherJournals,
          maxDays: maxDays,
          masterProvider: masterProvider,
        );
        await warningProvider.loadTeacherWarningLetters(
          teacher.id,
          authProvider.activeSchoolId,
        );

        if (!_hasCheckedReminder) {
          _hasCheckedReminder = true;
          _checkAndShowReminder(
            teacher,
            scheduleProvider,
            journalProvider,
            masterProvider,
          );
        }
      } else {
        // Clear old cached schedules, journals, and warnings if user is not registered as teacher in this school
        scheduleProvider.clearTeacherSchedulesCache();
        journalProvider.clearTeacherJournalsCache();
        warningProvider.clearCache();
      }
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDay = date;
      _focusedDay = date;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(
      context,
      listen: false,
    );
    final scheduleProvider = Provider.of<ScheduleProvider>(
      context,
      listen: false,
    );
    final currentUser = authProvider.currentUser;
    if (currentUser != null) {
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
        scheduleProvider.loadTeacherSchedules(teacher.id, date);
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),
                Text(
                  'Halo ${teacher.name}, Anda memiliki ${groupedKeys.length} jadwal mengajar hari ini yang belum diisi jurnalnya. Silakan segera melengkapi:',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.h),
                Container(
                  constraints: BoxConstraints(maxHeight: 180.h),
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(groupedKeys.length, (index) {
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
                                color: const Color(
                                  0xFF4F7CFF,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                hoursLabel,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  color: const Color(0xFF4F7CFF),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    subject.name,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.sp,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F7CFF),
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

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) {
      return 'Selamat pagi,';
    } else if (hour < 15) {
      return 'Selamat siang,';
    } else if (hour < 18) {
      return 'Selamat sore,';
    } else {
      return 'Selamat malam,';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final holidayProvider = context.watch<HolidayProvider>();

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
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

    final today = DateTime.now();
    final cleanActiveSchoolId =
        AppHelper.parseSingleCleanSchoolId(authProvider.activeSchoolId) ??
        authProvider.activeSchoolId?.trim();

    final scheduledDateKeys = <String>{};
    final completedDateKeys = <String>{};
    final Map<String, List<ScheduleModel>> schedulesByDate = {};

    for (final s in scheduleProvider.cachedTeacherSchedules) {
      if (!s.isActive) continue;
      if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
        final sSchoolId =
            AppHelper.parseSingleCleanSchoolId(s.schoolId) ??
            s.schoolId?.trim();
        if (sSchoolId != null &&
            sSchoolId.isNotEmpty &&
            sSchoolId != cleanActiveSchoolId) {
          continue;
        }
      }
      final key =
          '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      scheduledDateKeys.add(key);
      schedulesByDate.putIfAbsent(key, () => []).add(s);
    }

    for (final entry in schedulesByDate.entries) {
      final key = entry.key;
      final list = entry.value;
      final grouped = groupDailySchedules(list);
      if (grouped.isNotEmpty) {
        final allFilled = grouped.every((group) {
          final s = group.primarySchedule;
          return journalProvider.teacherJournals.any((j) {
            final sameDate =
                '${j.date.year}-${j.date.month.toString().padLeft(2, '0')}-${j.date.day.toString().padLeft(2, '0')}' == key;
            final sameSchedule = j.scheduleId == s.id ||
                group.scheduleIds.contains(j.scheduleId) ||
                (j.classId == s.classId && j.subjectId == s.subjectId);
            return sameDate &&
                sameSchedule &&
                (j.status == 'pending' || j.status == 'verified' || j.isTeacherAbsence);
          });
        });
        if (allFilled) {
          completedDateKeys.add(key);
        }
      }
    }

    final activeSchedulesThisMonth = scheduleProvider.cachedTeacherSchedules
        .where((s) {
          if (!s.isActive) return false;
          if (cleanActiveSchoolId != null && cleanActiveSchoolId.isNotEmpty) {
            final sSchoolId =
                AppHelper.parseSingleCleanSchoolId(s.schoolId) ??
                s.schoolId?.trim();
            if (sSchoolId != null &&
                sSchoolId.isNotEmpty &&
                sSchoolId != cleanActiveSchoolId) {
              return false;
            }
          }
          if (s.date.year != today.year || s.date.month != today.month) {
            return false;
          }
          return true;
        })
        .toList();

    final groupedMonthSchedules = groupDailySchedules(activeSchedulesThisMonth);

    final unfinishedMonthSchedules = groupedMonthSchedules.where((group) {
      final s = group.primarySchedule;
      final hasJournal = journalProvider.teacherJournals.any((j) {
        return j.scheduleId == s.id ||
            group.scheduleIds.contains(j.scheduleId) ||
            (j.date.year == group.date.year &&
                j.date.month == group.date.month &&
                j.date.day == group.date.day &&
                j.classId == group.classId &&
                j.subjectId == group.subjectId);
      });
      return !hasJournal;
    }).toList();

    final monthScheduleCount = unfinishedMonthSchedules.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF4F7CFF),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. HEADER SECTION ─────────────────────────────────────────
                FadeSlideIn(
                  delay: const Duration(milliseconds: 50),
                  child: _buildModernHeader(teacher, monthScheduleCount),
                ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),

                      // ── 2. KARTU KALENDER (Atas) ────────────────────────────
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 80),
                        child: _buildCalendarCard(
                          scheduledDateKeys,
                          completedDateKeys,
                          teacher,
                          scheduleProvider,
                          journalProvider,
                          holidayProvider,
                        ),
                      ),

                      SizedBox(height: 16.h),

                      // ── 3. TAB FILTER (Di bawah Kalender) ──────────────────
                      FadeSlideIn(
                        delay: const Duration(milliseconds: 100),
                        child: _buildFilterChips(),
                      ),

                      SizedBox(height: 20.h),

                      // ── Holiday Banner (If Holiday on selected date) ───────
                      Builder(
                        builder: (context) {
                          final holidayProvider = context
                              .watch<HolidayProvider>();
                          final holiday = holidayProvider.getHolidayForDate(
                            _selectedDay,
                          );
                          if (holiday == null) return const SizedBox.shrink();

                          return Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(bottom: 16.h),
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.w),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.event_busy_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'HARI LIBUR: ${holiday.title.toUpperCase()}',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF991B1B),
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        holiday.description != null &&
                                                holiday.description!.isNotEmpty
                                            ? holiday.description!
                                            : 'KBM ditiadakan. Anda tidak perlu mengisikan jurnal.',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 11.sp,
                                          color: const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // ── 5. SECTION JADWAL MENGAJAR ─────────────────────────
                      _buildScheduleSectionHeader(),
                      SizedBox(height: 10.h),
                      _buildScheduleListSection(
                        masterProvider,
                        scheduleProvider,
                        journalProvider,
                      ),

                      SizedBox(height: 20.h),

                      // ── 6. SECTION JURNAL TERBARU SAYA ────────────────────
                      _buildRecentJournalsSection(
                        journalProvider,
                        masterProvider,
                      ),

                      SizedBox(height: 24.h),
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

  // ─── 1. HEADER ─────────────────────────────────────────────────────────────
  Widget _buildModernHeader(TeacherModel teacher, int monthScheduleCount) {
    final greeting = _getTimeGreeting();

    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation Row: Hamburger Menu (Left) & Profile Avatar (Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Hamburger Menu Button
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
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF4F7CFF,
                            ).withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.menu_rounded,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 22,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Branding App Logo
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/logoApp.png',
                    height: 30.h,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/LogoJr.png',
                      height: 30.h,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Jurnal Mengajar',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              // Avatar Illustration / Profile Picture in Soft Blue Circle Container
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
                borderRadius: BorderRadius.circular(50.r),
                child: Container(
                  width: 46.w,
                  height: 46.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF4F7CFF).withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F7CFF).withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50.r),
                    child: Builder(
                      builder: (context) {
                        final authUser = context
                            .watch<AuthProvider>()
                            .currentUser;
                        final displayPhoto =
                            (authUser?.photoUrl != null &&
                                authUser!.photoUrl!.startsWith('http'))
                            ? authUser.photoUrl
                            : (teacher.photoUrl != null &&
                                      teacher.photoUrl!.startsWith('http')
                                  ? teacher.photoUrl
                                  : null);

                        return displayPhoto != null
                            ? Image.network(
                                displayPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.face_rounded,
                                      color: Color(0xFF4F7CFF),
                                      size: 26,
                                    ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.face_rounded,
                                  color: Color(0xFF4F7CFF),
                                  size: 26,
                                ),
                              );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 18.h),

          // Greeting Subtitle
          Text(
            greeting,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),

          SizedBox(height: 4.h),

          // Big Headline: "Anda memiliki X jadwal bulan ini " (Clickable to open Jadwal tab)
          InkWell(
            onTap: () {
              final shellState = context
                  .findAncestorStateOfType<GuruMainShellState>();
              if (shellState != null) {
                shellState.switchToTab(1);
              } else {
                context.go('/guru/dashboard?tab=1');
              }
            },
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 2.h),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 21.sp,
                    height: 1.25,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    const TextSpan(text: 'Anda memiliki '),
                    TextSpan(
                      text: '$monthScheduleCount jadwal ',
                      style: const TextStyle(
                        color: Color(0xFF4F7CFF),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const TextSpan(text: 'bulan ini'),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Active School & Role Switcher Banner
          Builder(
            builder: (ctx) {
              final auth = ctx.watch<AuthProvider>();
              final isAdminOnly = auth.isExclusiveAdmin;
              final isDark = Theme.of(context).brightness == Brightness.dark;

              final switcherWidget = Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F7CFF).withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      color: Color(0xFF4F7CFF),
                      size: 18,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        auth.activeSchoolName,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isAdminOnly)
                      const Icon(
                        Icons.unfold_more_rounded,
                        color: Color(0xFF64748B),
                        size: 20,
                      ),
                  ],
                ),
              );

              if (isAdminOnly) {
                return Row(
                  children: [
                    Expanded(child: switcherWidget),
                    SizedBox(width: 8.w),
                    RoleBadge(role: auth.activeRole),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => SchoolSwitcherModal.show(ctx),
                      borderRadius: BorderRadius.circular(14.r),
                      child: switcherWidget,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  RoleBadge(
                    role: auth.activeRole,
                    onTap: () => SchoolSwitcherModal.show(ctx),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── 3. TAB FILTER ─────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = ['Semua', 'Belum Diisi', 'Selesai'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _activeTabFilter == filter;
          return Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: ScaleTap(
              onTap: () {
                setState(() {
                  _activeTabFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF4F7CFF), Color(0xFF8B7CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24.r),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : const Color(0xFFEAF2FF),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF4F7CFF,
                            ).withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Text(
                  filter,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.5.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── 4. KARTU KALENDER ─────────────────────────────────────────────────────
  Widget _buildCalendarCard(
    Set<String> scheduledDateKeys,
    Set<String> completedDateKeys,
    TeacherModel teacher,
    ScheduleProvider scheduleProvider,
    JournalProvider journalProvider,
    HolidayProvider holidayProvider,
  ) {
    final monthYearStr = DateFormat('MMMM yyyy', 'id_ID').format(_focusedDay);

    // Calculate current week days starting from Monday of the focused day's week
    final monday = _focusedDay.subtract(
      Duration(days: _focusedDay.weekday - 1),
    );
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F7CFF).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Calendar Header: Nav Buttons & Month Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                  });
                },
                borderRadius: BorderRadius.circular(50.r),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F7CFF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: Color(0xFF4F7CFF),
                    size: 20,
                  ),
                ),
              ),

              InkWell(
                onTap: () => _showMonthCalendarDialog(
                  context,
                  scheduleProvider,
                  teacher,
                  scheduledDateKeys,
                  completedDateKeys,
                  holidayProvider,
                  journalProvider,
                ),
                borderRadius: BorderRadius.circular(10.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthYearStr,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(width: 5.w),
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 16.sp,
                        color: const Color(0xFF4F7CFF),
                      ),
                    ],
                  ),
                ),
              ),

              InkWell(
                onTap: () {
                  setState(() {
                    _focusedDay = _focusedDay.add(const Duration(days: 7));
                  });
                },
                borderRadius: BorderRadius.circular(50.r),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F7CFF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF4F7CFF),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // Day Names Row (Sen, Sel, Rab, Kam, Jum, Sab, Min)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayNames.map((name) {
              final isSunday = name == 'Min';
              return SizedBox(
                width: 38.w,
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    color: isSunday
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 10.h),

          // Week Dates Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekDays.map((date) {
              final isSelected =
                  date.year == _selectedDay.year &&
                  date.month == _selectedDay.month &&
                  date.day == _selectedDay.day;
              final isSunday = date.weekday == DateTime.sunday;
              final dateKey =
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final hasSchedule = scheduledDateKeys.contains(dateKey);
              final isAllFilled = completedDateKeys.contains(dateKey);
              final isHoliday = holidayProvider.getHolidayForDate(date) != null ||
                  journalProvider.teacherJournals.any((j) =>
                      j.date.year == date.year &&
                      j.date.month == date.month &&
                      j.date.day == date.day &&
                      j.isTeacherAbsence);

              BoxDecoration circleDecoration;
              Color textColor;
              FontWeight fontWeight;
              Widget bottomIndicator;

              if (isSelected) {
                // Indikator berpindah-pindah tetap biru kecuali libur/cuti merah
                if (isHoliday) {
                  circleDecoration = BoxDecoration(
                    color: const Color(0xFFDC2626),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  );
                  textColor = Colors.white;
                  fontWeight = FontWeight.w800;
                  bottomIndicator = Container(
                    width: 14.w,
                    height: 3.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  );
                } else {
                  circleDecoration = BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F7CFF), Color(0xFF8B7CFF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF60A5FA),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F7CFF).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  );
                  textColor = Colors.white;
                  fontWeight = FontWeight.w800;
                  bottomIndicator = Container(
                    width: 14.w,
                    height: 3.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F7CFF),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  );
                }
              } else if (isHoliday) {
                // Libur / cuti: berwarna merah
                circleDecoration = BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.22 : 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEF4444),
                    width: 1.5,
                  ),
                );
                textColor = const Color(0xFFEF4444);
                fontWeight = FontWeight.w700;
                bottomIndicator = SizedBox(height: 3.h);
              } else if (hasSchedule) {
                if (isAllFilled) {
                  // Selesai semua jadwal diisi: berwarna biru
                  circleDecoration = BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.22 : 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF3B82F6),
                      width: 1.5,
                    ),
                  );
                  textColor = isDark
                      ? const Color(0xFF93C5FD)
                      : const Color(0xFF1D4ED8);
                  fontWeight = FontWeight.w700;
                  bottomIndicator = SizedBox(height: 3.h);
                } else {
                  // Memiliki jadwal: berwarna hijau
                  circleDecoration = BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1.5,
                    ),
                  );
                  textColor = isDark
                      ? const Color(0xFF6EE7B7)
                      : const Color(0xFF047857);
                  fontWeight = FontWeight.w700;
                  bottomIndicator = SizedBox(height: 3.h);
                }
              } else {
                // Normal date
                circleDecoration = const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                );
                textColor = isSunday
                    ? const Color(0xFFEF4444)
                    : Theme.of(context).colorScheme.onSurface;
                fontWeight = FontWeight.w600;
                bottomIndicator = SizedBox(height: 3.h);
              }

              return InkWell(
                onTap: () => _onDateSelected(date),
                borderRadius: BorderRadius.circular(20.r),
                child: Column(
                  children: [
                    Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: circleDecoration,
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13.sp,
                            fontWeight: fontWeight,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    bottomIndicator,
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showMonthCalendarDialog(
    BuildContext context,
    ScheduleProvider scheduleProvider,
    TeacherModel teacher,
    Set<String> scheduledDateKeys,
    Set<String> completedDateKeys,
    HolidayProvider holidayProvider,
    JournalProvider journalProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        DateTime focused = _focusedDay;
        DateTime selected = _selectedDay;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 24.h,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pilih Tanggal Mengajar',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(dialogCtx).colorScheme.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(dialogCtx),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const Divider(),
                    TableCalendar(
                      locale: 'id_ID',
                      daysOfWeekHeight: 30.h,
                      rowHeight: 44.h,
                      firstDay: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDay: DateTime.now().add(const Duration(days: 365)),
                      focusedDay: focused,
                      calendarFormat: CalendarFormat.month,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: GoogleFonts.hankenGrotesk(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(dialogCtx).colorScheme.onSurface,
                        ),
                      ),
                      selectedDayPredicate: (day) => isSameDay(selected, day),
                      onDaySelected: (selDay, focDay) {
                        setDialogState(() {
                          selected = selDay;
                          focused = focDay;
                        });
                        _onDateSelected(selDay);
                        Navigator.pop(dialogCtx);
                      },
                      onPageChanged: (focDay) {
                        setDialogState(() {
                          focused = focDay;
                        });
                        setState(() {
                          _focusedDay = focDay;
                        });
                      },
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (ctx, day, focDay) {
                          return _buildMonthCell(
                            day,
                            isSelected: false,
                            isToday: false,
                            isOutside: false,
                            scheduledDateKeys: scheduledDateKeys,
                            completedDateKeys: completedDateKeys,
                            holidayProvider: holidayProvider,
                            journalProvider: journalProvider,
                          );
                        },
                        outsideBuilder: (ctx, day, focDay) {
                          return _buildMonthCell(
                            day,
                            isSelected: false,
                            isToday: false,
                            isOutside: true,
                            scheduledDateKeys: scheduledDateKeys,
                            completedDateKeys: completedDateKeys,
                            holidayProvider: holidayProvider,
                            journalProvider: journalProvider,
                          );
                        },
                        todayBuilder: (ctx, day, focDay) {
                          final isSel = isSameDay(selected, day);
                          return _buildMonthCell(
                            day,
                            isSelected: isSel,
                            isToday: true,
                            isOutside: false,
                            scheduledDateKeys: scheduledDateKeys,
                            completedDateKeys: completedDateKeys,
                            holidayProvider: holidayProvider,
                            journalProvider: journalProvider,
                          );
                        },
                        selectedBuilder: (ctx, day, focDay) {
                          return _buildMonthCell(
                            day,
                            isSelected: true,
                            isToday: isSameDay(DateTime.now(), day),
                            isOutside: false,
                            scheduledDateKeys: scheduledDateKeys,
                            completedDateKeys: completedDateKeys,
                            holidayProvider: holidayProvider,
                            journalProvider: journalProvider,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMonthCell(
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
    required Set<String> scheduledDateKeys,
    required Set<String> completedDateKeys,
    required HolidayProvider holidayProvider,
    required JournalProvider journalProvider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final hasSchedule = scheduledDateKeys.contains(dateKey);
    final isAllFilled = completedDateKeys.contains(dateKey);
    final isHoliday = holidayProvider.getHolidayForDate(day) != null ||
        journalProvider.teacherJournals.any((j) =>
            j.date.year == day.year &&
            j.date.month == day.month &&
            j.date.day == day.day &&
            j.isTeacherAbsence);
    final isSunday = day.weekday == DateTime.sunday;

    Color bgColor = Colors.transparent;
    Color textColor = isOutside
        ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
        : (isSunday
              ? const Color(0xFFEF4444)
              : Theme.of(context).colorScheme.onSurface);
    FontWeight fontWeight = FontWeight.w500;
    BoxBorder? border;

    if (isSelected) {
      if (isHoliday) {
        bgColor = const Color(0xFFDC2626);
        textColor = Colors.white;
        fontWeight = FontWeight.w800;
        border = Border.all(color: const Color(0xFFEF4444), width: 2.0);
      } else {
        bgColor = const Color(0xFF4F7CFF);
        textColor = Colors.white;
        fontWeight = FontWeight.w800;
        border = Border.all(color: const Color(0xFF60A5FA), width: 2.0);
      }
    } else if (isHoliday) {
      bgColor = const Color(0xFFDC2626).withValues(alpha: isDark ? 0.22 : 0.15);
      textColor = const Color(0xFFEF4444);
      fontWeight = FontWeight.w700;
      border = Border.all(color: const Color(0xFFEF4444), width: 1.5);
    } else if (hasSchedule) {
      if (isAllFilled) {
        bgColor = const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.22 : 0.15);
        textColor = isOutside
            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
            : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8));
        fontWeight = FontWeight.w700;
        border = Border.all(color: const Color(0xFF3B82F6), width: 1.5);
      } else {
        bgColor = const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.15);
        textColor = isOutside
            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))
            : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857));
        fontWeight = FontWeight.w700;
        border = Border.all(color: const Color(0xFF10B981), width: 1.5);
      }
    } else if (isToday) {
      bgColor = const Color(0xFF4F7CFF).withValues(alpha: isDark ? 0.25 : 0.15);
      textColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF4F7CFF);
      fontWeight = FontWeight.w700;
    }

    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 12.sp,
          fontWeight: fontWeight,
          color: textColor,
        ),
      ),
    );
  }

  // ─── 5. SECTION JADWAL MENGAJAR ────────────────────────────────────────────
  Widget _buildScheduleSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Jadwal Mengajar',
          style: GoogleFonts.hankenGrotesk(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        InkWell(
          onTap: () => context.go('/guru/jadwal'),
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
            child: Text(
              'Lihat Semua',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4F7CFF),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleListSection(
    MasterDataProvider master,
    ScheduleProvider scheduleProvider,
    JournalProvider journalProvider,
  ) {
    if (scheduleProvider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF4F7CFF)),
        ),
      );
    }

    var list = scheduleProvider.teacherSchedulesForSelectedDate;

    // ── EMPTY STATE ──────────────────────────────────────────────────────────
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F7CFF).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFF4F7CFF).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: Color(0xFF4F7CFF),
                size: 28,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tidak ada jadwal mengajar hari ini',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Nikmati hari Anda atau periksa jadwal di hari lainnya.',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.5.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Center(
          child: Text(
            'Tidak ada jadwal yang cocok dengan filter.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Schedule Cards Stack
    return Column(
      children: List.generate(groupedSchedules.length, (index) {
        final scheduleGroup = groupedSchedules[index];
        final isLast = index == groupedSchedules.length - 1;

        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 8.h),
          child: _buildTeachingScheduleCard(
            scheduleGroup,
            master,
            journalProvider,
            index,
          ),
        );
      }),
    );
  }

  Widget _buildTeachingScheduleCard(
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

    final timeBadgeText = 'Jam $hoursStr';

    return ScaleTap(
      onTap: () async {
        if (matchingJournal != null) {
          if (matchingJournal.status == 'rejected') {
            await context.push(
              '/guru/journal-form?scheduleId=${schedule.id}&journalId=${matchingJournal.id}&date=${DateFormat('yyyy-MM-dd').format(_selectedDay)}',
            );
          } else {
            await context.push('/guru/journal/${matchingJournal.id}');
          }
        } else {
          await context.push(
            '/guru/journal-form?scheduleId=${schedule.id}&date=${DateFormat('yyyy-MM-dd').format(_selectedDay)}',
          );
        }
        if (mounted) {
          _refreshData();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F7CFF).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Class & Subject Info (No big icon!)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          cls.name,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // Single blue Jam badge positioned next to class name
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F7CFF).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          timeBadgeText,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4F7CFF),
                          ),
                        ),
                      ),
                      if (matchingJournal != null) ...[
                        SizedBox(width: 6.w),
                        if (matchingJournal.isTeacherAbsence) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (matchingJournal.isTeacherSick
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFF59E0B))
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              matchingJournal.isTeacherSick ? 'Sakit' : 'Izin',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: matchingJournal.isTeacherSick
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                        ],
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppHelper.getStatusColor(
                              matchingJournal.status,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            AppHelper.getStatusLabel(matchingJournal.status),
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w700,
                              color: AppHelper.getStatusColor(
                                matchingJournal.status,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subject.name,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            SizedBox(width: 8.w),

            // Compact Right Arrow Button
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF334155).withValues(alpha: 0.6)
                    : const Color(0xFFF0F5FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF4F7CFF),
                size: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6. SECTION JURNAL TERBARU SAYA ────────────────────────────────────────
  Widget _buildRecentJournalsSection(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F7CFF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Color(0xFF4F7CFF),
                    size: 18,
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Jurnal Terbaru Saya',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                final shellState = context
                    .findAncestorStateOfType<GuruMainShellState>();
                if (shellState != null) {
                  shellState.switchToTab(2);
                } else {
                  context.go('/guru/dashboard?tab=2');
                }
              },
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                child: Text(
                  'Lihat Semua',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF4F7CFF),
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 10.h),

        if (journals.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    color: const Color(0xFF94A3B8),
                    size: 38.w,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Belum ada jurnal',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Jurnal yang Anda isi akan ditampilkan secara otomatis di sini.',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              final list = journals.length > 5
                  ? journals.sublist(0, 5)
                  : journals;
              return Column(
                children: List.generate(list.length, (index) {
                  final journal = list[index];
                  final isLast = index == list.length - 1;

                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 8.h),
                    child: index == 0
                        ? _buildLatestTimelineCard(journal, masterProvider)
                        : _buildHistoryTimelineCard(journal, masterProvider),
                  );
                }),
              );
            },
          ),
        ],
      ],
    );
  }

  // ─── Latest Journal Card (Prominent & Detailed) ───────────────────────────
  Widget _buildLatestTimelineCard(
    JournalModel journal,
    MasterDataProvider master,
  ) {
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
    final hoursList = groupSchedules.map((s) => s.teachingHour).toList()
      ..sort();
    final hoursStr = hoursList.isNotEmpty
        ? AppHelper.formatTeachingHours(hoursList)
        : '${journal.teachingHour}';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F7CFF).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: () => context.push('/guru/journal/${journal.id}'),
          borderRadius: BorderRadius.circular(10.r),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Vertical Left Accent Bar
                  Container(width: 3.5.w, color: statusColor),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(12.w, 9.h, 12.w, 9.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Date & Attendance Micro Pills & Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 11.5.sp,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(width: 5.w),
                                  Text(
                                    AppHelper.formatDateShort(journal.date),
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.5.sp,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (journal.isTeacherAbsence) ...[
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 7.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            (journal.isTeacherSick
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFFF59E0B))
                                                .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(
                                          5.r,
                                        ),
                                      ),
                                      child: Text(
                                        journal.isTeacherSick
                                            ? 'Surat Sakit'
                                            : 'Surat Izin',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w700,
                                          color: journal.isTeacherSick
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                  ] else ...[
                                    _buildAttendancePill(
                                      'S',
                                      journal.sickCount,
                                      const Color(0xFFD97706),
                                    ),
                                    SizedBox(width: 3.w),
                                    _buildAttendancePill(
                                      'I',
                                      journal.permissionCount,
                                      const Color(0xFF2563EB),
                                    ),
                                    SizedBox(width: 3.w),
                                    _buildAttendancePill(
                                      'A',
                                      journal.alphaCount,
                                      const Color(0xFFDC2626),
                                    ),
                                    SizedBox(width: 6.w),
                                  ],
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 7.w,
                                      vertical: 2.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(5.r),
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
                            ],
                          ),

                          SizedBox(height: 6.h),

                          // Main Content: Class Name & Jam Ke
                          Text(
                            '${cls.name} • Jam Ke-$hoursStr',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.5.sp,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            journal.material.isNotEmpty
                                ? '${subject.name} — ${journal.material}'
                                : subject.name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  // ─── History Journal Card (Compact) ───────────────────────────────────────
  Widget _buildHistoryTimelineCard(
    JournalModel journal,
    MasterDataProvider master,
  ) {
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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10.r),
        child: InkWell(
          onTap: () => context.push('/guru/journal/${journal.id}'),
          borderRadius: BorderRadius.circular(10.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          AppHelper.formatDateShort(journal.date),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (journal.isTeacherAbsence) ...[
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (journal.isTeacherSick
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFFF59E0B))
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                            child: Text(
                              journal.isTeacherSick
                                  ? 'Surat Sakit'
                                  : 'Surat Izin',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                                color: journal.isTeacherSick
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.w),
                        ],
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(5.r),
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
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  journal.material.isNotEmpty
                      ? '${cls.name} • ${subject.name} — ${journal.material}'
                      : '${cls.name} • ${subject.name}',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Attendance Micro-Pill ─────────────────────────────────────────────────
  Widget _buildAttendancePill(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4.r),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Text(
        '$label:$count',
        style: GoogleFonts.hankenGrotesk(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
