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
          // ── Header (Logo) ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24.h,
              bottom: 16.h,
              left: 24.w,
              right: 24.w,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/LogoJr.png',
                height: 48.h,
                fit: BoxFit.contain,
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0), thickness: 1),

          // ── Menu List ──────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              children: [
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
                  Icons.info_rounded,
                  'Tentang Aplikasi',
                  '/about',
                ),

                SizedBox(height: 16.h),
                const Divider(
                  height: 1,
                  color: Color(0xFFE2E8F0),
                  thickness: 1,
                ),
                SizedBox(height: 16.h),

                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Text(
                    'Master Data',
                    style: GoogleFonts.hankenGrotesk(
                      color: const Color(0xFF0F172A),
                      fontSize: 14.sp,
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
                  'Kelas',
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
                _buildMenuItem(
                  context,
                  Icons.person_rounded,
                  'Profil Saya',
                  '/admin/profile',
                ),
              ],
            ),
          ),

          // ── Footer / Logout ───────────────────────────────────────────────
          const Divider(height: 1, color: Color(0xFFE2E8F0), thickness: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFF0F172A),
              ),
              title: Text(
                'Keluar',
                style: GoogleFonts.hankenGrotesk(
                  color: const Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 14.sp,
                ),
              ),
              onTap: () {
                Navigator.pop(context); // Close Drawer
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
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
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.hankenGrotesk(
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) {
    final isSelected = currentRoute == route;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2.h),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
          size: 22,
        ),
        title: Text(
          title,
          style: GoogleFonts.hankenGrotesk(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFF0F172A),
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
