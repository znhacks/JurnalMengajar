import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/helper.dart';

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

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (widget.isRecoveryMode || authProvider.isRecoveryMode) {
      _emailController.text = widget.queryParameters['email'] ?? authProvider.currentUser?.email ?? '';
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
          AppHelper.showSnackBar(
            context,
            'Password berhasil diubah!',
          );
          // After password is updated the recovery session is still valid;
          // navigate directly to the user's dashboard based on their role.
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
        final success = await authProvider.resetPassword(_emailController.text.trim());
        if (success && mounted) {
          AppHelper.showSnackBar(
            context,
            'Link reset password berhasil dikirim ke email Anda!',
          );
          context.pop(); // Go back to login
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
      appBar: AppBar(
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20.h),
                Icon(
                  Icons.lock_reset_rounded,
                  size: 80.w,
                  color: const Color(0xFF0D9488),
                ),
                SizedBox(height: 24.h),
                Text(
                  isRecoveryMode ? 'Ubah Password' : 'Lupa Password?',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12.h),
                Text(
                  isRecoveryMode
                      ? 'Masukkan password baru Anda untuk mengaktifkan kembali akun.'
                      : 'Masukkan email Anda di bawah. Kami akan mengirimkan tautan untuk mengatur ulang kata sandi Anda.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 40.h),
                if (!isRecoveryMode) ...[
                  Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email tidak boleh kosong';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Masukkan email terdaftar',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  SizedBox(height: 32.h),
                ],
                if (isRecoveryMode) ...[
                  Text(
                    'Password Baru',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password baru tidak boleh kosong';
                      }
                      if (value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Masukkan password baru',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Konfirmasi Password',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Konfirmasi password tidak boleh kosong';
                      }
                      if (value != _passwordController.text) {
                        return 'Password tidak cocok';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Konfirmasi password baru',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                  ),
                  SizedBox(height: 32.h),
                ],
                ElevatedButton(
                  onPressed: isLoading ? null : _handleReset,
                  child: isLoading
                      ? SizedBox(
                          height: 24.w,
                          width: 24.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(isRecoveryMode ? 'Simpan Password' : 'Kirim Link Reset'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
