import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/about_app_screen.dart';
import '../../screens/guru/main_shell.dart';
import '../../screens/guru/detail_jadwal_screen.dart';
import '../../screens/guru/form_jurnal_screen.dart';
import '../../screens/guru/detail_jurnal_screen.dart';
import '../../screens/admin/dashboard_screen.dart';
import '../../screens/admin/approval_jurnal_screen.dart';
import '../../screens/admin/master/period_screen.dart';
import '../../screens/admin/master/subject_screen.dart';
import '../../screens/admin/master/hour_screen.dart';
import '../../screens/admin/master/class_screen.dart';
import '../../screens/admin/master/teacher_screen.dart';
import '../../screens/admin/master/user_screen.dart';
import '../../screens/admin/master/schedule_screen.dart';
import '../../screens/admin/settings_screen.dart';
import '../../screens/admin/profile_screen.dart';
import '../../screens/admin/warning_letter_list_screen.dart';
import '../../screens/guru/warning_letter_list_screen.dart';
import '../../screens/guru/statistik_screen.dart';
import '../../screens/admin/admin_jurnal_list_screen.dart';
import '../../screens/admin/master/student_screen.dart';
import '../../screens/admin/master/teacher_detail_screen.dart';

class AppRouter {
  static CustomTransitionPage<void> _buildCustomTransition(
      BuildContext context, GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        return FadeTransition(
          opacity: fadeAnimation,
          child: SlideTransition(
            position: slideAnimation,
            child: child,
          ),
        );
      },
    );
  }

  static GoRouter router(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isInitialized = authProvider.initialized;
        final isLoggedIn = authProvider.isAuthenticated;
        final isSplash = state.matchedLocation == '/splash';
        final isResetPasswordRoute = state.matchedLocation == '/reset-password';
        final isRecoveryMode = authProvider.isRecoveryMode ||
            state.uri.queryParameters['type'] == 'recovery' ||
            state.uri.queryParameters.containsKey('access_token') ||
            state.uri.fragment.contains('type=recovery') ||
            state.uri.fragment.contains('access_token=');
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/login-callback' ||
            state.matchedLocation == '/' ||
            isResetPasswordRoute;

        if (isSplash) return null;
        if (!isInitialized) return null;

        if (isRecoveryMode) {
          if (state.matchedLocation != '/reset-password') {
            return '/reset-password';
          }
          return null;
        }

        if (!isLoggedIn) {
          if (!isAuthRoute) {
            return '/login';
          }
          return null;
        }

        final user = authProvider.currentUser;
        if (user == null) return '/login';

        if (isAuthRoute && !isRecoveryMode) {
          if (user.role == 'admin') {
            return '/admin/dashboard';
          } else {
            return '/guru/dashboard';
          }
        }

        if (state.matchedLocation.startsWith('/admin') && user.role != 'admin') {
          return '/guru/dashboard';
        }

        if (state.matchedLocation.startsWith('/guru') && user.role != 'guru') {
          return '/admin/dashboard';
        }

        return null;
      },
      routes: [
        // Root / Callback Routes
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              _buildCustomTransition(context, state, const SplashScreen()),
        ),
        GoRoute(
          path: '/login-callback',
          pageBuilder: (context, state) => _buildCustomTransition(
            context,
            state,
            const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/splash',
          pageBuilder: (context, state) =>
              _buildCustomTransition(context, state, const SplashScreen()),
        ),
        GoRoute(
          path: '/about',
          pageBuilder: (context, state) =>
              _buildCustomTransition(context, state, const AboutAppScreen()),
        ),
        GoRoute(
          path: '/login',
          pageBuilder: (context, state) =>
              _buildCustomTransition(context, state, const LoginScreen()),
        ),
        GoRoute(
          path: '/register',
          pageBuilder: (context, state) =>
              _buildCustomTransition(context, state, const RegisterScreen()),
        ),
        GoRoute(
          path: '/reset-password',
          pageBuilder: (context, state) => _buildCustomTransition(
            context,
            state,
            ResetPasswordScreen(
              queryParameters: state.uri.queryParameters,
            ),
          ),
        ),

        // Guru Module
        GoRoute(
          path: '/guru/dashboard',
          pageBuilder: (context, state) {
            final tabStr = state.uri.queryParameters['tab'];
            final initialIndex = tabStr != null ? int.tryParse(tabStr) : null;
            return _buildCustomTransition(
                context, state, GuruMainShell(initialIndex: initialIndex));
          },
        ),
        GoRoute(
          path: '/guru/schedule/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildCustomTransition(
                context, state, DetailJadwalScreen(scheduleId: id));
          },
        ),
        GoRoute(
          path: '/guru/journal-form',
          pageBuilder: (context, state) {
            final scheduleId = state.uri.queryParameters['scheduleId'] ?? '';
            final dateStr = state.uri.queryParameters['date'];
            return _buildCustomTransition(
                context, state, FormJurnalScreen(scheduleId: scheduleId, dateStr: dateStr));
          },
        ),
        GoRoute(
          path: '/guru/journal/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildCustomTransition(
                context, state, DetailJurnalScreen(journalId: id));
          },
        ),
        GoRoute(
          path: '/guru/warning-letters',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const GuruWarningLetterListScreen()),
        ),
        GoRoute(
          path: '/guru/statistik',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const GuruStatistikScreen()),
        ),

        // Admin Module
        GoRoute(
          path: '/admin/dashboard',
          pageBuilder: (context, state) {
            final teacherId = state.uri.queryParameters['teacherId'];
            return _buildCustomTransition(
                context, state, AdminDashboardScreen(selectedTeacherId: teacherId));
          },
        ),
        GoRoute(
          path: '/admin/approvals',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const ApprovalJurnalScreen()),
        ),
        GoRoute(
          path: '/admin/journals',
          pageBuilder: (context, state) {
            final tab = int.tryParse(
                    state.uri.queryParameters['tab'] ?? '0') ??
                0;
            return _buildCustomTransition(
                context, state, AdminJurnalListScreen(initialTabIndex: tab));
          },
        ),
        GoRoute(
          path: '/admin/journal/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildCustomTransition(
                context, state, DetailJurnalScreen(journalId: id));
          },
        ),
        GoRoute(
          path: '/admin/schedule/:id',
          pageBuilder: (context, state) {
            final id = state.pathParameters['id']!;
            return _buildCustomTransition(
                context, state, DetailJadwalScreen(scheduleId: id));
          },
        ),
        GoRoute(
          path: '/admin/warning-letters',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const AdminWarningLetterListScreen()),
        ),
        GoRoute(
          path: '/admin/master-data/periods',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const MasterPeriodScreen()),
        ),
        GoRoute(
          path: '/admin/master-data/subjects',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const MasterSubjectScreen()),
        ),
        GoRoute(
          path: '/admin/master-data/hours',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const MasterHourScreen()),
        ),
        GoRoute(
          path: '/admin/master-data/classes',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const MasterClassScreen()),
        ),
        GoRoute(
          path: '/admin/master-data/classes/:classId/students',
          pageBuilder: (context, state) {
            final classId = state.pathParameters['classId']!;
            return _buildCustomTransition(
                context, state, MasterStudentScreen(classId: classId));
          },
        ),
        GoRoute(
          path: '/admin/master-data/teachers',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const MasterTeacherScreen()),
        ),
        GoRoute(
          path: '/admin/master-data/teachers/:teacherId',
          pageBuilder: (context, state) {
            final teacherId = state.pathParameters['teacherId']!;
            return _buildCustomTransition(
                context, state, TeacherDetailScreen(teacherId: teacherId));
          },
        ),
        GoRoute(
          path: '/admin/schedules',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const MasterScheduleScreen()),
        ),
        GoRoute(
          path: '/admin/settings',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const AdminSettingsScreen()),
        ),
        GoRoute(
          path: '/admin/master-data/users',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const MasterUserScreen()),
        ),
        GoRoute(
          path: '/admin/profile',
          pageBuilder: (context, state) => _buildCustomTransition(
              context, state, const AdminProfileScreen()),
        ),
      ],
    );
  }
}
