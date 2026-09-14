import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/class_model.dart';
import '../models/schedule_model.dart';
import '../models/journal_model.dart';

class ClassRealizationCard extends StatefulWidget {
  final List<ClassModel> classes;
  final List<ScheduleModel> schedules;
  final List<JournalModel> journals;
  final bool isLoading;
  final String? errorMessage;
  final String? selectedTeacherId;
  final String? selectedTeacherName;
  final ValueChanged<ClassModel>? onClassTap;

  const ClassRealizationCard({
    super.key,
    required this.classes,
    required this.schedules,
    required this.journals,
    this.isLoading = false,
    this.errorMessage,
    this.selectedTeacherId,
    this.selectedTeacherName,
    this.onClassTap,
  });

  @override
  State<ClassRealizationCard> createState() => _ClassRealizationCardState();
}

class _ClassRealizationCardState extends State<ClassRealizationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryAccent = const Color(0xFF2563EB);

    final titleText = widget.selectedTeacherId != null && widget.selectedTeacherName != null
        ? 'Realisasi Mengajar — ${widget.selectedTeacherName}'
        : 'Realisasi Mengajar Per Kelas';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cardBorder),
      ),
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titleText,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.classes.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(left: 8.w),
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: primaryAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    '${widget.classes.length} Kelas',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: primaryAccent,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14.h),

          // Loading state
          if (widget.isLoading && widget.classes.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          // Error state
          else if (widget.errorMessage != null && widget.classes.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: Text(
                  'Statistik belum dapat dimuat.',
                  style: GoogleFonts.hankenGrotesk(
                    color: textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            )
          // Empty state
          else if (widget.classes.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: Center(
                child: Text(
                  'Belum ada data realisasi mengajar.',
                  style: GoogleFonts.hankenGrotesk(
                    color: textSecondary,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            )
          // Data list
          else ...[
            Builder(
              builder: (context) {
                final displayList = _isExpanded
                    ? widget.classes
                    : widget.classes.sublist(0, math.min(widget.classes.length, 5));

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayList.length,
                  separatorBuilder: (context, _) => SizedBox(height: 14.h),
                  itemBuilder: (context, index) {
                    final cls = displayList[index];

                    // 1. Filter schedules for this class (and selected teacher if any)
                    final classSchedules = widget.schedules.where((s) {
                      if (s.classId != cls.id) return false;
                      if (widget.selectedTeacherId != null &&
                          s.teacherId != widget.selectedTeacherId) {
                        return false;
                      }
                      return s.isActive;
                    }).toList();

                    // Group schedules into discrete teaching sessions (date + subject + teacher)
                    final Set<String> uniqueScheduledSessions = {};
                    for (final s in classSchedules) {
                      final dateStr =
                          '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
                      uniqueScheduledSessions.add('${dateStr}_${s.subjectId}_${s.teacherId}');
                    }
                    int targetCount = uniqueScheduledSessions.length;

                    // 2. Filter journals for this class (and selected teacher if any)
                    final classJournals = widget.journals.where((j) {
                      if (j.classId != cls.id) return false;
                      if (widget.selectedTeacherId != null &&
                          j.teacherId != widget.selectedTeacherId) {
                        return false;
                      }
                      return !j.isSoftDeleted;
                    }).toList();

                    // Track unique journal IDs to eliminate any possibility of duplicate count
                    final Set<String> uniqueJournalIds = {};
                    for (final j in classJournals) {
                      if (j.id.isNotEmpty) {
                        uniqueJournalIds.add(j.id);
                      }
                    }
                    final int filledCount = uniqueJournalIds.length;

                    // Target must be at least filledCount if journals were submitted
                    if (filledCount > targetCount) {
                      targetCount = filledCount;
                    }

                    final double progress = targetCount > 0
                        ? (filledCount / targetCount).clamp(0.0, 1.0)
                        : 0.0;

                    final rowContent = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                cls.name,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              '$filledCount / $targetCount Jurnal',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: primaryAccent,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4.h,
                            backgroundColor: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFEFF6FF),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              primaryAccent,
                            ),
                          ),
                        ),
                      ],
                    );

                    if (widget.onClassTap != null) {
                      return InkWell(
                        onTap: () => widget.onClassTap!(cls),
                        borderRadius: BorderRadius.circular(8.r),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          child: rowContent,
                        ),
                      );
                    }

                    return rowContent;
                  },
                );
              },
            ),
            if (widget.classes.length > 5) ...[
              SizedBox(height: 10.h),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18.sp,
                    color: primaryAccent,
                  ),
                  label: Text(
                    _isExpanded
                        ? 'Tampilkan Lebih Sedikit'
                        : 'Lihat Semua (${widget.classes.length} Kelas)',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: primaryAccent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
