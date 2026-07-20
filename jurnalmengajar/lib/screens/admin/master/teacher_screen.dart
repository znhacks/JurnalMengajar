import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../providers/master_data_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/teacher_model.dart';
import '../../../widgets/admin_drawer.dart';
import '../../../widgets/state_widgets.dart';
import '../../../core/utils/helper.dart';
import '../../../core/utils/image_crop_helper.dart';
import '../../../repositories/supabase_auth_repository.dart';
import '../../../widgets/animated_widgets.dart';

class MasterTeacherScreen extends StatefulWidget {
  const MasterTeacherScreen({super.key});

  @override
  State<MasterTeacherScreen> createState() => _MasterTeacherScreenState();
}

class _MasterTeacherScreenState extends State<MasterTeacherScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  void _toggleSelectionMode({String? initialId}) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
      if (_isSelectionMode && initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _toggleSelectItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<TeacherModel> allTeachers) {
    setState(() {
      if (_selectedIds.length == allTeachers.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(allTeachers.map((t) => t.id));
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus $count Data Guru', style: const TextStyle(color: Colors.red)),
        content: Text('Apakah Anda yakin ingin menghapus $count data guru yang dipilih? Akun login guru yang bersangkutan juga akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus Massal', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
      final idsToDelete = _selectedIds.toList();
      final success = await masterProvider.deleteMultipleTeachers(idsToDelete);
      if (!mounted) return;
      if (success) {
        AppHelper.showSnackBar(context, '$count data guru berhasil dihapus.');
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      } else {
        AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus data guru.', isError: true);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Provider.of<MasterDataProvider>(context, listen: false).loadAllData();
  }

  void _showFormDialog({TeacherModel? teacher}) {
    final nameController = TextEditingController(text: teacher?.name ?? '');
    final posController = TextEditingController(text: teacher?.position ?? '');
    final phoneController = TextEditingController(text: teacher?.phoneNumber ?? '');
    final emailController = TextEditingController(text: teacher?.email ?? '');
    final addressController = TextEditingController(text: teacher?.address ?? '');
    Uint8List? tempImageBytes;
    String? tempImageName;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickDialogImage({ImageSource source = ImageSource.gallery}) async {
            final result = await pickAndCropImage(
              context: context,
              source: source,
            );
            if (result != null) {
              setDialogState(() {
                tempImageBytes = result.bytes;
                tempImageName = result.name;
              });
            }
          }

          Future<void> showImageSourceSheet() async {
            await showModalBottomSheet<void>(
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
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Pilih dari Galeri'),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        pickDialogImage(source: ImageSource.gallery);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Ambil dari Kamera'),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        pickDialogImage(source: ImageSource.camera);
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20.h,
              left: 20.w,
              right: 20.w,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    teacher == null ? 'Tambah Guru Baru' : 'Edit Data Guru',
                    style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),

                  // Teacher Photo selection
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 44.r,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: tempImageBytes != null
                              ? MemoryImage(tempImageBytes!)
                              : (teacher?.photoUrl != null && teacher!.photoUrl!.startsWith('http')
                                  ? NetworkImage(teacher.photoUrl!)
                                  : (teacher?.photoUrl != null
                                      ? FileImage(File(teacher!.photoUrl!))
                                      : null)) as ImageProvider?,
                          child: tempImageBytes == null && teacher?.photoUrl == null
                              ? Icon(Icons.person, size: 44.r, color: Colors.grey[400])
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: showImageSourceSheet,
                            child: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                              child: Icon(Icons.camera_alt, size: 14.r, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap', hintText: 'Nama lengkap beserta gelar'),
                  ),
                  SizedBox(height: 12.h),
                  GestureDetector(
                    onTap: () {
                      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                      final subjectNames = masterProvider.subjects.map((s) => s.name).toList();
                      _showPositionSelector(
                        context,
                        subjectNames,
                        posController.text,
                        (selected) {
                          setDialogState(() {
                            posController.text = selected;
                          });
                        },
                      );
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: posController,
                        decoration: const InputDecoration(
                          labelText: 'Jabatan',
                          hintText: 'Ketuk untuk memilih jabatan / guru mapel...',
                          suffixIcon: Icon(Icons.arrow_drop_down),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Nomor Telepon', hintText: 'Contoh: 08123456789'),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: teacher == null,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Contoh: guru@jurnal.com',
                      helperText: 'Email digunakan guru untuk login (default pass: password123)',
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: 'Alamat', hintText: 'Alamat lengkap rumah'),
                  ),
                  SizedBox(height: 24.h),

                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) {
                              AppHelper.showSnackBar(context, 'Nama guru tidak boleh kosong', isError: true);
                              return;
                            }
                            if (posController.text.trim().isEmpty) {
                              AppHelper.showSnackBar(context, 'Jabatan/guru mapel tidak boleh kosong', isError: true);
                              return;
                            }
                            if (emailController.text.trim().isEmpty) {
                              AppHelper.showSnackBar(context, 'Email tidak boleh kosong', isError: true);
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);

                            String? uploadedPhotoUrl = teacher?.photoUrl;
                            if (tempImageBytes != null &&
                                tempImageName != null &&
                                authProvider.authRepository is SupabaseAuthRepository) {
                              try {
                                final supabaseRepo = authProvider.authRepository as SupabaseAuthRepository;
                                final targetId = teacher?.id ?? const Uuid().v4();
                                uploadedPhotoUrl = await supabaseRepo.uploadProfilePhoto(
                                  tempImageBytes!,
                                  tempImageName!,
                                  targetId,
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  AppHelper.showSnackBar(context, 'Gagal upload foto: $e', isError: true);
                                }
                                setDialogState(() {
                                  isSaving = false;
                                });
                                return;
                              }
                            }

                            bool success;
                            if (teacher == null) {
                              success = await masterProvider.createTeacher(TeacherModel(
                                id: '',
                                name: nameController.text.trim(),
                                position: posController.text.trim(),
                                phoneNumber: phoneController.text.trim(),
                                email: emailController.text.trim(),
                                address: addressController.text.trim(),
                                photoUrl: uploadedPhotoUrl,
                              ));
                            } else {
                              success = await masterProvider.updateTeacher(teacher.copyWith(
                                name: nameController.text.trim(),
                                position: posController.text.trim(),
                                phoneNumber: phoneController.text.trim(),
                                address: addressController.text.trim(),
                                photoUrl: uploadedPhotoUrl,
                              ));
                            }

                            if (success && context.mounted) {
                              AppHelper.showSnackBar(context, 'Data guru berhasil disimpan!');
                              Navigator.pop(context);
                            } else if (context.mounted) {
                              AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menyimpan data guru.', isError: true);
                            }

                            setDialogState(() {
                              isSaving = false;
                            });
                          },
                    child: isSaving
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Simpan'),
                  ),
                  SizedBox(height: 20.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleDelete(String id) async {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final success = await masterProvider.deleteTeacher(id);
    if (success && mounted) {
      AppHelper.showSnackBar(context, 'Data guru berhasil dihapus');
    } else if (mounted) {
      AppHelper.showSnackBar(context, masterProvider.errorMessage ?? 'Gagal menghapus data guru.', isError: true);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    if (phone.trim().isEmpty) {
      AppHelper.showSnackBar(context, 'Nomor WhatsApp belum terdaftar', isError: true);
      return;
    }

    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }

    final url = Uri.parse('https://wa.me/$cleanPhone');
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        AppHelper.showSnackBar(context, 'Tidak dapat membuka WhatsApp', isError: true);
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Gagal membuka link WhatsApp', isError: true);
      }
    }
  }

  /// Group teachers by position, applying search filter first.
  Map<String, List<TeacherModel>> _buildGroups(List<TeacherModel> teachers) {
    final filtered = _searchQuery.isEmpty
        ? teachers
        : teachers.where((t) {
            return t.name.toLowerCase().contains(_searchQuery) ||
                t.position.toLowerCase().contains(_searchQuery) ||
                t.email.toLowerCase().contains(_searchQuery);
          }).toList();

    final Map<String, List<TeacherModel>> groups = {};
    for (final t in filtered) {
      final key = t.position.trim().isEmpty ? 'Lainnya' : t.position.trim();
      groups.putIfAbsent(key, () => []).add(t);
    }

    // Sort keys alphabetically, but put 'Lainnya' at the end
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'Lainnya') return 1;
        if (b == 'Lainnya') return -1;
        return a.compareTo(b);
      });

    return {for (final k in sortedKeys) k: groups[k]!};
  }

  Widget _buildTeacherCard(TeacherModel t) {
    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 20.w),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _handleDelete(t.id),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Guru'),
            content: const Text(
                'Apakah Anda yakin ingin menghapus data guru ini? Akun login guru tersebut juga akan dihapus.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: FadeSlideIn(
        delay: const Duration(milliseconds: 60),
        child: ScaleTap(
          onTap: _isSelectionMode
              ? () => _toggleSelectItem(t.id)
              : () => context.push('/admin/master-data/teachers/${t.id}'),
          onLongPress: () {
            if (!_isSelectionMode) {
              _toggleSelectionMode(initialId: t.id);
            } else {
              _toggleSelectItem(t.id);
            }
          },
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: _selectedIds.contains(t.id) ? const Color(0xFFEFF6FF) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _selectedIds.contains(t.id) ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                width: _selectedIds.contains(t.id) ? 1.5 : 1.0,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              child: Row(
                children: [
                  if (_isSelectionMode) ...[
                    Checkbox(
                      value: _selectedIds.contains(t.id),
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (_) => _toggleSelectItem(t.id),
                    ),
                    SizedBox(width: 4.w),
                  ],
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: t.photoUrl != null && t.photoUrl!.startsWith('http')
                        ? NetworkImage(t.photoUrl!)
                        : (t.photoUrl != null ? FileImage(File(t.photoUrl!)) : null) as ImageProvider?,
                    child: t.photoUrl == null
                        ? Icon(Icons.person, size: 20.r, color: Colors.grey[400])
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: TextStyle(
                              fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          t.position,
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                        if (t.phoneNumber.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            'Telp: ${t.phoneNumber}',
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  if (!_isSelectionMode)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chat,
                            color: t.phoneNumber.trim().isEmpty ? Colors.grey[400] : const Color(0xFF25D366),
                            size: 20.sp,
                          ),
                          tooltip: 'WhatsApp',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.all(2.w),
                          onPressed: () => _launchWhatsApp(t.phoneNumber),
                        ),
                        SizedBox(width: 2.w),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: Colors.indigo, size: 20.sp),
                          tooltip: 'Edit Guru',
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.all(2.w),
                          onPressed: () => _showFormDialog(teacher: t),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title, int count) {
    return Padding(
      padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2563EB),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count guru',
              style: TextStyle(
                fontSize: 11.sp,
                color: const Color(0xFF2563EB),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final teachers = masterProvider.teachers;
    final groups = _buildGroups(teachers);
    final hasResults = groups.isNotEmpty;

    // Build a flat list of items: [header, card, card, ..., header, card, ...]
    final List<Widget> listItems = [];
    groups.forEach((category, categoryTeachers) {
      listItems.add(_buildGroupHeader(category, categoryTeachers.length));
      for (final t in categoryTeachers) {
        listItems.add(Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: _buildTeacherCard(t),
        ));
      }
      listItems.add(SizedBox(height: 4.h));
    });

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedIds.clear();
                }),
              ),
              title: Text('${_selectedIds.length} Terpilih', style: const TextStyle(color: Colors.white)),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedIds.length == teachers.length ? Icons.deselect : Icons.select_all,
                    color: Colors.white,
                  ),
                  tooltip: _selectedIds.length == teachers.length ? 'Batal Pilih Semua' : 'Pilih Semua',
                  onPressed: () => _selectAll(teachers),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Hapus Massal',
                  onPressed: _selectedIds.isEmpty ? null : _handleBatchDelete,
                ),
              ],
            )
          : AppBar(
              title: const Text('Master Data Guru'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist_rounded),
                  tooltip: 'Pilih Massal',
                  onPressed: teachers.isEmpty ? null : () => _toggleSelectionMode(),
                ),
              ],
            ),
      drawer: const AdminDrawer(currentRoute: '/admin/master-data/teachers'),
      body: Column(
        children: [
          // --- Search Bar ---
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari guru berdasarkan nama, jabatan, atau email...',
                hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20.r),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18.r, color: Colors.grey[400]),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
          ),

          // --- List ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF2563EB),
              child: masterProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : teachers.isEmpty
                      ? const AppEmptyWidget(
                          title: 'Guru Kosong',
                          subtitle: 'Tekan tombol + di bawah untuk menambah data guru.',
                        )
                      : !hasResults
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.w),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off, size: 48.r, color: Colors.grey[300]),
                                    SizedBox(height: 12.h),
                                    Text(
                                      'Tidak ada guru yang cocok',
                                      style: TextStyle(
                                          fontSize: 14.sp, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      '"$_searchQuery"',
                                      style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
                              children: listItems,
                            ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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
                                    color: isSelected ? const Color(0xFF2563EB) : null,
                                  ),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check, color: Color(0xFF2563EB))
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
}
