import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../models/student_academic_history_model.dart';
import '../providers/master_data_provider.dart';
import '../core/theme/app_theme.dart';

class StudentHistoryModal {
  static void show(BuildContext context, {required StudentModel student}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StudentHistorySheet(student: student),
    );
  }
}

class _StudentHistorySheet extends StatefulWidget {
  final StudentModel student;

  const _StudentHistorySheet({required this.student});

  @override
  State<_StudentHistorySheet> createState() => _StudentHistorySheetState();
}

class _StudentHistorySheetState extends State<_StudentHistorySheet> {
  bool _isLoading = true;
  List<StudentAcademicHistoryModel> _histories = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistories();
  }

  Future<void> _loadHistories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
      final res = await masterProvider.getStudentHistories(widget.student.id);
      if (mounted) {
        setState(() {
          _histories = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'naik':
        return const Color(0xFF10B981); // Emerald
      case 'lulus':
        return const Color(0xFF8B5CF6); // Purple
      case 'tidak_naik':
        return const Color(0xFFF59E0B); // Amber
      case 'pindah':
        return const Color(0xFF06B6D4); // Cyan
      case 'aktif':
      default:
        return const Color(0xFF2563EB); // Blue
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'naik':
        return Icons.trending_up_rounded;
      case 'lulus':
        return Icons.school_rounded;
      case 'tidak_naik':
        return Icons.replay_rounded;
      case 'pindah':
        return Icons.swap_horiz_rounded;
      case 'aktif':
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Icon(
                    Icons.history_edu_rounded,
                    color: AppTheme.primaryColor,
                    size: 24.w,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Histori Pendidikan Siswa',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        widget.student.name,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      if (widget.student.nis != null && widget.student.nis!.isNotEmpty)
                        Text(
                          'NIS: ${widget.student.nis}',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 11.sp,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.w),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 48.w, color: Colors.red),
                              SizedBox(height: 12.h),
                              Text(
                                'Gagal memuat riwayat',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 12.sp,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              ElevatedButton(
                                onPressed: _loadHistories,
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _histories.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.w),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    size: 48.w,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 12.h),
                                  Text(
                                    'Belum Ada Histori Kenaikan',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Siswa ini belum memiliki catatan mutasi atau kenaikan kelas.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                            itemCount: _histories.length,
                            separatorBuilder: (context, _) => SizedBox(height: 12.h),
                            itemBuilder: (context, index) {
                              final item = _histories[index];
                              final statusColor = _getStatusColor(item.status);
                              final statusIcon = _getStatusIcon(item.status);

                              return Container(
                                padding: EdgeInsets.all(14.w),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row header: Tahun Ajaran & Status Badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today_rounded,
                                              size: 14.w,
                                              color: AppTheme.primaryColor,
                                            ),
                                            SizedBox(width: 6.w),
                                            Text(
                                              item.academicYear,
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.w800,
                                                color: textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 4.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(
                                              color: statusColor.withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(statusIcon, size: 12.w, color: statusColor),
                                              SizedBox(width: 4.w),
                                              Text(
                                                item.formattedStatus,
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 11.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8.h),

                                    // Kelas info
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.class_outlined,
                                          size: 15.w,
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'Kelas: ',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 12.sp,
                                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          item.className,
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        if (item.toClassName != null && item.toClassName!.isNotEmpty) ...[
                                          SizedBox(width: 6.w),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 14.w,
                                            color: statusColor,
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            item.toClassName!,
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),

                                    // Tanggal mutasi / pencatatan
                                    if (item.transferDate != null) ...[
                                      SizedBox(height: 6.h),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 13.w,
                                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                                          ),
                                          SizedBox(width: 6.w),
                                          Text(
                                            'Tanggal: ${DateFormat('dd MMMM yyyy', 'id_ID').format(item.transferDate!)}',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 11.sp,
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    // Catatan
                                    if (item.note != null && item.note!.isNotEmpty) ...[
                                      SizedBox(height: 6.h),
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Text(
                                          'Catatan: ${item.note}',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 11.sp,
                                            fontStyle: FontStyle.italic,
                                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
