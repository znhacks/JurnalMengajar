import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AdminDrawer extends StatelessWidget {
  final String currentRoute;
  const AdminDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Drawer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header with logo
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
            ),
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset(
                  'assets/logoApp.png',
                  height: 52.h,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 10.h),
                Text(
                  authProvider.currentUser?.fullName ?? 'Administrator',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  authProvider.currentUser?.email ?? 'admin@jurnal.com',
                  style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                ),
              ],
            ),
          ),

          // Drawer Menu List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(context, Icons.dashboard_outlined, 'Dashboard', '/admin/dashboard'),
                _buildMenuItem(context, Icons.rate_review_outlined, 'Approval Jurnal', '/admin/approvals'),
                
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('MASTER DATA', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                _buildMenuItem(context, Icons.date_range_outlined, 'Master Periode', '/admin/master-data/periods'),
                _buildMenuItem(context, Icons.menu_book_outlined, 'Master Pelajaran', '/admin/master-data/subjects'),
                _buildMenuItem(context, Icons.access_time_outlined, 'Master Jam Pelajaran', '/admin/master-data/hours'),
                _buildMenuItem(context, Icons.class_outlined, 'Master Kelas', '/admin/master-data/classes'),
                _buildMenuItem(context, Icons.people_outline, 'Master Guru', '/admin/master-data/teachers'),
                _buildMenuItem(context, Icons.event_note_outlined, 'Master Jadwal', '/admin/schedules'),
                
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('LAPORAN & SISTEM', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                _buildMenuItem(context, Icons.grid_view_outlined, 'Jadwal Mingguan', '/admin/weekly-schedules'),
                _buildMenuItem(context, Icons.settings_outlined, 'Pengaturan Sistem', '/admin/settings'),
              ],
            ),
          ),

          // Logout Item
          const Divider(),
          _buildMenuItem(context, Icons.info_outline, 'Tentang Aplikasi', '/about'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context); // Close Drawer
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Apakah Anda yakin ingin keluar dari halaman Administrator?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        authProvider.logout();
                      },
                      child: const Text('Logout', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String route) {
    final isSelected = currentRoute == route;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF0D9488) : Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF0D9488) : const Color(0xFF0F172A),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFF0D9488).withValues(alpha: 0.05),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (!isSelected) {
          context.go(route);
        }
      },
    );
  }
}
