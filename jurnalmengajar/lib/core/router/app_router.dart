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
import '../../screens/admin/jadwal_mingguan_screen.dart';
import '../../screens/admin/settings_screen.dart';
import '../../screens/admin/profile_screen.dart';

class AppRouter {
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

        // Don't redirect from splash — it handles its own navigation
        if (isSplash) return null;

        // Wait until AuthProvider has finished loading the initial user state.
        // This prevents false redirects to /login while getCurrentUser() is
        // still running async (e.g. after a Google OAuth callback).
        if (!isInitialized) return null;

        // If recovery mode is active (either via AuthProvider or URL parameters/fragments),
        // we must force navigation to /reset-password.
        if (isRecoveryMode) {
          if (state.matchedLocation != '/reset-password') {
            return '/reset-password';
          }
          return null;
        }

        if (!isLoggedIn) {
          // If not logged in and not on auth pages, redirect to login
          if (!isAuthRoute) {
            return '/login';
          }
          return null;
        }

        // User is logged in
        final user = authProvider.currentUser;
        if (user == null) return '/login';

        // Redirect from auth routes to appropriate dashboard based on role
        if (isAuthRoute && !isRecoveryMode) {
          if (user.role == 'admin') {
            return '/admin/dashboard';
          } else {
            return '/guru/dashboard';
          }
        }

        // Role-based route guard: Admin route check
        if (state.matchedLocation.startsWith('/admin') && user.role != 'admin') {
          return '/guru/dashboard';
        }

        // Role-based route guard: Guru route check
        if (state.matchedLocation.startsWith('/guru') && user.role != 'guru') {
          return '/admin/dashboard';
        }

        return null;
      },
      routes: [
        // Root / Callback Routes
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login-callback',
          builder: (context, state) => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
        // Splash Route
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        // About App Route
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutAppScreen(),
        ),
        // Auth Routes
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => ResetPasswordScreen(
            queryParameters: state.uri.queryParameters,
          ),
        ),

        // Guru Module shell (Dashboard, Jadwal, Jurnal, Profil inside MainShell bottom nav)
        GoRoute(
          path: '/guru/dashboard',
          builder: (context, state) => const GuruMainShell(),
        ),
        // We can route detailed/form pages separately or as children
        GoRoute(
          path: '/guru/schedule/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DetailJadwalScreen(scheduleId: id);
          },
        ),
        GoRoute(
          path: '/guru/journal-form',
          builder: (context, state) {
            final scheduleId = state.uri.queryParameters['scheduleId'] ?? '';
            return FormJurnalScreen(scheduleId: scheduleId);
          },
        ),
        GoRoute(
          path: '/guru/journal/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return DetailJurnalScreen(journalId: id);
          },
        ),

        // Admin Module Routes
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/approvals',
          builder: (context, state) => const ApprovalJurnalScreen(),
        ),
        GoRoute(
          path: '/admin/master-data/periods',
          builder: (context, state) => const MasterPeriodScreen(),
        ),
        GoRoute(
          path: '/admin/master-data/subjects',
          builder: (context, state) => const MasterSubjectScreen(),
        ),
        GoRoute(
          path: '/admin/master-data/hours',
          builder: (context, state) => const MasterHourScreen(),
        ),
        GoRoute(
          path: '/admin/master-data/classes',
          builder: (context, state) => const MasterClassScreen(),
        ),
        GoRoute(
          path: '/admin/master-data/teachers',
          builder: (context, state) => const MasterTeacherScreen(),
        ),
        GoRoute(
          path: '/admin/schedules',
          builder: (context, state) => const MasterScheduleScreen(),
        ),
        GoRoute(
          path: '/admin/weekly-schedules',
          builder: (context, state) => const JadwalMingguanScreen(),
        ),
        GoRoute(
          path: '/admin/settings',
          builder: (context, state) => const AdminSettingsScreen(),
        ),
        GoRoute(
          path: '/admin/master-data/users',
          builder: (context, state) => const MasterUserScreen(),
        ),
        GoRoute(
          path: '/admin/profile',
          builder: (context, state) => const AdminProfileScreen(),
        ),
      ],
    );
  }
}
