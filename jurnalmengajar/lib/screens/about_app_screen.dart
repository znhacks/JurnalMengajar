import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              if (authProvider.currentUser?.role == 'admin') {
                context.go('/admin/dashboard');
              } else {
                context.go('/guru/dashboard');
              }
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Center(
                child: Image.asset(
                  'assets/logoAboutApp.png',
                  width: 200.w,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 24.h),

              // App Name & Version
              Text(
                'Jurnal Mengajar',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E3A5F),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                'Versi 1.0.0',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
              ),
              SizedBox(height: 24.h),

              const Divider(),
              SizedBox(height: 16.h),

              // Description Card
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Deskripsi'),
                      SizedBox(height: 8.h),
                      Text(
                        'Jurnal Mengajar adalah aplikasi manajemen jurnal dan jadwal mengajar yang dirancang untuk memudahkan guru dalam mendokumentasikan kegiatan belajar mengajar secara digital.',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[700],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Features Card
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Fitur Utama'),
                      SizedBox(height: 12.h),
                      _buildFeatureItem(
                        Icons.assignment_outlined,
                        'Pencatatan jurnal mengajar harian',
                      ),
                      _buildFeatureItem(
                        Icons.calendar_month_outlined,
                        'Manajemen jadwal pelajaran',
                      ),
                      _buildFeatureItem(
                        Icons.people_outline,
                        'Pengelolaan data guru & kelas',
                      ),
                      _buildFeatureItem(
                        Icons.check_circle_outline,
                        'Persetujuan jurnal oleh admin',
                      ),
                      _buildFeatureItem(
                        Icons.bar_chart_outlined,
                        'Rekap & laporan kegiatan',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Developer Card
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Pengembang'),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        Icons.code_outlined,
                        'Tim Pengembang',
                        'JoeDevs',
                      ),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        Icons.phone_android_outlined,
                        'Platform',
                        'Mobile',
                      ),
                      SizedBox(height: 8.h),
                      _buildInfoRow(
                        Icons.language_outlined,
                        'Teknologi',
                        'Flutter + Supabase',
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 40.h),
              Text(
                '© 2025 Jurnal Mengajar - JDEVS. All rights reserved.',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[400]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1E3A5F),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(icon, size: 20.w, color: const Color(0xFF2C7BE5)),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18.w, color: const Color(0xFF2C7BE5)),
        SizedBox(width: 10.w),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13.sp,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
