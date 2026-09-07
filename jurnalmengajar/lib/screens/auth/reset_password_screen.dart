import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/utils/helper.dart';
import '../../widgets/wave_clipper.dart';

class ResetPasswordScreen extends StatefulWidget {
  final Map<String, String> queryParameters;

  const ResetPasswordScreen({super.key, this.queryParameters = const {}});

  bool get isRecoveryMode {
    return queryParameters['type'] == 'recovery' ||
        queryParameters.containsKey('access_token');
  }

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (widget.isRecoveryMode || authProvider.isRecoveryMode) {
      _emailController.text =
          widget.queryParameters['email'] ??
          authProvider.currentUser?.email ??
          '';
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (widget.isRecoveryMode || authProvider.isRecoveryMode) {
        final newPassword = _passwordController.text.trim();
        final success = await authProvider.updatePassword(newPassword);
        if (success && mounted) {
          AppHelper.showSnackBar(context, 'Password berhasil diubah!');
          final user = authProvider.currentUser;
          if (user != null && user.role == 'admin') {
            context.go('/admin/dashboard');
          } else {
            context.go('/guru/dashboard');
          }
        } else if (mounted) {
          AppHelper.showSnackBar(
            context,
            authProvider.errorMessage ??
                'Gagal memperbarui password. Silakan coba lagi.',
            isError: true,
          );
        }
      } else {
        final success =
            await authProvider.resetPassword(_emailController.text.trim());
        if (success && mounted) {
          AppHelper.showSnackBar(
            context,
            'Link reset password berhasil dikirim ke email Anda!',
          );
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/login');
          }
        } else if (mounted) {
          AppHelper.showSnackBar(
            context,
            authProvider.errorMessage ??
                'Gagal memproses reset password. Periksa kembali email Anda.',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading;
    final isRecoveryMode = widget.isRecoveryMode || authProvider.isRecoveryMode;

    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 16 : 24.w,
                vertical: kIsWeb ? 16 : 32.h,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: kIsWeb ? 380 : 440),
                child: Card(
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  color:
                      Theme.of(context).cardTheme.color ??
                      Theme.of(context).colorScheme.surface,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section with Wave
                      Stack(
                        children: [
                          ClipPath(
                            clipper: const WaveClipper(),
                            child: Container(
                              height: kIsWeb ? 145 : 170.h,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color.fromARGB(255, 30, 64, 175),
                                    Color.fromARGB(255, 29, 78, 216),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: kIsWeb ? 12 : 16.h,
                                bottom: kIsWeb ? 36 : 46.h,
                                left: 16.w,
                                right: 16.w,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(11.w),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isRecoveryMode
                                          ? Icons.lock_reset_rounded
                                          : Icons.email_outlined,
                                      size: 34.sp,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8.h,
                            left: 8.w,
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 22.sp,
                              ),
                              tooltip: 'Kembali ke Login',
                              onPressed: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/login');
                                }
                              },
                            ),
                          ),
                          Positioned(
                            top: 8.h,
                            right: 8.w,
                            child: Consumer<ThemeProvider>(
                              builder: (context, themeProvider, child) {
                                return IconButton(
                                  icon: Icon(
                                    themeProvider.isDarkMode
                                        ? Icons.dark_mode_rounded
                                        : Icons.light_mode_rounded,
                                    color: Colors.white,
                                    size: 22.sp,
                                  ),
                                  tooltip: themeProvider.isDarkMode
                                      ? 'Mode Gelap'
                                      : 'Mode Terang',
                                  onPressed: () {
                                    themeProvider.toggleTheme(
                                      !themeProvider.isDarkMode,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // Form Section
                      Padding(
                        padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 20.h),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                isRecoveryMode
                                    ? 'Ubah Password'
                                    : 'Lupa Password?',
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                isRecoveryMode
                                    ? 'Masukkan password baru Anda untuk mengaktifkan kembali akun.'
                                    : 'Masukkan email terdaftar Anda. Kami akan mengirimkan tautan untuk mengatur ulang kata sandi.',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(height: 16.h),

                              if (!isRecoveryMode) ...[
                                // Email field label
                                Text(
                                  'EMAIL TERDAFTAR',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Email tidak boleh kosong';
                                    }
                                    if (!RegExp(
                                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                    ).hasMatch(value)) {
                                      return 'Format email tidak valid';
                                    }
                                    return null;
                                  },
                                  decoration: _inputDecoration(
                                    context,
                                    hintText: 'nama@sekolah.id',
                                    icon: Icons.email_outlined,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                              ],

                              if (isRecoveryMode) ...[
                                // New Password
                                Text(
                                  'PASSWORD BARU',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Password baru tidak boleh kosong';
                                    }
                                    if (value.length < 6) {
                                      return 'Password minimal 6 karakter';
                                    }
                                    return null;
                                  },
                                  decoration: _inputDecoration(
                                    context,
                                    hintText: 'Password minimal 6 karakter',
                                    icon: Icons.lock_outline,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20.h),

                                // Confirm Password
                                Text(
                                  'KONFIRMASI PASSWORD',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF94A3B8),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Konfirmasi password tidak boleh kosong';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Password tidak cocok';
                                    }
                                    return null;
                                  },
                                  decoration: _inputDecoration(
                                    context,
                                    hintText: 'Ulangi password baru',
                                    icon: Icons.lock_clock_outlined,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: const Color(0xFF2563EB),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.h),
                              ],

                              // Submit Button
                              ElevatedButton(
                                onPressed: isLoading ? null : _handleReset,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.4),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                ),
                                child: isLoading
                                    ? SizedBox(
                                        height: 20.w,
                                        width: 20.w,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        isRecoveryMode
                                            ? 'Simpan Password'
                                            : 'Kirim Link Reset',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              SizedBox(height: 20.h),

                              // Back to login link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Ingat password? ',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      if (context.canPop()) {
                                        context.pop();
                                      } else {
                                        context.go('/login');
                                      }
                                    },
                                    child: Text(
                                      'Kembali Login',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(
        icon,
        color: const Color.fromARGB(255, 37, 99, 235),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : const Color(0xFFEFF6FF).withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(
          color: Color.fromARGB(255, 37, 99, 235),
          width: 2,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        vertical: 10.h,
        horizontal: 12.w,
      ),
    );
  }
}
