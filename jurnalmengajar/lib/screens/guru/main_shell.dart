import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dashboard_screen.dart';
import 'jadwal_screen.dart';
import 'daftar_jurnal_screen.dart';
import 'profil_screen.dart';
import '../../widgets/guru_drawer.dart';
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
    if (widget.initialIndex != null && widget.initialIndex != oldWidget.initialIndex) {
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
        drawer: GuruDrawer(selectedIndex: _currentIndex),
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
}
