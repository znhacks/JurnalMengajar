import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_theme.dart';
import '../providers/theme_provider.dart';
import 'role_badge.dart';
import 'school_switcher_modal.dart';

import '../providers/journal_provider.dart';
import '../providers/warning_letter_provider.dart';
import '../providers/teacher_leave_provider.dart';
import '../models/user_model.dart';
import '../core/services/cache_service.dart';
import '../core/utils/helper.dart';

class AdminDrawer extends StatelessWidget {
  final String currentRoute;
  const AdminDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16.r),
          bottomRight: Radius.circular(16.r),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: AdminDrawerPanel(currentRoute: currentRoute),
    );
  }
}

/// Isi menu sidebar yang dipakai bersama oleh [AdminDrawer] (menu geser pada
/// layar sempit) dan sidebar permanen pada web desktop.
class AdminDrawerPanel extends StatefulWidget {
  final String currentRoute;

  /// True saat panel ini dirender sebagai sidebar permanen, bukan drawer.
  /// Pada mode ini menekan menu tidak menutup route karena tidak ada drawer.
  final bool isPermanentSidebar;

  const AdminDrawerPanel({
    super.key,
    required this.currentRoute,
    this.isPermanentSidebar = false,
  });

  @override
  State<AdminDrawerPanel> createState() => _AdminDrawerPanelState();
}

class _AdminDrawerPanelState extends State<AdminDrawerPanel> {
  bool _hasPendingUsers = false;
  String? _lastCheckedSchoolId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingUsers();
      _ensureDataLoaded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = authProvider.activeSchoolId;
    if (_lastCheckedSchoolId != schoolId) {
      _lastCheckedSchoolId = schoolId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkPendingUsers();
        _ensureDataLoaded();
      });
    }
  }

  void _ensureDataLoaded() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = authProvider.activeSchoolId;
    if (schoolId == null || schoolId.isEmpty) return;

    try {
      final journalProvider = Provider.of<JournalProvider>(context, listen: false);
      if (journalProvider.journals.isEmpty && !journalProvider.isLoading) {
        journalProvider.loadAllJournals(schoolId);
      }
    } catch (_) {}

    try {
      final warningProvider = Provider.of<WarningLetterProvider>(context, listen: false);
      if (warningProvider.warningLetters.isEmpty && !warningProvider.isLoading) {
        warningProvider.loadAllWarningLetters(schoolId);
      }
    } catch (_) {}
  }

  T? _safeWatch<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: true);
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkPendingUsers() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolId = authProvider.activeSchoolId;
    if (schoolId == null || schoolId.isEmpty) return;

    // 1. Cek dari local cache dulu untuk respon instan
    try {
      final cachedUsers = await CacheService().loadList('school_users_$schoolId');
      if (cachedUsers != null) {
        final hasPending = cachedUsers.any((u) {
          final status = (u['status'] ?? '').toString().toLowerCase();
          final role = (u['role'] ?? '').toString().toLowerCase();
          return status == 'pending' || role == 'pending_guru' || u['is_pending'] == true;
        });
        if (mounted && hasPending != _hasPendingUsers) {
          setState(() => _hasPendingUsers = hasPending);
        }
      }
      final cachedExit = await CacheService().loadList('exit_requests_$schoolId');
      if (cachedExit != null && cachedExit.isNotEmpty) {
        if (mounted && !_hasPendingUsers) {
          setState(() => _hasPendingUsers = true);
        }
      }
    } catch (_) {}

    // 2. Fetch data terbaru di background
    try {
      final exitReqsFuture = authProvider.getPendingExitRequests(schoolId);
      final usersFuture = authProvider.getAllUsers(schoolId);
      final results = await Future.wait([exitReqsFuture, usersFuture]);
      final exitReqs = results[0] as List<Map<String, dynamic>>;
      final users = results[1] as List<UserModel>;

      final hasPending = exitReqs.isNotEmpty || users.any((u) {
        final st = u.status?.toLowerCase() ?? '';
        final rl = u.role.toLowerCase();
        return u.isPending || st == 'pending' || rl == 'pending_guru';
      });

      if (mounted && hasPending != _hasPendingUsers) {
        setState(() => _hasPendingUsers = hasPending);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Jika tinggi layar terbatas (misal laptop kecil/landscape/split screen),
        // gunakan single scrolling agar menu dan footer tidak bertumpuk/terjepit.
        final isCompactHeight = constraints.maxHeight < 560;

        if (isCompactHeight) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, authProvider),
                Divider(height: 1, color: dividerColor, thickness: 1),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildMenuItems(context, dividerColor),
                  ),
                ),
                _buildFooter(context, authProvider, dividerColor),
              ],
            ),
          );
        }

        // Tampilan standar dengan tinggi cukup:
        // Header tetap di atas, Menu List di Expanded dengan scroll mandiri (overflow-y: auto),
        // Footer (Profil Saya, Mode Gelap, Keluar) tetap di bawah rapi dengan area terpisah.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, authProvider),
            Divider(height: 1, color: dividerColor, thickness: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                children: _buildMenuItems(context, dividerColor),
              ),
            ),
            _buildFooter(context, authProvider, dividerColor),
          ],
        );
      },
    );
  }

  /// Menutup drawer saat panel ini dipakai sebagai drawer (bukan sidebar
  /// permanen). Pada sidebar permanen tidak ada drawer yang perlu ditutup,
  /// memanggil `Navigator.pop` justru akan mengeluarkan route yang aktif.
  void _closeDrawer(BuildContext context) {
    if (widget.isPermanentSidebar) return;
    Navigator.pop(context);
  }

  // ── Header (Logo & Active School) ──────────────────────────────────────────
  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16.h,
        bottom: 12.h,
        left: 16.w,
        right: 16.w,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(
                'assets/LogoJr.png',
                height: 34.h,
                fit: BoxFit.contain,
              ),
              RoleBadge(role: authProvider.activeRole),
            ],
          ),
          SizedBox(height: 12.h),
          Builder(
            builder: (context) {
              final canSwitch =
                  !authProvider.isAdminAsli || authProvider.hasMultipleSchools;
              final switcherWidget = Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      color: Color(0xFF2563EB),
                      size: 16,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        authProvider.activeSchoolName,
                        style: GoogleFonts.hankenGrotesk(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canSwitch)
                      const Icon(
                        Icons.swap_vert_rounded,
                        color: Color(0xFF64748B),
                        size: 18,
                      ),
                  ],
                ),
              );

              if (!canSwitch) {
                return switcherWidget;
              }

              return InkWell(
                onTap: () => SchoolSwitcherModal.show(context),
                borderRadius: BorderRadius.circular(12.r),
                child: switcherWidget,
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Menu List Items ────────────────────────────────────────────────────────
  List<Widget> _buildMenuItems(BuildContext context, Color dividerColor) {
    final authProvider = context.watch<AuthProvider>();
    final journalProvider = _safeWatch<JournalProvider>(context);
    final warningProvider = _safeWatch<WarningLetterProvider>(context);
    final leaveProvider = _safeWatch<TeacherLeaveProvider>(context);

    final cleanActiveSchoolId = AppHelper.parseSingleCleanSchoolId(
      authProvider.activeSchoolId,
    );

    // 1. Jurnal Mengajar: ada jurnal menunggu persetujuan/verifikasi admin
    final hasPendingJournals = journalProvider?.journals.any((j) {
      if (j.status != 'pending') return false;
      if (cleanActiveSchoolId == null || cleanActiveSchoolId.isEmpty) return true;
      final wSchoolId = AppHelper.parseSingleCleanSchoolId(j.schoolId);
      return wSchoolId == null || wSchoolId.isEmpty || wSchoolId == cleanActiveSchoolId;
    }) ?? false;

    // 2. User & Akses: ada guru menunggu persetujuan bergabung atau keluar
    final hasPendingUsers = _hasPendingUsers;

    // 3. Pengingat: ada surat peringatan unread untuk sekolah ini
    final hasPendingWarnings = warningProvider?.warningLetters.any((w) {
      if (w.status != 'unread') return false;
      if (cleanActiveSchoolId == null || cleanActiveSchoolId.isEmpty) return true;
      final wSchoolId = AppHelper.parseSingleCleanSchoolId(w.schoolId);
      return wSchoolId == null || wSchoolId.isEmpty || wSchoolId == cleanActiveSchoolId;
    }) ?? false;

    // 4. Cuti Guru: ada cuti guru dengan status pending/menunggu
    final hasPendingLeaves = leaveProvider?.leaves.any((l) {
      final st = l.status.toLowerCase();
      if (st != 'pending' && st != 'menunggu') return false;
      if (cleanActiveSchoolId == null || cleanActiveSchoolId.isEmpty) return true;
      final wSchoolId = AppHelper.parseSingleCleanSchoolId(l.schoolId);
      return wSchoolId == null || wSchoolId.isEmpty || wSchoolId == cleanActiveSchoolId;
    }) ?? false;

    return [
      _buildMenuItem(
        context,
        Icons.space_dashboard_rounded,
        'Dashboard',
        '/admin/dashboard',
      ),
      _buildMenuItem(
        context,
        Icons.check_circle_rounded,
        'Jurnal Mengajar',
        '/admin/journals',
        hasAction: hasPendingJournals,
      ),
      _buildMenuItem(
        context,
        Icons.calendar_month_rounded,
        'Jadwal Mengajar',
        '/admin/schedules',
      ),
      _buildMenuItem(
        context,
        Icons.analytics_rounded,
        'Statistik Guru',
        '/admin/teacher-statistics',
      ),
      _buildMenuItem(
        context,
        Icons.fact_check_rounded,
        'Kehadiran',
        '/admin/class-attendance-recap',
      ),
      _buildMenuItem(
        context,
        Icons.settings_rounded,
        'Pengaturan',
        '/admin/settings',
      ),
      _buildMenuItem(context, Icons.info_rounded, 'Tentang Aplikasi', '/about'),

      SizedBox(height: 8.h),
      Divider(height: 1, color: dividerColor, thickness: 1),
      SizedBox(height: 8.h),

      _buildMenuItem(
        context,
        Icons.local_offer_rounded,
        'Periode',
        '/admin/master-data/periods',
      ),
      _buildMenuItem(
        context,
        Icons.assignment_rounded,
        'Pelajaran',
        '/admin/master-data/subjects',
      ),
      _buildMenuItem(
        context,
        Icons.access_time_filled_rounded,
        'Jam Pelajaran',
        '/admin/master-data/hours',
      ),
      _buildMenuItem(
        context,
        Icons.home_rounded,
        'Kelas & Siswa',
        '/admin/master-data/classes',
      ),
      _buildMenuItem(
        context,
        Icons.trending_up_rounded,
        'Kenaikan Kelas',
        '/admin/master-data/student-promotions',
      ),
      _buildMenuItem(
        context,
        Icons.school_rounded,
        'Guru',
        '/admin/master-data/teachers',
      ),
      _buildMenuItem(
        context,
        Icons.manage_accounts_rounded,
        'User & Akses',
        '/admin/master-data/users',
        hasAction: hasPendingUsers,
      ),
      _buildMenuItem(
        context,
        Icons.mail_rounded,
        'Pengingat',
        '/admin/warning-letters',
        hasAction: hasPendingWarnings,
      ),
      _buildMenuItem(
        context,
        Icons.event_busy_rounded,
        'Hari Libur',
        '/admin/holidays',
      ),
      _buildMenuItem(
        context,
        Icons.person_off_rounded,
        'Cuti Guru',
        '/admin/teacher-leaves',
        hasAction: hasPendingLeaves,
      ),
    ];
  }

  // ── Footer (Profil Saya, Mode Gelap, Keluar) ──────────────────────────────
  Widget _buildFooter(
    BuildContext context,
    AuthProvider authProvider,
    Color dividerColor,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: dividerColor, thickness: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 1.h),
            child: _buildMenuItem(
              context,
              Icons.person_rounded,
              'Profil Saya',
              '/admin/profile',
            ),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 1.h),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(
                    horizontal: -3,
                    vertical: -4,
                  ),
                  minVerticalPadding: 0,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 0,
                  ),
                  onTap: () {
                    themeProvider.toggleTheme(!themeProvider.isDarkMode);
                  },
                  leading: Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  title: Text(
                    themeProvider.isDarkMode ? 'Mode Gelap' : 'Mode Terang',
                    style: GoogleFonts.hankenGrotesk(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                  ),
                  trailing: Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: themeProvider.isDarkMode,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        themeProvider.toggleTheme(val);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 12.w,
              right: 12.w,
              top: 1.h,
              bottom: 2.h,
            ),
            child: ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -4),
              minVerticalPadding: 0,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              leading: Icon(
                Icons.logout_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
              title: Text(
                'Keluar',
                style: GoogleFonts.hankenGrotesk(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
              onTap: () => _showLogoutDialog(context, authProvider),
            ),
          ),
          if (MediaQuery.of(context).padding.bottom > 0)
            SizedBox(
              height: MediaQuery.of(context).padding.bottom,
            ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: Text(
          'Konfirmasi Keluar',
          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari halaman Administrator?',
          style: GoogleFonts.hankenGrotesk(color: AppTheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Batal',
              style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              _closeDrawer(context);
              await authProvider.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(
              'Keluar',
              style: GoogleFonts.hankenGrotesk(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String route, {
    bool hasAction = false,
  }) {
    // Query string (mis. ?teacherId=..) tidak boleh mengganggu penanda menu.
    final isSelected = widget.currentRoute.split('?').first == route;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 1.h),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        leading: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text.rich(
          TextSpan(
            text: title,
            style: GoogleFonts.hankenGrotesk(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.sp,
            ),
            children: [
              if (hasAction)
                WidgetSpan(
                  alignment: PlaceholderAlignment.top,
                  child: Padding(
                    padding: EdgeInsets.only(left: 3.5.w, top: 1.5.h),
                    child: Container(
                      width: 6.r,
                      height: 6.r,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        onTap: () {
          _closeDrawer(context); // Close drawer (hanya pada mode drawer)
          if (!isSelected) {
            if (route == '/admin/dashboard') {
              context.go(route);
            } else {
              context.push(route);
            }
          }
        },
      ),
    );
  }
}
