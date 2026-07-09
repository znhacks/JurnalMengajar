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

class GuruMainShell extends StatefulWidget {
  const GuruMainShell({super.key});

  @override
  State<GuruMainShell> createState() => _GuruMainShellState();
}

class _GuruMainShellState extends State<GuruMainShell> {
  int _currentIndex = 0;
  double? _xPosition;
  double? _yPosition;

  final List<Widget> _screens = [
    const GuruDashboardScreen(),
    const GuruJadwalScreen(),
    const GuruDaftarJurnalScreen(),
    const GuruProfilScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
      final warningProvider = Provider.of<WarningLetterProvider>(context, listen: false);

      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        await masterProvider.loadAllData();
        final teacher = masterProvider.teachers.firstWhere(
          (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
          orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
        );
        if (teacher.id.isNotEmpty) {
          await warningProvider.loadTeacherWarningLetters(teacher.id);
        }
      }
    });
  }

  Widget _buildFloatingWarningBadge(int unreadCount, double screenWidth, double screenHeight) {
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
        onTap: () {
          context.push('/guru/warning-letters');
        },
        child: Container(
          width: 56.w,
          height: 56.w,
          decoration: BoxDecoration(
            color: const Color(0xFFBA1A1A), // Red Warning
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFBA1A1A).withValues(alpha: 0.4),
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
              const Icon(
                Icons.assignment_late_rounded,
                color: Colors.white,
                size: 28,
              ),
              Positioned(
                right: -6.w,
                top: -6.h,
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(
                    minWidth: 18.w,
                    minHeight: 18.w,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$unreadCount',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.black,
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
    final warningProvider = context.watch<WarningLetterProvider>();
    final unreadWarnings = warningProvider.warningLetters.where((w) => w.status == 'unread').length;

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          if (unreadWarnings > 0)
            _buildFloatingWarningBadge(unreadWarnings, screenWidth, screenHeight),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Jadwal',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Jurnal',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}
