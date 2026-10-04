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
    _selectedClass = widget.initialClass ??
        (widget.availableClasses != null && widget.availableClasses!.isNotEmpty
            ? widget.availableClasses!.first
            : null);
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

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          AppHelper.showSnackBar(
            context,
            'Berhasil mengimpor ${models.length} data siswa ke ${_selectedClass!.name}!',
          );
          widget.onImportSuccess?.call();
        } else {
          AppHelper.showSnackBar(
            context,
            masterProvider.errorMessage ?? 'Gagal mengimpor data siswa.',
            isError: true,
          );
        }
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
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

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
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.file_upload_outlined,
                      color: const Color(0xFF2563EB),
                      size: 20.w,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Impor Siswa dari Excel',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (_selectedClass != null)
                          Text(
                            'Kelas: ${_selectedClass!.name}',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.5.sp,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

            // Content body
            _parseResult == null
                ? _buildSimpleUploadStep(isDark)
                : Flexible(child: _buildPreviewStep(isDark)),
          ],
        ),
      ),
    );
  }

  // --- STEP 1: Simple & Compact Upload ---
  Widget _buildSimpleUploadStep(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Class selector if multiple classes available
          if (widget.availableClasses != null && widget.availableClasses!.length > 1) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Kelas: ',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ClassModel>(
                        value: _selectedClass,
                        isDense: true,
                        isExpanded: true,
                        items: widget.availableClasses!.map((c) {
                          return DropdownMenuItem<ClassModel>(
                            value: c,
                            child: Text(
                              '${c.name} (${c.studentCount} Siswa)',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedClass = val;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],

          // Compact Upload Drop area
          InkWell(
            onTap: _isPicking ? null : _handlePickFile,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 22.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isPicking) ...[
                    SizedBox(
                      width: 26.w,
                      height: 26.w,
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Membaca file Excel...',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 32.w,
                      color: const Color(0xFF2563EB),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Pilih File Excel Siswa',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'Format .xlsx atau .xls',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.5.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Action row: Download template button & column guide
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _isDownloadingTemplate ? null : _handleDownloadTemplate,
                icon: _isDownloadingTemplate
                    ? SizedBox(
                        width: 12.w,
                        height: 12.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.file_download_outlined, size: 16.w, color: const Color(0xFF10B981)),
                label: Text(
                  'Unduh Template',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF10B981),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Flexible(
                child: Text(
                  'Kolom: Nama, NIS, L/P, No HP',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 11.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- STEP 2: Preview & Confirmation ---
  Widget _buildPreviewStep(bool isDark) {
    final result = _parseResult!;
    final validItems = result.items.where((i) => i.isValid).toList();
    final selectedCount = validItems.where((i) => i.isSelected).length;
    final allSelected = validItems.isNotEmpty && validItems.every((i) => i.isSelected);

    return Column(
      children: [
        // File summary & badge chips
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.insert_drive_file_outlined, size: 16.w, color: const Color(0xFF2563EB)),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  result.fileName,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _statusBadge('${result.validCount} Siap', Colors.green),
              if (result.duplicateCount > 0) ...[
                SizedBox(width: 4.w),
                _statusBadge('${result.duplicateCount} Duplikat', Colors.orange),
              ],
              SizedBox(width: 4.w),
              TextButton(
                onPressed: () => setState(() => _parseResult = null),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Ganti', style: TextStyle(fontSize: 11.sp)),
              ),
            ],
          ),
        ),

        // Controls bar: Duplicate toggle & Select All
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (result.duplicateCount > 0)
                Expanded(
                  child: InkWell(
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
                        Flexible(
                          child: Text(
                            'Lewati Duplikat',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
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

        // Bottom action import button
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: ElevatedButton.icon(
            onPressed: (_isImporting || selectedCount == 0) ? null : _handleStartImport,
            icon: _isImporting
                ? SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              _isImporting
                  ? 'Mengimpor Data...'
                  : 'Impor $selectedCount Siswa ke ${_selectedClass?.name ?? "Kelas"}',
              style: GoogleFonts.hankenGrotesk(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
