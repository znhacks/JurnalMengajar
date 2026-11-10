import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/helper.dart';
import '../models/class_model.dart';
import '../models/student_model.dart';
import '../providers/auth_provider.dart';
import '../providers/master_data_provider.dart';
import '../services/excel_import_service.dart';
import 'app_dialog_actions.dart';
import 'class_import_modal.dart';

class StudentImportModal extends StatefulWidget {
  final ClassModel? initialClass;
  final List<ClassModel>? availableClasses;
  final VoidCallback? onImportSuccess;

  const StudentImportModal({
    super.key,
    this.initialClass,
    this.availableClasses,
    this.onImportSuccess,
  });

  /// Helper statis untuk menampilkan modal bottom sheet impor siswa
  static Future<void> show(
    BuildContext context, {
    ClassModel? initialClass,
    List<ClassModel>? availableClasses,
    VoidCallback? onImportSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentImportModal(
        initialClass: initialClass,
        availableClasses: availableClasses,
        onImportSuccess: onImportSuccess,
      ),
    );
  }

  @override
  State<StudentImportModal> createState() => _StudentImportModalState();
}

class _StudentImportModalState extends State<StudentImportModal> {
  ClassModel? _selectedClass;
  StudentImportParseResult? _parseResult;
  bool _isPicking = false;
  bool _isDownloadingTemplate = false;
  bool _isImporting = false;
  bool _skipDuplicates = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialClass != null) {
      _selectedClass = widget.initialClass;
    } else if (widget.availableClasses != null && widget.availableClasses!.isNotEmpty) {
      _selectedClass = widget.availableClasses!.first;
    } else {
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
      _selectedClass = masterProvider.classes.isNotEmpty ? masterProvider.classes.first : null;
    }
  }

  List<StudentModel> _getExistingStudentsForSelectedClass() {
    if (_selectedClass == null) return [];
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    return masterProvider.students.where((s) => s.classId == _selectedClass!.id).toList();
  }

  Future<void> _handleDownloadTemplate() async {
    if (_isDownloadingTemplate) return;
    setState(() => _isDownloadingTemplate = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolName = auth.activeSchoolName.isNotEmpty ? auth.activeSchoolName : 'Sekolah';
      final className = _selectedClass?.name ?? 'Kelas X';

      await ExcelImportService.downloadStudentTemplate(
        className: className,
        schoolName: schoolName,
      );

      if (mounted) {
        AppHelper.showSnackBar(context, 'Template Excel berhasil diunduh.');
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Gagal mengunduh template: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingTemplate = false);
      }
    }
  }

  Future<void> _handlePickFile() async {
    if (_selectedClass == null) {
      AppHelper.showSnackBar(context, 'Pilih kelas tujuan terlebih dahulu', isError: true);
      return;
    }

    setState(() => _isPicking = true);

    try {
      final existingStudents = _getExistingStudentsForSelectedClass();
      final result = await ExcelImportService.pickAndParseExcel(
        existingStudents: existingStudents,
      );

      if (result != null && mounted) {
        setState(() {
          _parseResult = result;
          _applyDuplicateFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Gagal membaca file Excel: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _applyDuplicateFilter() {
    if (_parseResult == null) return;
    setState(() {
      for (final item in _parseResult!.items) {
        if (!item.isValid) {
          item.isSelected = false;
        } else if (item.isDuplicate) {
          item.isSelected = !_skipDuplicates;
        } else {
          item.isSelected = true;
        }
      }
    });
  }

  void _toggleSelectAll(bool select) {
    if (_parseResult == null) return;
    setState(() {
      for (final item in _parseResult!.items) {
        if (item.isValid) {
          if (item.isDuplicate && _skipDuplicates && select) {
            item.isSelected = false;
          } else {
            item.isSelected = select;
          }
        }
      }
    });
  }

  Future<void> _handleStartImport() async {
    if (_isImporting) return;
    if (_selectedClass == null) {
      AppHelper.showSnackBar(context, 'Pilih kelas tujuan terlebih dahulu', isError: true);
      return;
    }

    if (_parseResult == null) return;

    final selectedItems = _parseResult!.items.where((i) => i.isSelected && i.isValid).toList();

    if (selectedItems.isEmpty) {
      AppHelper.showSnackBar(context, 'Pilih minimal satu data siswa untuk diimpor', isError: true);
      return;
    }

    setState(() => _isImporting = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);

      final models = selectedItems.map((item) {
        return item.toStudentModel(
          classId: _selectedClass!.id,
          schoolId: auth.activeSchoolId ?? masterProvider.currentSchoolId,
        );
      }).toList();

      final success = await masterProvider.createMultipleStudents(models, _selectedClass!.id);

      if (!mounted) return;
      if (success) {
        final messenger = ScaffoldMessenger.of(context);
        final importedCount = models.length;
        final className = _selectedClass!.name;
        final onSuccess = widget.onImportSuccess;
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil mengimpor $importedCount data siswa ke $className!',
            ),
          ),
        );
        onSuccess?.call();
      } else {
        AppHelper.showSnackBar(
          context,
          masterProvider.errorMessage ?? 'Gagal mengimpor data siswa.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Terjadi kesalahan: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;
    final masterProvider = context.watch<MasterDataProvider>();
    final List<ClassModel> effectiveClasses;
    if (widget.availableClasses != null && widget.availableClasses!.isNotEmpty) {
      effectiveClasses = widget.availableClasses!;
    } else if (widget.initialClass != null) {
      effectiveClasses = [
        widget.initialClass!,
        ...masterProvider.classes.where((c) => c.id != widget.initialClass!.id),
      ];
    } else {
      effectiveClasses = masterProvider.classes;
    }

    if (_selectedClass == null && effectiveClasses.isNotEmpty) {
      _selectedClass = widget.initialClass ?? effectiveClasses.first;
    }

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top pull handle
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header title & close button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Impor Siswa',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (_selectedClass != null) ...[
                          SizedBox(height: 2.h),
                          Text(
                            'Kelas: ${_selectedClass!.name}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.5.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            // Content body
            _parseResult == null
                ? Flexible(child: SingleChildScrollView(child: _buildSimpleUploadStep(context, isDark, effectiveClasses)))
                : Flexible(child: _buildPreviewStep(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildNoClassesState(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.domain_disabled_rounded,
              size: 42.r,
              color: const Color(0xFFF59E0B),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'Belum Ada Kelas',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          Text(
            'Tambahkan atau impor kelas terlebih dahulu sebelum mengimpor siswa.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12.5.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ClassImportModal.show(
                context,
                onImportSuccess: widget.onImportSuccess,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: Text(
              'Impor Kelas',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleUploadStep(BuildContext context, bool isDark, List<ClassModel> effectiveClasses) {
    if (effectiveClasses.isEmpty) {
      return _buildNoClassesState(context, isDark);
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pilihan Kelas Tujuan
          Text(
            'Kelas Tujuan',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          effectiveClasses.length > 1
              ? DropdownButtonFormField<ClassModel>(
                  initialValue: _selectedClass,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                  items: effectiveClasses.map((c) {
                    return DropdownMenuItem<ClassModel>(
                      value: c,
                      child: Text(
                        '${c.name} (${c.studentCount} Siswa)',
                        style: GoogleFonts.hankenGrotesk(fontSize: 13.sp),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedClass = val);
                  },
                )
              : Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '${_selectedClass?.name ?? ""} (${_selectedClass?.studentCount ?? 0} Siswa)',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
          SizedBox(height: 16.h),

          // Unduh Template & Pilih File Excel
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isDownloadingTemplate ? null : _handleDownloadTemplate,
                  icon: _isDownloadingTemplate
                      ? SizedBox(
                          width: 14.w,
                          height: 14.w,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    'Unduh Template',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isPicking ? null : _handlePickFile,
                  icon: _isPicking
                      ? SizedBox(
                          width: 14.w,
                          height: 14.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(
                    'Pilih File Excel',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep(bool isDark) {
    final result = _parseResult!;
    final validItems = result.items.where((i) => i.isValid).toList();
    final selectedCount = validItems.where((i) => i.isSelected).length;
    final allSelected = validItems.isNotEmpty && validItems.every((i) => i.isSelected);

    return Column(
      children: [
        // Summary & Ganti file
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${result.items.length} baris terdeteksi • ${result.validCount} siap disimpan${result.duplicateCount > 0 ? " • ${result.duplicateCount} duplikat" : ""}',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _parseResult = null),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Ganti File',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Controls bar: Duplicate toggle & Select All
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (result.duplicateCount > 0)
                InkWell(
                  onTap: () {
                    setState(() {
                      _skipDuplicates = !_skipDuplicates;
                      _applyDuplicateFilter();
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 20.h,
                        width: 20.w,
                        child: Checkbox(
                          value: _skipDuplicates,
                          onChanged: (val) {
                            setState(() {
                              _skipDuplicates = val ?? true;
                              _applyDuplicateFilter();
                            });
                          },
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Lewati Duplikat',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox(),
              InkWell(
                onTap: () => _toggleSelectAll(!allSelected),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 20.h,
                      width: 20.w,
                      child: Checkbox(
                        value: allSelected,
                        onChanged: (val) => _toggleSelectAll(val ?? false),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'Pilih Semua',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Students list preview
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
            itemCount: result.items.length,
            separatorBuilder: (context, index) => SizedBox(height: 6.h),
            itemBuilder: (context, index) {
              final item = result.items[index];
              final isMale = item.gender == 'L';
              final genderColor = isMale ? const Color(0xFF2563EB) : const Color(0xFFEC4899);

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? (item.isSelected ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFF1E293B))
                      : (item.isSelected ? const Color(0xFFEFF6FF) : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.isSelected
                        ? const Color(0xFF2563EB)
                        : (item.error != null
                            ? Colors.redAccent.withValues(alpha: 0.4)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: Checkbox(
                        value: item.isSelected,
                        activeColor: const Color(0xFF2563EB),
                        onChanged: item.isValid
                            ? (val) {
                                setState(() {
                                  item.isSelected = val ?? false;
                                });
                              }
                            : null,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    CircleAvatar(
                      radius: 12.r,
                      backgroundColor: genderColor.withValues(alpha: 0.15),
                      child: Text(
                        item.gender ?? 'L',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: genderColor,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.bold,
                              color: item.isValid
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.redAccent,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                item.nis != null ? 'NIS: ${item.nis}' : 'NIS: -',
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (item.parentPhoneNumber != null) ...[
                                Text(
                                  '  •  HP: ${item.parentPhoneNumber}',
                                  style: TextStyle(
                                    fontSize: 10.5.sp,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (item.isDuplicate) ...[
                                SizedBox(width: 6.w),
                                Text(
                                  'Duplikat',
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (item.error != null) ...[
                            Text(
                              item.error!,
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom action buttons
        SafeArea(
          child: AppDialogActions(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            cancelText: 'Batal',
            confirmText: 'Simpan ($selectedCount Siswa)',
            isConfirmLoading: _isImporting,
            onCancel: () => Navigator.pop(context),
            onConfirm: (_isImporting || selectedCount == 0) ? null : _handleStartImport,
          ),
        ),
      ],
    );
  }
}
