import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  DateTime? _lastBackPressTime;

  void switchToTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
    // Synchronize browser route so reload preserves this tab
    try {
      final currentLoc = GoRouterState.of(context).matchedLocation;
      switch (index) {
        case 0:
          if (currentLoc != '/guru/dashboard') {
            context.go('/guru/dashboard');
          }
          break;
        case 1:
          if (currentLoc != '/guru/jadwal') {
            context.go('/guru/jadwal');
          }
          break;
        case 2:
          if (currentLoc != '/guru/jurnal') {
            context.go('/guru/jurnal');
          }
          break;
        case 3:
          if (currentLoc != '/guru/profil' && currentLoc != '/guru/profile') {
            context.go('/guru/profil');
          }
          break;
      }
    } catch (_) {}
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final warningProvider = Provider.of<WarningLetterProvider>(context, listen: false);
    final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
    final journalProvider = Provider.of<JournalProvider>(context, listen: false);

    await masterProvider.loadAllData(authProvider.activeSchoolId);
    if (!mounted) return;
    
    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
      orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
    );
    
    if (teacher.id.isNotEmpty) {
      await Future.wait([
        warningProvider.loadTeacherWarningLetters(teacher.id, authProvider.activeSchoolId),
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



  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (!authProvider.initialized || currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadedUserId != currentUser.id) {
      _loadedUserId = currentUser.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadUserData(currentUser);
      });
    }



    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tekan sekali lagi untuk keluar dari aplikasi',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
              margin: EdgeInsets.all(16.w),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        drawer: GuruDrawer(selectedIndex: _currentIndex),
        body: IndexedStack(index: _currentIndex, children: _screens),
      ),
    );
  }
}
