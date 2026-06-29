import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      _navigateWhenReady();
    });
  }

  void _navigateWhenReady() {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.initialized) {
      // Auth state not loaded yet — poll until ready
      Future.delayed(const Duration(milliseconds: 200), _navigateWhenReady);
      return;
    }
    if (authProvider.isAuthenticated) {
      final role = authProvider.currentUser?.role ?? 'guru';
      if (role == 'admin') {
        context.go('/admin/dashboard');
      } else {
        context.go('/guru/dashboard');
      }
    } else {
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: child,
              ),
            );
          },
          child: Image.asset(
            'assets/LogoJr.png',
            width: 180,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
