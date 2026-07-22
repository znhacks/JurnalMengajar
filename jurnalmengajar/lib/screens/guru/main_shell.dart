import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'jadwal_screen.dart';
import 'daftar_jurnal_screen.dart';
import 'profil_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/user_model.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';

class GuruMainShell extends StatefulWidget {
  final int? initialIndex;
  const GuruMainShell({super.key, this.initialIndex});

  @override
  State<GuruMainShell> createState() => GuruMainShellState();
}

class GuruMainShellState extends State<GuruMainShell> {
  late int _currentIndex;
  double? _xPosition;
  double? _yPosition;

  void switchToTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  final List<Widget> _screens = [
    const GuruDashboardScreen(),
    const GuruJadwalScreen(),
    const GuruDaftarJurnalScreen(),
    const GuruProfilScreen(),
  ];

  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex ?? 0;
  }

  Future<void> _loadUserData(UserModel currentUser) async {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final warningProvider = Provider.of<WarningLetterProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);

    await masterProvider.loadAllData();
    if (!mounted) return;
    
    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
      orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
    );
    
    if (teacher.id.isNotEmpty) {
      await Future.wait([
        warningProvider.loadTeacherWarningLetters(teacher.id),
        scheduleProvider.loadTeacherSchedules(teacher.id, DateTime.now()),
        journalProvider.loadTeacherJournals(teacher.id),
      ]);
    }
  }

  @override
  void didUpdateWidget(covariant GuruMainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != null && widget.initialIndex != _currentIndex) {
      setState(() {
        _currentIndex = widget.initialIndex!;
      });
    }
  }

  Widget _buildFloatingBadge({
    required int count,
    required Color color,
    required IconData icon,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
    required double screenWidth,
    required double screenHeight,
  }) {
    _xPosition ??= screenWidth - 72.w;
    _yPosition ??= screenHeight - 160.h;

    return Positioned(
      left: _xPosition,
      top: _yPosition,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _xPosition = (_xPosition ?? 0) + details.delta.dx;
            _yPosition = (_yPosition ?? 0) + details.delta.dy;

            // Boundaries: stay on screen
            _xPosition = _xPosition!.clamp(16.0, screenWidth - 72.w);
            _yPosition = _yPosition!.clamp(16.0, screenHeight - 200.h);
          });
        },
        onTap: onTap,
        child: Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
              Positioned(
                right: -6.w,
                top: -6.h,
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: 18.w,
                    minHeight: 18.w,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: GoogleFonts.hankenGrotesk(
                      color: badgeTextColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser != null && _loadedUserId != currentUser.id) {
      _loadedUserId = currentUser.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserData(currentUser);
      });
    }

    final warningProvider = context.watch<WarningLetterProvider>();
    final unreadWarnings = warningProvider.warningLetters.where((w) => w.status == 'unread').length;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _currentIndex = 0;
        });
      },
      child: Scaffold(
        drawer: _buildGuruDrawer(context, currentUser, unreadWarnings),
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _screens),
            if (unreadWarnings > 0)
              _buildFloatingBadge(
                count: unreadWarnings,
                color: const Color(0xFFBA1A1A),
                icon: Icons.assignment_late_rounded,
                badgeColor: Colors.amber,
                badgeTextColor: Colors.black,
                onTap: () => context.push('/guru/warning-letters'),
                screenWidth: screenWidth,
                screenHeight: screenHeight,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuruDrawer(BuildContext context, UserModel? currentUser, int unreadWarnings) {
    final name = currentUser?.fullName ?? 'Guru Pengajar';
    final email = currentUser?.email ?? '';
    final photoUrl = currentUser?.photoUrl;

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20.w, 48.h, 20.w, 20.h),
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
                  isSelected: _currentIndex == 0,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentIndex = 0;
                    });
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Jadwal Mengajar',
                  isSelected: _currentIndex == 1,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentIndex = 1;
                    });
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_rounded,
                  label: 'Daftar Jurnal',
                  isSelected: _currentIndex == 2,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentIndex = 2;
                    });
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.person_rounded,
                  label: 'Profil Saya',
                  isSelected: _currentIndex == 3,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _currentIndex = 3;
                    });
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
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/guru/statistics');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_late_rounded,
                  label: 'Surat Peringatan (SP)',
                  badgeCount: unreadWarnings,
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/guru/warning-letters');
                  },
                ),

                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: const Divider(color: Color(0xFFE2E8F0), height: 1),
                ),

                _buildDrawerItem(
                  icon: Icons.info_outline_rounded,
                  label: 'Tentang Aplikasi',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/about');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Keluar',
                  isDestructive: true,
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                ),
              ],
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          'Konfirmasi Keluar',
          style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w800, fontSize: 16.sp),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun?',
          style: GoogleFonts.hankenGrotesk(fontSize: 13.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.hankenGrotesk(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
              context.go('/login');
            },
            child: Text('Keluar', style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
