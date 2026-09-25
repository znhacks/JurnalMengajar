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
  final List<String>? initialSelectedSchools;
  final String? initialSchoolId;

  const RegisterScreen({
    super.key,
    this.initialSelectedSchools,
    this.initialSchoolId,
  });

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
  final _schoolNameController = TextEditingController();
  final _nipController = TextEditingController();

  final _schoolCodeFocusNode = FocusNode();
  final _schoolNameFocusNode = FocusNode();
  final _fullNameFocusNode = FocusNode();
  final _nipFocusNode = FocusNode();
  final _phoneNumberFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  Uint8List? _profileImageBytes;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _registerType = 'guru'; // 'guru' or 'admin'
  final List<String> _selectedSchools = [];
  String? _resolvedSchoolId;
  String? _detectedPlan;
  String? _schoolErrorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedSchools != null &&
        widget.initialSelectedSchools!.isNotEmpty) {
      _selectedSchools.addAll(widget.initialSelectedSchools!);
      _resolvedSchoolId = widget.initialSchoolId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resolvedSchoolId != null && _resolvedSchoolId!.isNotEmpty) {
        Provider.of<MasterDataProvider>(
          context,
          listen: false,
        ).loadAllData(_resolvedSchoolId);
      } else {
        Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
      }
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
    _schoolNameController.dispose();
    _nipController.dispose();

    _schoolCodeFocusNode.dispose();
    _schoolNameFocusNode.dispose();
    _fullNameFocusNode.dispose();
    _nipFocusNode.dispose();
    _phoneNumberFocusNode.dispose();
    _addressFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final result = await pickAndCropImage(context: context, source: source);
      if (result != null) {
        setState(() {
          _profileImageBytes = result.bytes;
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
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
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
      final isTeacherRegister = _registerType == 'guru';
      final assignedRole = isTeacherRegister ? 'pending_guru' : 'admin';

      if (isTeacherRegister && _selectedSchools.isEmpty) {
        AppHelper.showSnackBar(
          context,
          'Silakan verifikasi kode sekolah tempat Anda mengajar terlebih dahulu.',
          isError: true,
        );
        return;
      }

      if (!isTeacherRegister && _schoolNameController.text.trim().isEmpty) {
        AppHelper.showSnackBar(
          context,
          'Silakan masukkan nama sekolah yang dikelola.',
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

      final schoolName = isTeacherRegister
          ? _selectedSchools.join(', ')
          : _schoolNameController.text.trim();
      final schoolId = _resolvedSchoolId ?? _schoolCodeController.text.trim();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneNumberController.text.trim(),
        position: isTeacherRegister
            ? _positionController.text.trim()
            : 'Admin Sekolah ($schoolName)',
        address: _addressController.text.trim(),
        role: assignedRole,
        photoUrl: null,
        schoolName: schoolName,
        schoolId: schoolId,
        nip: isTeacherRegister
            ? (_nipController.text.trim().isEmpty
                  ? null
                  : _nipController.text.trim())
            : null,
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
              'Registrasi Admin Sekolah Berhasil! Selamat datang di $schoolName.',
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
              'Akun Guru Anda telah berhasil didaftarkan.\n\nHarap tunggu persetujuan dan verifikasi dari Admin Sekolah tempat Anda mengajar ($schoolName) sebelum dapat masuk.',
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
        child: SafeArea(
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
                        padding: EdgeInsets.fromLTRB(
                          kIsWeb ? 20 : 28.w,
                          kIsWeb ? 8 : 8.h,
                          kIsWeb ? 20 : 28.w,
                          kIsWeb ? 20 : 28.h,
                        ),
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.enter,
                            ): () {
                              if (_schoolCodeFocusNode.hasFocus) {
                                _resolveSchoolCode(
                                  _schoolCodeController.text.trim(),
                                  masterProvider,
                                  showSnackBar: true,
                                );
                                FocusScope.of(
                                  context,
                                ).requestFocus(_fullNameFocusNode);
                              } else {
                                if (!isLoading) {
                                  _handleRegister();
                                }
                              }
                            },
                            const SingleActivator(
                              LogicalKeyboardKey.numpadEnter,
                            ): () {
                              if (_schoolCodeFocusNode.hasFocus) {
                                _resolveSchoolCode(
                                  _schoolCodeController.text.trim(),
                                  masterProvider,
                                  showSnackBar: true,
                                );
                                FocusScope.of(
                                  context,
                                ).requestFocus(_fullNameFocusNode);
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
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                  padding: EdgeInsets.all(4.w),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            _registerType = 'guru';
                                            _schoolErrorMessage = null;
                                          }),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              vertical: 10.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _registerType == 'guru'
                                                  ? const Color.fromARGB(
                                                      255,
                                                      37,
                                                      99,
                                                      235,
                                                    )
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.school_rounded,
                                                  size: 16.r,
                                                  color: _registerType == 'guru'
                                                      ? Colors.white
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  'Register Guru',
                                                  style: TextStyle(
                                                    fontSize: kIsWeb
                                                        ? 13
                                                        : 13.5.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        _registerType == 'guru'
                                                        ? Colors.white
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() {
                                            _registerType = 'admin';
                                            _schoolErrorMessage = null;
                                          }),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              vertical: 10.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _registerType == 'admin'
                                                  ? const Color.fromARGB(
                                                      255,
                                                      37,
                                                      99,
                                                      235,
                                                    )
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(12.r),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons
                                                      .admin_panel_settings_rounded,
                                                  size: 16.r,
                                                  color:
                                                      _registerType == 'admin'
                                                      ? Colors.white
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                ),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  'Admin Sekolah',
                                                  style: TextStyle(
                                                    fontSize: kIsWeb
                                                        ? 13
                                                        : 13.5.sp,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        _registerType == 'admin'
                                                        ? Colors.white
                                                        : Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
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
                                        backgroundColor: const Color(
                                          0xFFF1F5F9,
                                        ),
                                        backgroundImage:
                                            _profileImageBytes != null
                                            ? MemoryImage(_profileImageBytes!)
                                            : null,
                                        child: _profileImageBytes == null
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
                                              color: Color.fromARGB(
                                                255,
                                                37,
                                                99,
                                                235,
                                              ),
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

                                // Sekolah Tempat Mengajar / Mengelola (Wajib)
                                if (_registerType == 'admin') ...[
                                  _buildFieldLabel(
                                    'NAMA SEKOLAH YANG DIKELOLA',
                                  ),
                                  _buildTextField(
                                    controller: _schoolNameController,
                                    focusNode: _schoolNameFocusNode,
                                    nextFocusNode: _schoolCodeFocusNode,
                                    hintText: 'Contoh: SMK Negeri 11 Malang',
                                    icon: Icons.domain_rounded,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Nama sekolah tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 16.h),
                                  _buildFieldLabel(
                                    'KODE PAKET / AKTIVASI DARI JM-PANEL',
                                  ),
                                  TextFormField(
                                    controller: _schoolCodeController,
                                    focusNode: _schoolCodeFocusNode,
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 14.5 : 15.sp,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Contoh: FREE, PRO, atau Kode Voucher...',
                                      hintStyle: TextStyle(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF64748B)
                                            : Colors.grey[400],
                                        fontSize: kIsWeb ? 14 : 14.5.sp,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.key_rounded,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF60A5FA)
                                            : const Color.fromARGB(
                                                255,
                                                37,
                                                99,
                                                235,
                                              ),
                                      ),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_schoolCodeController
                                                  .text
                                                  .isNotEmpty ||
                                              _selectedSchools.isNotEmpty)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.clear_rounded,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _schoolCodeController.clear();
                                                  _selectedSchools.clear();
                                                  _detectedPlan = null;
                                                });
                                              },
                                            ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.check_circle,
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF60A5FA)
                                                  : const Color.fromARGB(
                                                      255,
                                                      37,
                                                      99,
                                                      235,
                                                    ),
                                            ),
                                            onPressed: () {
                                              _resolveSchoolCode(
                                                _schoolCodeController.text
                                                    .trim(),
                                                masterProvider,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      filled: true,
                                      fillColor:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                          : const Color(
                                              0xFFEFF6FF,
                                            ).withValues(alpha: 0.5),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: kIsWeb ? 10 : 12.h,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: BorderSide(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF60A5FA)
                                              : const Color.fromARGB(
                                                  255,
                                                  37,
                                                  99,
                                                  235,
                                                ),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      if (_detectedPlan != null) {
                                        setState(() {
                                          _detectedPlan = null;
                                        });
                                      }
                                    },
                                    onFieldSubmitted: (val) {
                                      _resolveSchoolCode(
                                        val.trim(),
                                        masterProvider,
                                        showSnackBar: true,
                                      );
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(_fullNameFocusNode);
                                    },
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Kode aktivasi / paket tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                  if (_detectedPlan != null ||
                                      _selectedSchools.isNotEmpty) ...[
                                    SizedBox(height: 8.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF86EFAC),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF166534),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Text(
                                              'Paket Terverifikasi: ${_detectedPlan ?? 'AKTIF'}',
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
                                ] else ...[
                                  _buildFieldLabel(
                                    'SEKOLAH TEMPAT MENGAJAR (KODE SEKOLAH / UUID)',
                                  ),
                                  TextFormField(
                                    controller: _schoolCodeController,
                                    focusNode: _schoolCodeFocusNode,
                                    style: TextStyle(
                                      fontSize: kIsWeb ? 14.5 : 15.sp,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'Masukkan Kode Sekolah tempat mengajar...',
                                      hintStyle: TextStyle(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF64748B)
                                            : Colors.grey[400],
                                        fontSize: kIsWeb ? 14 : 14.5.sp,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.key_rounded,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? const Color(0xFF60A5FA)
                                            : const Color.fromARGB(
                                                255,
                                                37,
                                                99,
                                                235,
                                              ),
                                      ),
                                      suffixIcon: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_schoolCodeController
                                                  .text
                                                  .isNotEmpty ||
                                              _selectedSchools.isNotEmpty ||
                                              _schoolErrorMessage != null)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.clear_rounded,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _schoolCodeController.clear();
                                                  _selectedSchools.clear();
                                                  _resolvedSchoolId = null;
                                                  _schoolErrorMessage = null;
                                                  _positionController.clear();
                                                });
                                              },
                                            ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.check_circle,
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? const Color(0xFF60A5FA)
                                                  : const Color.fromARGB(
                                                      255,
                                                      37,
                                                      99,
                                                      235,
                                                    ),
                                            ),
                                            onPressed: () {
                                              _resolveSchoolCode(
                                                _schoolCodeController.text
                                                    .trim(),
                                                masterProvider,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      filled: true,
                                      fillColor:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                          : const Color(
                                              0xFFEFF6FF,
                                            ).withValues(alpha: 0.5),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: kIsWeb ? 10 : 12.h,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: BorderSide(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF60A5FA)
                                              : const Color.fromARGB(
                                                  255,
                                                  37,
                                                  99,
                                                  235,
                                                ),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFEF4444),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    onChanged: (val) {
                                      if (_selectedSchools.isNotEmpty ||
                                          _schoolErrorMessage != null) {
                                        setState(() {
                                          _selectedSchools.clear();
                                          _resolvedSchoolId = null;
                                          _schoolErrorMessage = null;
                                          _positionController.clear();
                                        });
                                      }
                                    },
                                    onFieldSubmitted: (val) {
                                      _resolveSchoolCode(
                                        val.trim(),
                                        masterProvider,
                                        showSnackBar: true,
                                      );
                                      FocusScope.of(
                                        context,
                                      ).requestFocus(_fullNameFocusNode);
                                    },
                                    validator: (value) {
                                      if (_selectedSchools.isEmpty) {
                                        if (_schoolErrorMessage != null) {
                                          return _schoolErrorMessage;
                                        }
                                        return 'Tekan tombol centang biru untuk verifikasi Kode Sekolah';
                                      }
                                      return null;
                                    },
                                  ),
                                  if (_selectedSchools.isNotEmpty) ...[
                                    SizedBox(height: 8.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0FDF4),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFF86EFAC),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF166534),
                                            size: 18,
                                          ),
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
                                  ] else if (_schoolErrorMessage != null) ...[
                                    SizedBox(height: 8.h),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(
                                          12.r,
                                        ),
                                        border: Border.all(
                                          color: const Color(0xFFFCA5A5),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.cancel_rounded,
                                            color: Color(0xFFB91C1C),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Text(
                                              _schoolErrorMessage!,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFB91C1C),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                                SizedBox(height: 16.h),

                                // Nama Lengkap
                                _buildFieldLabel('NAMA LENGKAP'),
                                _buildTextField(
                                  controller: _fullNameController,
                                  focusNode: _fullNameFocusNode,
                                  nextFocusNode: _registerType == 'guru'
                                      ? _nipFocusNode
                                      : _phoneNumberFocusNode,
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

                                // NIP (khusus guru)
                                if (_registerType == 'guru') ...[
                                  _buildFieldLabel('NIP (NOMOR INDUK PEGAWAI)'),
                                  _buildTextField(
                                    controller: _nipController,
                                    focusNode: _nipFocusNode,
                                    nextFocusNode: _phoneNumberFocusNode,
                                    hintText:
                                        'Contoh: 198507202010011005 (Kosongkan jika belum ada)',
                                    icon: Icons.badge_outlined,
                                    keyboardType: TextInputType.number,
                                    validator: (value) => null,
                                  ),
                                  SizedBox(height: 16.h),
                                ],

                                // Jabatan (khusus guru)
                                if (_registerType == 'guru') ...[
                                  _buildFieldLabel('JABATAN'),
                                  if (_selectedSchools.isNotEmpty) ...[
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () async {
                                        final effectiveSchoolId =
                                            _resolvedSchoolId;
                                        List<String> subjectNames = [];

                                        try {
                                          if (effectiveSchoolId != null &&
                                              effectiveSchoolId.isNotEmpty) {
                                            final fetched = await masterProvider
                                                .subjectRepository
                                                .getAll(effectiveSchoolId);
                                            if (fetched.isNotEmpty) {
                                              subjectNames = fetched
                                                  .where((s) => s.isActive)
                                                  .map((s) => s.name)
                                                  .toList();
                                            }
                                          }
                                        } catch (e) {
                                          debugPrint(
                                            '[REGISTER] Error fetching subjects from DB: $e',
                                          );
                                        }

                                        // Fallback ke masterProvider.subjects jika terfilter untuk sekolah yang sama
                                        if (subjectNames.isEmpty &&
                                            (effectiveSchoolId == null ||
                                                masterProvider
                                                        .currentSchoolId ==
                                                    effectiveSchoolId)) {
                                          subjectNames = masterProvider.subjects
                                              .where((s) => s.isActive)
                                              .map((s) => s.name)
                                              .toList();
                                        }

                                        if (!context.mounted) return;

                                        _showPositionSelector(
                                          context,
                                          subjectNames,
                                          _positionController.text,
                                          (selected) {
                                            setState(() {
                                              _positionController.text =
                                                  selected;
                                            });
                                          },
                                        );
                                      },
                                      child: AbsorbPointer(
                                        child: _buildTextField(
                                          controller: _positionController,
                                          hintText:
                                              'Ketuk untuk memilih jabatan / guru mapel...',
                                          icon: Icons.work_outline,
                                          suffixIcon: const Icon(
                                            Icons.arrow_drop_down,
                                            color: Color.fromARGB(
                                              255,
                                              37,
                                              99,
                                              235,
                                            ),
                                          ),
                                          validator: (value) {
                                            if (_registerType == 'guru' &&
                                                (value == null ||
                                                    value.isEmpty)) {
                                              return 'Jabatan tidak boleh kosong';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 12.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.5)
                                            : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        border: Border.all(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF334155)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            size: 18.sp,
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF64748B),
                                          ),
                                          SizedBox(width: 10.w),
                                          Expanded(
                                            child: Text(
                                              'Masukkan dan verifikasi Kode Sekolah di atas terlebih dahulu untuk menampilkan pilihan jabatan / mata pelajaran sekolah.',
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color:
                                                    Theme.of(
                                                          context,
                                                        ).brightness ==
                                                        Brightness.dark
                                                    ? const Color(0xFF94A3B8)
                                                    : const Color(0xFF64748B),
                                                height: 1.3,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(_confirmPasswordFocusNode);
                                  },
                                  style: TextStyle(
                                    fontSize: kIsWeb ? 14.5 : 15.sp,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
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
                                    fontSize: kIsWeb ? 14.5 : 15.sp,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
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
                                    backgroundColor: const Color.fromARGB(
                                      255,
                                      37,
                                      99,
                                      235,
                                    ),
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: const Color.fromARGB(
                                      255,
                                      37,
                                      99,
                                      235,
                                    ).withValues(alpha: 0.4),
                                    padding: EdgeInsets.symmetric(
                                      vertical: kIsWeb ? 10 : 13.h,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.r),
                                    ),
                                  ),
                                  child: isLoading
                                      ? SizedBox(
                                          height: 20.w,
                                          width: 20.w,
                                          child:
                                              const CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                        )
                                      : Text(
                                          'Daftar Sekarang',
                                          style: TextStyle(
                                            fontSize: kIsWeb ? 15 : 16.sp,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                SizedBox(height: 24.h),

                                // Login Link
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Sudah punya akun? ',
                                      style: TextStyle(
                                        fontSize: kIsWeb ? 13.5 : 14.sp,
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
                                        'Masuk Sekarang',
                                        style: TextStyle(
                                          fontSize: kIsWeb ? 13.5 : 14.sp,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? const Color(0xFF60A5FA)
                                              : const Color.fromARGB(
                                                  255,
                                                  37,
                                                  99,
                                                  235,
                                                ),
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
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Text(
        label,
        style: TextStyle(
          fontSize: kIsWeb ? 11.5 : 12.sp,
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
      style: TextStyle(
        fontSize: kIsWeb ? 14.5 : 15.sp,
        color: Theme.of(context).colorScheme.onSurface,
      ),
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

    // Ambil mata pelajaran langsung dari database tabel subjects
    final Set<String> allOptionsSet = {};

    for (final s in subjects) {
      final trimmed = s.trim();
      if (trimmed.isNotEmpty) {
        final formatted = trimmed.toLowerCase().startsWith('guru ')
            ? trimmed
            : 'Guru $trimmed';
        allOptionsSet.add(formatted);
      }
    }

    // Jika currentPosition sudah terisi dan belum ada di opsi, sertakan
    if (currentPosition.trim().isNotEmpty) {
      allOptionsSet.add(currentPosition.trim());
    }

    final List<String> options = allOptionsSet.toList()
      ..sort((a, b) => a.compareTo(b));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? const Color(0xFF60A5FA)
        : const Color.fromARGB(255, 37, 99, 235);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Theme.of(context).cardTheme.color ??
          Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final rawQuery = searchController.text.trim();
          final query = rawQuery.toLowerCase();
          final filteredOptions = options
              .where((opt) => opt.toLowerCase().contains(query))
              .toList();
          final hasExactMatch = options.any(
            (opt) => opt.toLowerCase() == query,
          );

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 16.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SizedBox(
              height: 480.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'Pilih Jabatan / Guru Mapel',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: searchController,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Cari mata pelajaran / jabatan...',
                      hintStyle: TextStyle(
                        fontSize: 13.5.sp,
                        color: isDark
                            ? const Color(0xFF64748B)
                            : Colors.grey[400],
                      ),
                      prefixIcon: Icon(Icons.search, color: primaryColor),
                      suffixIcon: rawQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 10.h,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (rawQuery.isNotEmpty && !hasExactMatch) ...[
                    SizedBox(height: 8.h),
                    InkWell(
                      onTap: () {
                        onSelect(rawQuery);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 10.h,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: primaryColor,
                              size: 18.r,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'Gunakan "$rawQuery" sebagai jabatan',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12.r,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Expanded(
                    child: filteredOptions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 40.r,
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  options.isEmpty
                                      ? 'Mata pelajaran belum tersedia di database'
                                      : 'Jabatan tidak ditemukan di daftar',
                                  style: TextStyle(
                                    fontSize: 13.5.sp,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                                if (rawQuery.isNotEmpty) ...[
                                  SizedBox(height: 12.h),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      onSelect(rawQuery);
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.check, size: 16),
                                    label: Text('Gunakan "$rawQuery"'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 8.h,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          10.r,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredOptions.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 0.5,
                              color: isDark
                                  ? Colors.grey[800]
                                  : const Color(0xFFF1F5F9),
                            ),
                            itemBuilder: (context, index) {
                              final opt = filteredOptions[index];
                              final isSelected =
                                  opt.toLowerCase() ==
                                  currentPosition.toLowerCase();
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                title: Text(
                                  opt,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? primaryColor
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                                trailing: isSelected
                                    ? Icon(
                                        Icons.check_circle_rounded,
                                        color: primaryColor,
                                        size: 20.r,
                                      )
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

  Future<void> _resolveSchoolCode(
    String inputCode,
    MasterDataProvider masterProvider, {
    bool showSnackBar = true,
  }) async {
    if (inputCode.trim().isEmpty) return;

    final cleanCode = inputCode.trim();

    try {
      final remoteMatched = await masterProvider.validateActivationCode(
        cleanCode,
      );
      if (remoteMatched != null) {
        if (remoteMatched.isInactive) {
          setState(() {
            _selectedSchools.clear();
            _resolvedSchoolId = null;
            _detectedPlan = null;
          });
          if (showSnackBar && mounted) {
            AppHelper.showSnackBar(
              context,
              'Aktivasi sekolah sedang dinonaktifkan oleh administrator.',
              isError: true,
            );
          }
          return;
        }

        if (_registerType == 'admin') {
          if (_schoolNameController.text.trim().isEmpty &&
              remoteMatched.name.isNotEmpty &&
              remoteMatched.name != 'Sekolah') {
            _schoolNameController.text = remoteMatched.name;
          }
          final effectiveSchoolName =
              _schoolNameController.text.trim().isNotEmpty
              ? _schoolNameController.text.trim()
              : (remoteMatched.name.isNotEmpty
                    ? remoteMatched.name
                    : 'Sekolah');
          setState(() {
            _selectedSchools.clear();
            _selectedSchools.add(effectiveSchoolName);
            _resolvedSchoolId = remoteMatched.id.isNotEmpty
                ? remoteMatched.id
                : null;
            _detectedPlan =
                '${remoteMatched.plan.toUpperCase()} PLAN (${remoteMatched.maxTeachers} Guru)';
          });
          if (showSnackBar && mounted) {
            AppHelper.showSnackBar(
              context,
              'Kode terverifikasi! Paket: ${remoteMatched.plan.toUpperCase()}',
            );
          }
          return;
        } else {
          // Guru: HANYA jika memiliki nama sekolah riil (bukan dummy voucher tanpa nama)
          final isRealSchool = remoteMatched.name.trim().isNotEmpty &&
              remoteMatched.name.trim().toLowerCase() != 'sekolah';
          if (isRealSchool) {
            final schoolName = remoteMatched.name.trim();
            setState(() {
              _selectedSchools.clear();
              _selectedSchools.add(schoolName);
              _resolvedSchoolId = remoteMatched.id;
              _detectedPlan = null;
              _schoolErrorMessage = null;
              _positionController.clear();
            });
            if (remoteMatched.id.isNotEmpty) {
              masterProvider.loadAllData(remoteMatched.id);
            }
            if (showSnackBar && mounted) {
              AppHelper.showSnackBar(context, 'Sekolah ditemukan: $schoolName');
            }
            return;
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('dinonaktifkan')) {
        setState(() {
          _selectedSchools.clear();
          _resolvedSchoolId = null;
          _detectedPlan = null;
        });
        if (showSnackBar && mounted) {
          AppHelper.showSnackBar(
            context,
            'Aktivasi sekolah sedang dinonaktifkan oleh administrator.',
            isError: true,
          );
        }
        return;
      }
    }

    final searchCode = cleanCode.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    SchoolModel? matchedSchool;
    for (final s in masterProvider.schools) {
      final sCode = s.code?.toUpperCase().replaceAll(RegExp(r'\s+'), '') ?? '';
      final sNpsn = s.npsn?.toUpperCase().replaceAll(RegExp(r'\s+'), '') ?? '';
      final sNss = s.nss?.toUpperCase().replaceAll(RegExp(r'\s+'), '') ?? '';
      final sId = s.id.toUpperCase().replaceAll(RegExp(r'\s+'), '');
      final sName = s.name.toUpperCase().replaceAll(RegExp(r'\s+'), '');

      // Strict exact match for Code, NPSN, NSS, ID
      // Untuk pendaftaran Guru: HANYA kode sekolah resmi (JM Panel), NPSN, NSS, atau ID!
      // JANGAN mencocokkan nama sekolah jika kodenya tidak sesuai dengan JM Panel.
      final isCodeMatch = (sCode.isNotEmpty && sCode == searchCode) ||
          (sNpsn.isNotEmpty && sNpsn == searchCode) ||
          (sNss.isNotEmpty && sNss == searchCode) ||
          (sId.isNotEmpty && sId == searchCode);
      final isNameMatch = _registerType == 'admin' &&
          (sName.isNotEmpty && sName == searchCode);

      if (isCodeMatch || isNameMatch) {
        matchedSchool = s;
        break;
      }
    }

    String? foundName = matchedSchool?.name;

    if (matchedSchool != null && matchedSchool.isInactive) {
      setState(() {
        _selectedSchools.clear();
        _resolvedSchoolId = null;
        _detectedPlan = null;
        _schoolErrorMessage =
            'Aktivasi sekolah sedang dinonaktifkan oleh administrator.';
      });
      if (showSnackBar && mounted) {
        AppHelper.showSnackBar(
          context,
          'Aktivasi sekolah sedang dinonaktifkan oleh administrator.',
          isError: true,
        );
      }
      return;
    }

    if (_registerType == 'admin') {
      final isPro = searchCode.contains('PRO');
      final isEnt = searchCode.contains('ENTERPRISE');
      final planName = isEnt
          ? 'ENTERPRISE PLAN (999 Guru)'
          : (isPro ? 'PRO PLAN (50 Guru)' : 'FREE PLAN (30 Guru)');

      final schoolName =
          foundName ??
          (_schoolNameController.text.trim().isNotEmpty
              ? _schoolNameController.text.trim()
              : 'Sekolah');
      if (foundName != null && _schoolNameController.text.trim().isEmpty) {
        _schoolNameController.text = foundName;
      }

      setState(() {
        _selectedSchools.clear();
        _selectedSchools.add(schoolName);
        _resolvedSchoolId = matchedSchool?.id;
        _detectedPlan = planName;
        _schoolErrorMessage = null;
      });
      if (showSnackBar && mounted) {
        AppHelper.showSnackBar(context, 'Kode aktivasi diterima: $planName');
      }
    } else {
      if (foundName != null &&
          foundName.trim().isNotEmpty &&
          foundName.trim().toLowerCase() != 'sekolah') {
        final validSchoolName = foundName.trim();
        setState(() {
          _selectedSchools.clear();
          _selectedSchools.add(validSchoolName);
          _resolvedSchoolId = matchedSchool?.id;
          _detectedPlan = null;
          _positionController.clear();
          _schoolErrorMessage = null;
        });
        if (matchedSchool != null && matchedSchool.id.isNotEmpty) {
          masterProvider.loadAllData(matchedSchool.id);
        }
        if (showSnackBar && mounted) {
          AppHelper.showSnackBar(
            context,
            'Sekolah ditemukan: $validSchoolName',
          );
        }
      } else {
        setState(() {
          _selectedSchools.clear();
          _resolvedSchoolId = null;
          _detectedPlan = null;
          _positionController.clear();
          _schoolErrorMessage =
              'Sekolah tidak ditemukan. Pastikan Kode Sekolah sesuai dengan yang ada di JM Panel.';
        });
        if (showSnackBar && mounted) {
          AppHelper.showSnackBar(
            context,
            'Sekolah tidak ditemukan. Pastikan Kode Sekolah sesuai dengan yang ada di JM Panel.',
            isError: true,
          );
        }
      }
    }
  }

  InputDecoration _getInputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF64748B) : Colors.grey[400],
        fontSize: kIsWeb ? 14 : 14.5.sp,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: isDark
            ? const Color(0xFF60A5FA)
            : const Color.fromARGB(255, 37, 99, 235),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : const Color(0xFFEFF6FF).withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(
          color: isDark
              ? const Color(0xFF60A5FA)
              : const Color.fromARGB(255, 37, 99, 235),
          width: 2,
        ),
      ),
      contentPadding: EdgeInsets.symmetric(
        vertical: kIsWeb ? 10 : 12.h,
        horizontal: 14.w,
      ),
    );
  }
}
