import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/school_model.dart';
import '../../core/utils/helper.dart';
import '../../core/utils/image_crop_helper.dart';
import '../../widgets/wave_clipper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _schoolCodeController = TextEditingController();

  final _schoolCodeFocusNode = FocusNode();
  final _fullNameFocusNode = FocusNode();
  final _phoneNumberFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  File? _profileImage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _registerType = 'guru'; // 'guru' or 'admin'
  final List<String> _selectedSchools = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _positionController.dispose();
    _addressController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _schoolCodeController.dispose();

    _schoolCodeFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _phoneNumberFocusNode.dispose();
    _addressFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final result = await pickAndCropImage(
        context: context,
        source: source,
      );
      if (result != null) {
        final tempDir = Directory.systemTemp;
        final tempFile = File(
          '${tempDir.path}/profile_crop_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(result.bytes);

        setState(() {
          _profileImage = tempFile;
        });
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(
          context,
          'Gagal memproses gambar: $e',
          isError: true,
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 8.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'Pilih Sumber Foto',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(
                  Icons.photo_library_outlined,
                  color: Color.fromARGB(255, 37, 99, 235),
                ),
              ),
              title: const Text('Galeri Foto'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(
                  Icons.camera_alt_outlined,
                  color: Color.fromARGB(255, 37, 99, 235),
                ),
              ),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickImage(ImageSource.camera);
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSchools.isEmpty) {
        AppHelper.showSnackBar(
          context,
          'Silakan pilih minimal 1 sekolah.',
          isError: true,
        );
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        AppHelper.showSnackBar(
          context,
          'Konfirmasi password tidak cocok',
          isError: true,
        );
        return;
      }

      final isTeacherRegister = _registerType == 'guru';
      final assignedRole = isTeacherRegister ? 'pending_guru' : 'admin';

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneNumberController.text.trim(),
        position: isTeacherRegister
            ? _positionController.text.trim()
            : 'Admin Sekolah (${_schoolCodeController.text.trim().toUpperCase()})',
        address: _addressController.text.trim(),
        role: assignedRole,
        photoUrl: _profileImage?.path,
        schoolName: _selectedSchools.join(', '),
      );

      if (success && mounted) {
        if (!isTeacherRegister) {
          // Auto login admin upon registration
          await authProvider.login(
            _emailController.text.trim(),
            _passwordController.text,
          );
          if (mounted) {
            AppHelper.showSnackBar(
              context,
              'Registrasi Admin Sekolah Berhasil! Selamat datang.',
            );
            context.go('/admin/dashboard');
          }
          return;
        }

        // For Teacher registration (pending verification)
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Registrasi Guru Berhasil'),
            content: Text(
              'Akun Guru Anda telah berhasil didaftarkan.\n\nHarap tunggu persetujuan dan verifikasi dari Admin Sekolah tempat Anda mengajar (${_selectedSchools.join(', ')}) sebelum dapat masuk.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  if (mounted) {
                    context.pop();
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (mounted) {
        AppHelper.showSnackBar(
          context,
          authProvider.errorMessage ?? 'Gagal melakukan registrasi.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final masterProvider = context.watch<MasterDataProvider>();

    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: kIsWeb ? 16 : 24.w,
                vertical: kIsWeb ? 16 : 32.h,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: kIsWeb ? 420 : 480),
                child: Card(
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
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
                              height: kIsWeb ? 130 : 155.h,
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
                                top: kIsWeb ? 16 : 20.h,
                                bottom: kIsWeb ? 28 : 36.h,
                                left: 16.w,
                                right: 16.w,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/logoJurnalMengajarLogin.png',
                                    height: kIsWeb ? 40 : 52.h,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Form Section
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          kIsWeb ? 20 : 28.w,
                          kIsWeb ? 8 : 8.h,
                          kIsWeb ? 20 : 28.w,
                          kIsWeb ? 20 : 28.h,
                        ),
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.enter): () {
                              if (_schoolCodeFocusNode.hasFocus) {
                                _resolveSchoolCode(_schoolCodeController.text.trim(), masterProvider, showSnackBar: true);
                                FocusScope.of(context).requestFocus(_fullNameFocusNode);
                              } else {
                                if (!isLoading) {
                                  _handleRegister();
                                }
                              }
                            },
                            const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
                              if (_schoolCodeFocusNode.hasFocus) {
                                _resolveSchoolCode(_schoolCodeController.text.trim(), masterProvider, showSnackBar: true);
                                FocusScope.of(context).requestFocus(_fullNameFocusNode);
                              } else {
                                if (!isLoading) {
                                  _handleRegister();
                                }
                              }
                            },
                          },
                          child: Form(
                            key: _formKey,
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Toggle Switch Opsi Pendaftaran (Guru vs Admin Sekolah)
                              _buildFieldLabel('TIPE PENDAFTARAN'),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                padding: EdgeInsets.all(4.w),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _registerType = 'guru'),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: EdgeInsets.symmetric(vertical: 10.h),
                                          decoration: BoxDecoration(
                                            color: _registerType == 'guru'
                                                ? const Color.fromARGB(255, 37, 99, 235)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.school_rounded,
                                                size: 16.r,
                                                color: _registerType == 'guru'
                                                    ? Colors.white
                                                    : const Color(0xFF64748B),
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                'Register Guru',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: _registerType == 'guru'
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _registerType = 'admin'),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: EdgeInsets.symmetric(vertical: 10.h),
                                          decoration: BoxDecoration(
                                            color: _registerType == 'admin'
                                                ? const Color.fromARGB(255, 37, 99, 235)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.admin_panel_settings_rounded,
                                                size: 16.r,
                                                color: _registerType == 'admin'
                                                    ? Colors.white
                                                    : const Color(0xFF64748B),
                                              ),
                                              SizedBox(width: 6.w),
                                              Text(
                                                'Admin Sekolah',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: _registerType == 'admin'
                                                      ? Colors.white
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                _registerType == 'guru'
                                    ? '* Pendaftaran akun Guru memerlukan persetujuan dari Admin Sekolah yang bersangkutan.'
                                    : '* Pendaftaran Admin Sekolah memerlukan Kode Sekolah resmi dari Superadmin untuk aktivasi.',
                                style: TextStyle(
                                  fontSize: 11.5.sp,
                                  color: const Color(0xFF2563EB),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              SizedBox(height: 20.h),

                              // Profile image picker
                              Center(
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 46.r,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      backgroundImage: _profileImage != null
                                          ? FileImage(_profileImage!)
                                          : null,
                                      child: _profileImage == null
                                          ? Icon(
                                              Icons.person_outline_rounded,
                                              size: 46.r,
                                              color: Colors.grey[400],
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _showImageSourceSheet,
                                        child: Container(
                                          padding: EdgeInsets.all(6.w),
                                          decoration: const BoxDecoration(
                                            color: Color.fromARGB(255, 37, 99, 235),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.camera_alt,
                                            size: 16.r,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 24.h),

                              // Sekolah Tempat Mengajar / Mengelola (Wajib) - Kolom bertanda kunci untuk NPSN/Kode Sekolah
                              _buildFieldLabel(_registerType == 'guru' ? 'SEKOLAH TEMPAT MENGAJAR (MASUKKAN KODE/NPSN)' : 'SEKOLAH YANG DIKELOLA (MASUKKAN KODE/NPSN)'),
                              TextFormField(
                                controller: _schoolCodeController,
                                focusNode: _schoolCodeFocusNode,
                                textCapitalization: TextCapitalization.characters,
                                decoration: InputDecoration(
                                  hintText: 'Masukkan Kode Sekolah / NPSN...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.normal,
                                  ),
                                  prefixIcon: const Icon(Icons.key_rounded, color: Color.fromARGB(255, 37, 99, 235)),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_schoolCodeController.text.isNotEmpty || _selectedSchools.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              _schoolCodeController.clear();
                                              _selectedSchools.clear();
                                            });
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.check_circle, color: Color.fromARGB(255, 37, 99, 235)),
                                        onPressed: () {
                                          _resolveSchoolCode(_schoolCodeController.text.trim(), masterProvider);
                                        },
                                      ),
                                    ],
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFEFF6FF).withValues(alpha: 0.5),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                    borderSide: BorderSide(
                                      color: _selectedSchools.isEmpty ? Colors.red : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                    borderSide: BorderSide(
                                      color: _selectedSchools.isEmpty ? Colors.red : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedSchools.clear();
                                  });
                                },
                                onFieldSubmitted: (val) {
                                  _resolveSchoolCode(val.trim(), masterProvider, showSnackBar: true);
                                  FocusScope.of(context).requestFocus(_fullNameFocusNode);
                                },
                                validator: (value) {
                                  if (_selectedSchools.isEmpty) {
                                    return 'Tekan tombol centang biru untuk verifikasi NPSN Sekolah';
                                  }
                                  return null;
                                },
                              ),
                              if (_selectedSchools.isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF166534), size: 18),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          'Terverifikasi: ${_selectedSchools.join(', ')}',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF166534),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              SizedBox(height: 16.h),

                               // Nama Lengkap
                               _buildFieldLabel('NAMA LENGKAP'),
                               _buildTextField(
                                 controller: _fullNameController,
                                 focusNode: _fullNameFocusNode,
                                 nextFocusNode: _phoneNumberFocusNode,
                                 hintText: 'Nama lengkap beserta gelar',
                                 icon: Icons.person_outline,
                                 validator: (value) {
                                   if (value == null || value.isEmpty) {
                                     return 'Nama lengkap tidak boleh kosong';
                                   }
                                   return null;
                                 },
                               ),
                               SizedBox(height: 16.h),

                               // Jabatan (khusus guru)
                               if (_registerType == 'guru') ...[
                                 _buildFieldLabel('JABATAN'),
                                 GestureDetector(
                                   onTap: () {
                                     final subjectNames = masterProvider.subjects.map((s) => s.name).toList();
                                     _showPositionSelector(
                                       context,
                                       subjectNames,
                                       _positionController.text,
                                       (selected) {
                                         setState(() {
                                           _positionController.text = selected;
                                         });
                                       },
                                     );
                                   },
                                   child: AbsorbPointer(
                                     child: _buildTextField(
                                       controller: _positionController,
                                       hintText: 'Ketuk untuk memilih jabatan / guru mapel...',
                                       icon: Icons.work_outline,
                                       suffixIcon: const Icon(
                                         Icons.arrow_drop_down,
                                         color: Color.fromARGB(255, 37, 99, 235),
                                       ),
                                       validator: (value) {
                                         if (_registerType == 'guru' && (value == null || value.isEmpty)) {
                                           return 'Jabatan tidak boleh kosong';
                                         }
                                         return null;
                                       },
                                     ),
                                   ),
                                 ),
                                 SizedBox(height: 16.h),
                               ],

                              // Nomor Telepon
                              _buildFieldLabel('NOMOR TELEPON'),
                              _buildTextField(
                                controller: _phoneNumberController,
                                focusNode: _phoneNumberFocusNode,
                                nextFocusNode: _addressFocusNode,
                                hintText: 'Contoh: 08123456789',
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Nomor telepon tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Alamat
                              _buildFieldLabel('ALAMAT'),
                              _buildTextField(
                                controller: _addressController,
                                focusNode: _addressFocusNode,
                                nextFocusNode: _emailFocusNode,
                                hintText: 'Alamat tempat tinggal',
                                icon: Icons.home_outlined,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Alamat tidak boleh kosong';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Email
                              _buildFieldLabel('EMAIL'),
                              _buildTextField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                nextFocusNode: _passwordFocusNode,
                                hintText: 'guru@sekolah.id',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
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
                              ),
                              SizedBox(height: 16.h),

                              // Password
                              _buildFieldLabel('KATA SANDI'),
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
                                },
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Password tidak boleh kosong';
                                  }
                                  if (value.length < 6) {
                                    return 'Password minimal 6 karakter';
                                  }
                                  return null;
                                },
                                decoration: _getInputDecoration(
                                  hintText: 'Password minimal 6 karakter',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // Confirm Password
                              _buildFieldLabel('KONFIRMASI KATA SANDI'),
                              TextFormField(
                                controller: _confirmPasswordController,
                                focusNode: _confirmPasswordFocusNode,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleRegister(),
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Konfirmasi password tidak boleh kosong';
                                  }
                                  return null;
                                },
                                decoration: _getInputDecoration(
                                  hintText: 'Ulangi password',
                                  prefixIcon: Icons.lock_clock_outlined,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey,
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
                              SizedBox(height: 32.h),

                              // Register Button
                              ElevatedButton(
                                onPressed: isLoading ? null : _handleRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color.fromARGB(255, 37, 99, 235),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: const Color.fromARGB(255, 37, 99, 235).withValues(alpha: 0.4),
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
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
                                        'Daftar Sekarang',
                                        style: TextStyle(
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                              SizedBox(height: 24.h),

                              // Login Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sudah punya akun? ',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.pop(),
                                    child: Text(
                                      'Masuk Sekarang',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color.fromARGB(255, 37, 99, 235),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
            Positioned(
              top: 16.h,
              right: 16.w,
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return IconButton(
                    icon: Icon(
                      themeProvider.isDarkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      themeProvider.toggleTheme(!themeProvider.isDarkMode);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    required FormFieldValidator<String> validator,
    Widget? suffixIcon,
    TextInputAction textInputAction = TextInputAction.next,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      focusNode: focusNode,
      onFieldSubmitted: (value) {
        if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        }
      },
      style: TextStyle(fontSize: 14.sp, color: Theme.of(context).colorScheme.onSurface),
      validator: validator,
      decoration: _getInputDecoration(
        hintText: hintText,
        prefixIcon: icon,
        suffixIcon: suffixIcon,
      ),
    );
  }

  void _showPositionSelector(
    BuildContext context,
    List<String> subjects,
    String currentPosition,
    Function(String) onSelect,
  ) {
    final searchController = TextEditingController();
    List<String> options = subjects.map((s) => 'Guru $s').toSet().toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final query = searchController.text.toLowerCase();
          final filteredOptions = options
              .where((opt) => opt.toLowerCase().contains(query))
              .toList();

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SizedBox(
              height: 400.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pilih Jabatan / Guru Mapel',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: 'Cari mata pelajaran / jabatan...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: filteredOptions.isEmpty
                        ? const Center(child: Text('Tidak ada pilihan ditemukan'))
                        : ListView.builder(
                            itemCount: filteredOptions.length,
                            itemBuilder: (context, index) {
                              final opt = filteredOptions[index];
                              final isSelected = opt.toLowerCase() == currentPosition.toLowerCase();
                              return ListTile(
                                title: Text(
                                  opt,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? const Color.fromARGB(255, 37, 99, 235) : null,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check, color: Color.fromARGB(255, 37, 99, 235))
                                    : null,
                                onTap: () {
                                  onSelect(opt);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  void _resolveSchoolCode(String inputCode, MasterDataProvider masterProvider, {bool showSnackBar = true}) {
    if (inputCode.trim().isEmpty) return;

    final cleanCode = inputCode.toUpperCase().replaceAll(RegExp(r'\s+'), '');

    SchoolModel? matchedSchool;
    for (final s in masterProvider.schools) {
      final sCode = s.code?.toUpperCase().replaceAll(RegExp(r'\s+'), '') ?? '';
      final sNpsn = s.npsn?.toUpperCase().replaceAll(RegExp(r'\s+'), '') ?? '';
      final sNss = s.nss?.toUpperCase().replaceAll(RegExp(r'\s+'), '') ?? '';
      final sId = s.id.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      final sName = s.name.toUpperCase().replaceAll(RegExp(r'\s+'), '');

      // Strict exact match for Code, NPSN, NSS, ID, or exact School Name
      if ((sCode.isNotEmpty && sCode == cleanCode) ||
          (sNpsn.isNotEmpty && sNpsn == cleanCode) ||
          (sNss.isNotEmpty && sNss == cleanCode) ||
          (sId.isNotEmpty && sId == cleanCode) ||
          (sName.isNotEmpty && sName == cleanCode)) {
        matchedSchool = s;
        break;
      }
    }

    String? foundName = matchedSchool?.name;

    if (foundName != null && foundName.isNotEmpty) {
      final validSchoolName = foundName;
      setState(() {
        _selectedSchools.clear();
        _selectedSchools.add(validSchoolName);
      });
      if (showSnackBar) {
        AppHelper.showSnackBar(context, 'Sekolah ditemukan: $validSchoolName');
      }
    } else {
      setState(() {
        _selectedSchools.clear();
      });
      if (showSnackBar) {
        AppHelper.showSnackBar(context, 'Tidak terdapat sekolah dengan kode ini, mungkin berlangganan pada jmpanel.vercel.app telah expired/school dihapus', isError: true);
      }
    }
  }

  InputDecoration _getInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(prefixIcon, color: const Color.fromARGB(255, 37, 99, 235)),
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
        borderSide: const BorderSide(color: Color.fromARGB(255, 37, 99, 235), width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
    );
  }
}
