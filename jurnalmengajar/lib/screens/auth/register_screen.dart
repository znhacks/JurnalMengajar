import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
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

  File? _profileImage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final String _selectedRole = 'pending_guru';
  final List<String> _selectedSchools = ['SMKN 11 Malang'];

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
          'Silakan pilih minimal 1 sekolah tempat Anda mengajar.',
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

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phoneNumber: _phoneNumberController.text.trim(),
        position: _positionController.text.trim(),
        address: _addressController.text.trim(),
        role: _selectedRole,
        photoUrl: _profileImage?.path,
        schoolName: _selectedSchools.join(', '),
      );

      if (success && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Registrasi Berhasil'),
            content: const Text(
              'Akun Anda telah berhasil didaftarkan.\n\nHarap tunggu verifikasi dan persetujuan dari Administrator sebelum Anda dapat masuk ke aplikasi.',
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 37, 99, 235),
              Color.fromARGB(255, 147, 197, 253),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 420.w),
                child: Card(
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32.r),
                  ),
                  color: Colors.white,
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
                              height: 160.h,
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
                                bottom: 20.h,
                                left: 16.w,
                                right: 16.w,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/logoJurnalMengajarLogin.png',
                                    height: 50.h,
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
                        padding: EdgeInsets.fromLTRB(28.w, 8.h, 28.w, 28.h),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Registrasi Guru',
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'Silakan lengkapi data diri Anda',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: const Color(0xFF64748B),
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

                               // Sekolah Tempat Mengajar (Wajib, Multi-Select)
                               _buildFieldLabel('SEKOLAH TEMPAT MENGAJAR'),
                               GestureDetector(
                                 onTap: () {
                                   _showSchoolSelector(context, masterProvider);
                                 },
                                 child: Container(
                                   padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFFEFF6FF).withValues(alpha: 0.5),
                                     borderRadius: BorderRadius.circular(16.r),
                                     border: Border.all(
                                       color: _selectedSchools.isEmpty ? Colors.red : const Color(0xFFE2E8F0),
                                       width: _selectedSchools.isEmpty ? 1.5 : 1,
                                     ),
                                   ),
                                   child: Row(
                                     children: [
                                       const Icon(Icons.school_outlined, color: Color.fromARGB(255, 37, 99, 235)),
                                       SizedBox(width: 12.w),
                                       Expanded(
                                         child: _selectedSchools.isEmpty
                                             ? Text(
                                                 'Pilih sekolah tempat mengajar...',
                                                 style: TextStyle(
                                                   fontSize: 14.sp,
                                                   color: Colors.grey[400],
                                                 ),
                                               )
                                             : Wrap(
                                                 spacing: 6.w,
                                                 runSpacing: 4.h,
                                                 children: _selectedSchools.map((sch) {
                                                   return Container(
                                                     padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                                     decoration: BoxDecoration(
                                                       color: const Color.fromARGB(255, 37, 99, 235).withValues(alpha: 0.1),
                                                       borderRadius: BorderRadius.circular(8.r),
                                                       border: Border.all(
                                                         color: const Color.fromARGB(255, 37, 99, 235).withValues(alpha: 0.3),
                                                       ),
                                                     ),
                                                     child: Row(
                                                       mainAxisSize: MainAxisSize.min,
                                                       children: [
                                                         Text(
                                                           sch,
                                                           style: TextStyle(
                                                             fontSize: 12.sp,
                                                             fontWeight: FontWeight.bold,
                                                             color: const Color.fromARGB(255, 37, 99, 235),
                                                           ),
                                                         ),
                                                         if (_selectedSchools.length > 1) ...[
                                                           SizedBox(width: 4.w),
                                                           GestureDetector(
                                                             onTap: () {
                                                               setState(() {
                                                                 _selectedSchools.remove(sch);
                                                               });
                                                             },
                                                             child: Icon(
                                                               Icons.close_rounded,
                                                               size: 14.r,
                                                               color: const Color.fromARGB(255, 37, 99, 235),
                                                             ),
                                                           ),
                                                         ],
                                                       ],
                                                     ),
                                                   );
                                                 }).toList(),
                                               ),
                                       ),
                                       Icon(
                                         Icons.arrow_drop_down,
                                         color: const Color.fromARGB(255, 37, 99, 235),
                                       ),
                                     ],
                                   ),
                                 ),
                               ),
                               SizedBox(height: 16.h),

                              // Nama Lengkap
                              _buildFieldLabel('NAMA LENGKAP'),
                              _buildTextField(
                                controller: _fullNameController,
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

                              // Jabatan
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
                                      if (value == null || value.isEmpty) {
                                        return 'Jabatan tidak boleh kosong';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // Nomor Telepon
                              _buildFieldLabel('NOMOR TELEPON'),
                              _buildTextField(
                                controller: _phoneNumberController,
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
                                obscureText: _obscurePassword,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: const Color(0xFF1E293B),
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
                                      color: const Color.fromARGB(255, 37, 99, 235),
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
                                obscureText: _obscureConfirmPassword,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: const Color(0xFF1E293B),
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
                                      color: const Color.fromARGB(255, 37, 99, 235),
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 14.sp, color: const Color(0xFF1E293B)),
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

  void _showSchoolSelector(
    BuildContext context,
    MasterDataProvider masterProvider,
  ) {
    // Collect school names from DB masterProvider, with fallback default list
    final dbSchools = masterProvider.schools.map((s) => s.name).toList();
    final allSchoolNames = dbSchools.isNotEmpty
        ? dbSchools
        : ['SMKN 11 Malang', 'SMKN 777 Ngawi'];

    final tempSelected = List<String>.from(_selectedSchools);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              top: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SizedBox(
              height: 380.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pilih Sekolah Tempat Mengajar',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Anda dapat memilih lebih dari 1 sekolah',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.builder(
                      itemCount: allSchoolNames.length,
                      itemBuilder: (sheetCtx, index) {
                        final schoolName = allSchoolNames[index];
                        final isChecked = tempSelected.contains(schoolName);
                        return CheckboxListTile(
                          activeColor: const Color.fromARGB(255, 37, 99, 235),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          title: Text(
                            schoolName,
                            style: TextStyle(
                              fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            isChecked ? 'Terpilih' : 'Ketuk untuk memilih',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                          value: isChecked,
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                if (!tempSelected.contains(schoolName)) {
                                  tempSelected.add(schoolName);
                                }
                              } else {
                                if (tempSelected.length > 1) {
                                  tempSelected.remove(schoolName);
                                } else {
                                  AppHelper.showSnackBar(
                                    sheetCtx,
                                    'Minimal pilih 1 sekolah.',
                                    isError: true,
                                  );
                                }
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedSchools.clear();
                        _selectedSchools.addAll(tempSelected);
                      });
                      Navigator.pop(sheetCtx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 37, 99, 235),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      'Simpan Pilihan (${tempSelected.length} Sekolah)',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          );
        },
      ),
    );
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
      fillColor: const Color(0xFFEFF6FF).withValues(alpha: 0.5),
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
