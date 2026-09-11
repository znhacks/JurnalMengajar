import 'dart:math' as math;
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

class AdminDrawer extends StatelessWidget {
  final String currentRoute;
  const AdminDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

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
      child: LayoutBuilder(
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
                  Divider(
                    height: 1,
                    color: dividerColor,
                    thickness: 1,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
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
              Divider(
                height: 1,
                color: dividerColor,
                thickness: 1,
              ),
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
      ),
    );
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
              final isAdminOnly = authProvider.isExclusiveAdmin;
              final switcherWidget = Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business_rounded, color: Color(0xFF4F46E5), size: 16),
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
                    if (!isAdminOnly)
                      const Icon(Icons.swap_vert_rounded, color: Color(0xFF64748B), size: 18),
                  ],
                ),
              );

              if (isAdminOnly) {
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
      ),
      _buildMenuItem(
        context,
        Icons.calendar_month_rounded,
        'Jadwal Mengajar',
        '/admin/schedules',
      ),
      _buildMenuItem(
        context,
        Icons.settings_rounded,
        'Pengaturan',
        '/admin/settings',
      ),
      _buildMenuItem(
        context,
        Icons.event_busy_rounded,
        'Hari Libur / Cuti',
        '/admin/holidays',
      ),
      _buildMenuItem(
        context,
        Icons.info_rounded,
        'Tentang Aplikasi',
        '/about',
      ),

      SizedBox(height: 8.h),
      Divider(
        height: 1,
        color: dividerColor,
        thickness: 1,
      ),
      SizedBox(height: 8.h),

      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 4.h,
        ),
        child: Text(
          'Master Data',
          style: GoogleFonts.hankenGrotesk(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 12.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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
        Icons.school_rounded,
        'Guru',
        '/admin/master-data/teachers',
      ),
      _buildMenuItem(
        context,
        Icons.manage_accounts_rounded,
        'User & Akses',
        '/admin/master-data/users',
      ),
      _buildMenuItem(
        context,
        Icons.mail_rounded,
        'Surat Peringatan (SP)',
        '/admin/warning-letters',
      ),
    ];
  }

  // ── Footer (Profil Saya, Mode Gelap, Keluar) ──────────────────────────────
  Widget _buildFooter(BuildContext context, AuthProvider authProvider, Color dividerColor) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            color: dividerColor,
            thickness: 1,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
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
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                child: ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0),
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
                    scale: 0.8,
                    child: Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (val) {
                        themeProvider.toggleTheme(val);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          Divider(
            height: 1,
            color: dividerColor,
            thickness: 1,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            child: ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 0),
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
          SizedBox(height: math.max(8.h, MediaQuery.of(context).padding.bottom)),
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
          'Konfirmasi Logout',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari halaman Administrator?',
          style: GoogleFonts.hankenGrotesk(
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Batal',
              style: GoogleFonts.hankenGrotesk(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              Navigator.pop(context);
              await authProvider.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(
              'Logout',
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
    String route,
  ) {
    final isSelected = currentRoute == route;
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
          color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text(
          title,
          style: GoogleFonts.hankenGrotesk(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13.sp,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        onTap: () {
          Navigator.pop(context); // Close drawer
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

