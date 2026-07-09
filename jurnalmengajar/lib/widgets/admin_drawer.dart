import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_theme.dart';

class AdminDrawer extends StatelessWidget {
  final String currentRoute;
  const AdminDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Drawer(
      backgroundColor: Colors.white,
      shadowColor: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Gradient ────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
              ),
            ),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20.h,
              bottom: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 24),
                    ),
                    SizedBox(width: 10.w),
                    Image.asset(
                      'assets/logoApp.png',
                      height: 36.h,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                Text(
                  authProvider.currentUser?.fullName ?? 'Administrator',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16.sp,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  authProvider.currentUser?.email ?? 'admin@jurnal.com',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ── Menu List ──────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              children: [
                _buildMenuItem(context, Icons.dashboard_outlined, 'Dashboard', '/admin/dashboard'),
                _buildMenuItem(context, Icons.rate_review_outlined, 'Approval Jurnal', '/admin/approvals'),
                
                const Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Text(
                    'MASTER DATA',
                    style: GoogleFonts.hankenGrotesk(
                      color: AppTheme.outline,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
                _buildMenuItem(context, Icons.date_range_outlined, 'Master Periode', '/admin/master-data/periods'),
                _buildMenuItem(context, Icons.menu_book_outlined, 'Master Pelajaran', '/admin/master-data/subjects'),
                _buildMenuItem(context, Icons.access_time_outlined, 'Master Jam Pelajaran', '/admin/master-data/hours'),
                _buildMenuItem(context, Icons.class_outlined, 'Master Kelas', '/admin/master-data/classes'),
                _buildMenuItem(context, Icons.people_outline, 'Master Guru', '/admin/master-data/teachers'),
                _buildMenuItem(context, Icons.manage_accounts_outlined, 'Master User & Akses', '/admin/master-data/users'),
                _buildMenuItem(context, Icons.event_note_outlined, 'Master Jadwal', '/admin/schedules'),
                
                const Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: Text(
                    'LAPORAN & SISTEM',
                    style: GoogleFonts.hankenGrotesk(
                      color: AppTheme.outline,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.05,
                    ),
                  ),
                ),
                _buildMenuItem(context, Icons.grid_view_outlined, 'Jadwal Mingguan', '/admin/weekly-schedules'),
                _buildMenuItem(context, Icons.mail_outline_rounded, 'Surat Peringatan (SP)', '/admin/warning-letters'),
                _buildMenuItem(context, Icons.settings_outlined, 'Pengaturan Sistem', '/admin/settings'),
                _buildMenuItem(context, Icons.person_outline, 'Profil Saya', '/admin/profile'),
              ],
            ),
          ),

          // ── Footer / Logout ───────────────────────────────────────────────
          const Divider(),
          _buildMenuItem(context, Icons.info_outline, 'Tentang Aplikasi', '/about'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.logout_outlined, color: AppTheme.errorColor),
              title: Text(
                'Logout',
                style: GoogleFonts.hankenGrotesk(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Close Drawer
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(
                      'Konfirmasi Logout',
                      style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w700),
                    ),
                    content: Text(
                      'Apakah Anda yakin ingin keluar dari halaman Administrator?',
                      style: GoogleFonts.hankenGrotesk(color: AppTheme.onSurfaceVariant),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          authProvider.logout();
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
              },
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String route) {
    final isSelected = currentRoute == route;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryColor : AppTheme.outline,
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.hankenGrotesk(
            color: isSelected ? AppTheme.primaryColor : AppTheme.onBackground,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14.sp,
          ),
        ),
        selected: isSelected,
        selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.08),
        onTap: () {
          Navigator.pop(context); // Close drawer
          if (!isSelected) {
            context.go(route);
          }
        },
      ),
    );
  }
}
