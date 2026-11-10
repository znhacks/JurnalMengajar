import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/helper.dart';
import '../providers/auth_provider.dart';
import '../providers/master_data_provider.dart';
import '../services/excel_import_service.dart';
import 'student_import_modal.dart';
import 'app_dialog_actions.dart';

class ClassImportModal extends StatefulWidget {
  final VoidCallback? onImportSuccess;

  const ClassImportModal({
    super.key,
    this.onImportSuccess,
  });

  /// Helper statis untuk membuka modal impor kelas
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onImportSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClassImportModal(
        onImportSuccess: onImportSuccess,
      ),
    );
  }

  @override
  State<ClassImportModal> createState() => _ClassImportModalState();
}

class _ClassImportModalState extends State<ClassImportModal> {
  String? _selectedPeriodId;
  ClassImportParseResult? _parseResult;
  bool _isPicking = false;
  bool _isDownloadingTemplate = false;
  bool _isImporting = false;
  bool _skipDuplicates = true;

  @override
  void initState() {
    super.initState();
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    _selectedPeriodId = masterProvider.activePeriod?.id ??
        (masterProvider.periods.isNotEmpty ? masterProvider.periods.first.id : null);
  }

  Future<void> _handleDownloadTemplate() async {
    if (_isDownloadingTemplate) return;
    setState(() => _isDownloadingTemplate = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final schoolName = auth.activeSchoolName.isNotEmpty ? auth.activeSchoolName : 'Sekolah';

      await ExcelImportService.downloadClassTemplate(schoolName: schoolName);

      if (mounted) {
        AppHelper.showSnackBar(context, 'Template Excel kelas berhasil diunduh.');
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
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    setState(() => _isPicking = true);

    try {
      final result = await ExcelImportService.pickAndParseClassExcel(
        existingClasses: masterProvider.classes,
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
    if (_selectedPeriodId == null || _selectedPeriodId!.isEmpty) {
      AppHelper.showSnackBar(context, 'Pilih periode akademik tujuan terlebih dahulu', isError: true);
      return;
    }

    if (_parseResult == null) return;

    final selectedItems = _parseResult!.items.where((i) => i.isSelected && i.isValid).toList();

    if (selectedItems.isEmpty) {
      AppHelper.showSnackBar(context, 'Pilih minimal satu kelas untuk diimpor', isError: true);
      return;
    }

    setState(() => _isImporting = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);

      final models = selectedItems.map((item) {
        return item.toClassModel(
          periodId: _selectedPeriodId!,
          schoolId: auth.activeSchoolId ?? masterProvider.currentSchoolId,
        );
      }).toList();

      final success = await masterProvider.createMultipleClasses(models);

      if (!mounted) return;
      if (success) {
        final importedCount = models.length;
        widget.onImportSuccess?.call();
        Navigator.pop(context); // Tutup modal impor kelas

        // Dialog interaktif: Tanyakan apakah ingin langsung lanjut ke Langkah 2 (Impor Siswa)
        _showNextStepPrompt(importedCount);
      } else {
        AppHelper.showSnackBar(
          context,
          masterProvider.errorMessage ?? 'Gagal menyimpan data kelas hasil impor.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(context, 'Terjadi kesalahan saat impor: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showNextStepPrompt(int importedClassCount) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Kelas Berhasil Diimpor!',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Berhasil menambahkan $importedClassCount kelas baru ke dalam sistem.',
              style: GoogleFonts.hankenGrotesk(fontSize: 13.5.sp),
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Langkah 1 selesai. Anda sekarang dapat melanjutkan ke Langkah 2 untuk mengimpor daftar siswa ke kelas.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12.sp,
                        color: const Color(0xFF1E40AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          AppDialogActions(
            cancelText: 'Selesai',
            confirmText: 'Lanjut Impor Siswa',
            onCancel: () => Navigator.pop(dialogCtx),
            onConfirm: () {
              Navigator.pop(dialogCtx);
              final master = Provider.of<MasterDataProvider>(context, listen: false);
              StudentImportModal.show(
                context,
                availableClasses: master.classes,
                onImportSuccess: widget.onImportSuccess,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final masterProvider = context.watch<MasterDataProvider>();
    final periods = masterProvider.periods;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Modal Title Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: const Icon(
                    Icons.domain_add_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Impor Kelas (Excel)',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Langkah 1: Siapkan daftar kelas sebelum mengimpor siswa',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 11.5.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Modal Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Alur Pengerjaan (Step Badge)
                  _buildStepFlowCard(isDark),
                  SizedBox(height: 14.h),

                  // Pilihan Periode Akademik
                  Text(
                    'Periode / Tahun Ajaran Tujuan',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPeriodId,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    items: periods.map((p) {
                      return DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          p.name + (p.isActive ? ' (Aktif)' : ''),
                          style: GoogleFonts.hankenGrotesk(fontSize: 13.sp),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedPeriodId = val);
                    },
                  ),
                  SizedBox(height: 16.h),

                  // Unduh Template & Pilih File Excel
                  _buildUploadSection(isDark),
                  SizedBox(height: 16.h),

                  // Area Preview Hasil Parsing
                  if (_parseResult != null) _buildPreviewSection(theme, isDark),
                ],
              ),
            ),
          ),

          // Bottom Action Buttons
          if (_parseResult != null)
            SafeArea(
              child: AppDialogActions(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                cancelText: 'Batal',
                confirmText: 'Simpan (${_parseResult!.selectedCount} Kelas)',
                isConfirmLoading: _isImporting,
                onCancel: () => Navigator.pop(context),
                onConfirm: _parseResult!.selectedCount > 0 ? _handleStartImport : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepFlowCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'Langkah 1 dari 2',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'Impor Kelas Dulu → Lalu Impor Siswa',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            'Dengan membuat kelas terlebih dahulu, data siswa dapat secara otomatis langsung dipetakan ke kelas yang sesuai saat diimpor.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11.5.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(bool isDark) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    'Unduh Template Excel',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
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
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '* Format template memiliki lebar kolom lega (spacing rapi). Kolom "Nama Kelas" wajib diisi.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(ThemeData theme, bool isDark) {
    final result = _parseResult!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Chips Bar
        Wrap(
          spacing: 8.w,
          runSpacing: 6.h,
          children: [
            _buildStatChip('Total: ${result.totalRows}', Colors.grey),
            _buildStatChip('Siap Impor: ${result.validCount}', const Color(0xFF10B981)),
            if (result.duplicateCount > 0)
              _buildStatChip('Duplikat: ${result.duplicateCount}', const Color(0xFFF59E0B)),
            if (result.errorCount > 0)
              _buildStatChip('Error: ${result.errorCount}', const Color(0xFFEF4444)),
          ],
        ),
        SizedBox(height: 10.h),

        // Opsi lewati duplikat & Select All
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (result.duplicateCount > 0)
              Row(
                children: [
                  Checkbox(
                    value: _skipDuplicates,
                    onChanged: (val) {
                      setState(() {
                        _skipDuplicates = val ?? true;
                        _applyDuplicateFilter();
                      });
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  Text(
                    'Lewati kelas yang sudah ada',
                    style: GoogleFonts.hankenGrotesk(fontSize: 11.5.sp),
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
            Row(
              children: [
                TextButton(
                  onPressed: () => _toggleSelectAll(true),
                  child: Text('Pilih Semua', style: GoogleFonts.hankenGrotesk(fontSize: 11.5.sp)),
                ),
                TextButton(
                  onPressed: () => _toggleSelectAll(false),
                  child: Text('Batal Pilih', style: GoogleFonts.hankenGrotesk(fontSize: 11.5.sp)),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 6.h),

        // List Kelas yang Akan Diimpor
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: result.items.length,
          separatorBuilder: (_, _) => SizedBox(height: 8.h),
          itemBuilder: (ctx, index) {
            final item = result.items[index];
            final hasError = !item.isValid;
            final isDup = item.isDuplicate;

            Color statusColor = const Color(0xFF10B981);
            String statusText = 'Siap Impor';

            if (hasError) {
              statusColor = const Color(0xFFEF4444);
              statusText = item.error ?? 'Data Tidak Valid';
            } else if (isDup) {
              statusColor = const Color(0xFFF59E0B);
              statusText = item.duplicateReason ?? 'Sudah Terdaftar';
            }

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: item.isSelected,
                    onChanged: hasError
                        ? null
                        : (val) {
                            setState(() => item.isSelected = val ?? false);
                          },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name.isNotEmpty ? item.name : '(Nama Kosong)',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: hasError ? const Color(0xFFEF4444) : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (item.description != null && item.description!.isNotEmpty)
                          Text(
                            item.description!,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.5.sp,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.hankenGrotesk(
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
