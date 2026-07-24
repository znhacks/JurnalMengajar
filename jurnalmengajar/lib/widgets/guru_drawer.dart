import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/warning_letter_provider.dart';
import '../screens/guru/main_shell.dart';

class GuruDrawer extends StatelessWidget {
  final String? currentRoute;
  final int? selectedIndex;

  const GuruDrawer({
    super.key,
    this.currentRoute,
    this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    final warningProvider = context.watch<WarningLetterProvider>();
    final unreadWarnings = warningProvider.warningLetters.where((w) => w.status == 'unread').length;

    final name = currentUser?.fullName ?? 'Guru Pengajar';
    final email = currentUser?.email ?? '';
    final photoUrl = currentUser?.photoUrl;

    final shellState = context.findAncestorStateOfType<GuruMainShellState>();

    int activeIndex = selectedIndex ?? -1;
    if (activeIndex == -1 && currentRoute != null) {
      if (currentRoute == '/guru/dashboard' || currentRoute == '/guru/dashboard?tab=0') {
        activeIndex = 0;
      } else if (currentRoute == '/guru/jadwal' || currentRoute == '/guru/dashboard?tab=1') {
        activeIndex = 1;
      } else if (currentRoute == '/guru/jurnal' || currentRoute == '/guru/dashboard?tab=2') {
        activeIndex = 2;
      } else if (currentRoute == '/guru/profil' || currentRoute == '/guru/profile' || currentRoute == '/guru/dashboard?tab=3') {
        activeIndex = 3;
      }
    }

    return Drawer(
      backgroundColor: Colors.white,
      shadowColor: Colors.transparent,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20.w, MediaQuery.of(context).padding.top + 20.h, 20.w, 20.h),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4F46E5), // Vibrant Indigo
                  Color(0xFF3730A3),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52.w,
                      height: 52.w,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFACC15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(52.r),
                        child: photoUrl != null && photoUrl.startsWith('http')
                            ? Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.person, color: Color(0xFF1E293B), size: 30),
                              )
                            : const Icon(Icons.person, color: Color(0xFF1E293B), size: 30),
                      ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            email,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: 0.8),
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
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_rounded, color: Colors.white, size: 14.w),
                      SizedBox(width: 6.w),
                      Text(
                        'Guru Pengajar',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Menu List
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
              children: [
                _buildDrawerSectionHeader('MENU UTAMA'),
                _buildDrawerItem(
                  icon: Icons.grid_view_rounded,
                  label: 'Dashboard',
                  isSelected: activeIndex == 0,
                  onTap: () {
                    Navigator.pop(context);
                    if (shellState != null) {
                      shellState.switchToTab(0);
                    } else {
                      context.go('/guru/dashboard?tab=0');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Jadwal Mengajar',
                  isSelected: activeIndex == 1,
                  onTap: () {
                    Navigator.pop(context);
                    if (shellState != null) {
                      shellState.switchToTab(1);
                    } else {
                      context.go('/guru/dashboard?tab=1');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_rounded,
                  label: 'Daftar Jurnal',
                  isSelected: activeIndex == 2,
                  onTap: () {
                    Navigator.pop(context);
                    if (shellState != null) {
                      shellState.switchToTab(2);
                    } else {
                      context.go('/guru/dashboard?tab=2');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  label: 'Profil Saya',
                  isSelected: activeIndex == 3,
                  onTap: () {
                    Navigator.pop(context);
                    if (shellState != null) {
                      shellState.switchToTab(3);
                    } else {
                      context.go('/guru/dashboard?tab=3');
                    }
                  },
                ),

                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: const Divider(color: Color(0xFFE2E8F0), height: 1),
                ),

                _buildDrawerSectionHeader('FITUR LAINNYA'),
                _buildDrawerItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Statistik Mengajar',
                  isSelected: currentRoute == '/guru/statistics' || currentRoute == '/guru/statistik',
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != '/guru/statistics' && currentRoute != '/guru/statistik') {
                      context.push('/guru/statistics');
                    }
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_late_rounded,
                  label: 'Surat Peringatan (SP)',
                  badgeCount: unreadWarnings,
                  isSelected: currentRoute == '/guru/warning-letters',
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != '/guru/warning-letters') {
                      context.push('/guru/warning-letters');
                    }
                  },
                ),

                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: const Divider(color: Color(0xFFE2E8F0), height: 1),
                ),

                _buildDrawerItem(
                  icon: Icons.info_outline_rounded,
                  label: 'Tentang Aplikasi',
                  isSelected: currentRoute == '/about',
                  onTap: () {
                    Navigator.pop(context);
                    if (currentRoute != '/about') {
                      context.push('/about');
                    }
                  },
                ),
              ],
            ),
          ),

          // Drawer Footer (Logout)
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            child: _buildDrawerItem(
              icon: Icons.logout_rounded,
              label: 'Keluar / Logout',
              isSelected: false,
              isDestructive: true,
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
          ),
          SizedBox(height: 6.h),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

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
          'Apakah Anda yakin ingin keluar dari aplikasi?',
          style: GoogleFonts.hankenGrotesk(
            color: const Color(0xFF475569),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Batal',
              style: GoogleFonts.hankenGrotesk(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx); // Close Dialog
              Navigator.pop(context);   // Close Drawer
              await authProvider.logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: Text(
              'Logout',
              style: GoogleFonts.hankenGrotesk(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 6.h),
      child: Text(
        title,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
    bool isDestructive = false,
  }) {
    final Color activeColor = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF4F46E5);
    final Color textColor = isDestructive
        ? const Color(0xFFEF4444)
        : (isSelected ? const Color(0xFF4F46E5) : const Color(0xFF334155));

    return Container(
      margin: EdgeInsets.only(bottom: 4.h),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEEF2FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
        leading: Icon(
          icon,
          color: isSelected ? activeColor : (isDestructive ? activeColor : const Color(0xFF64748B)),
          size: 22,
        ),
        title: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: textColor,
          ),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '$badgeCount',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : (isSelected
                ? Container(
                    width: 4.w,
                    height: 18.h,
                    decoration: BoxDecoration(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  )
                : null),
      ),
    );
  }
}
