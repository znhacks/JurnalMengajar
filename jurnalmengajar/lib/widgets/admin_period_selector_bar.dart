import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/period_model.dart';

class AdminPeriodSelectorBar extends StatelessWidget {
  final List<PeriodModel> periods;
  final String? selectedPeriodId;
  final ValueChanged<String> onPeriodChanged;
  final EdgeInsetsGeometry? padding;

  const AdminPeriodSelectorBar({
    super.key,
    required this.periods,
    required this.selectedPeriodId,
    required this.onPeriodChanged,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Sort periods: active first, then descending by name
    final sortedPeriods = List<PeriodModel>.from(periods)..sort((a, b) {
      if (a.isActive && !b.isActive) return -1;
      if (!a.isActive && b.isActive) return 1;
      return b.name.compareTo(a.name);
    });

    final activePeriod = periods.firstWhere(
      (p) => p.isActive,
      orElse: () => sortedPeriods.first,
    );

    final currentSelectedPeriod = periods.firstWhere(
      (p) => p.id == selectedPeriodId,
      orElse: () => activePeriod,
    );

    final isHistorical = !currentSelectedPeriod.isActive;

    return Padding(
      padding: padding ?? EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isHistorical
                    ? const Color(0xFFF59E0B)
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                width: isHistorical ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHistorical
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  isHistorical ? Icons.history_rounded : Icons.calendar_month_rounded,
                  size: 18.sp,
                  color: isHistorical
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF2563EB),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Tahun Ajaran:',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: currentSelectedPeriod.id,
                      isDense: true,
                      isExpanded: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      dropdownColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      items: sortedPeriods.map((period) {
                        return DropdownMenuItem<String>(
                          value: period.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  period.name,
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: period.isActive
                                      ? (isDark
                                          ? const Color(0xFF064E3B).withValues(alpha: 0.4)
                                          : const Color(0xFFDCFCE7))
                                      : (isDark
                                          ? const Color(0xFF334155).withValues(alpha: 0.5)
                                          : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(6.r),
                                  border: Border.all(
                                    color: period.isActive
                                        ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
                                        : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  period.isActive ? 'Aktif' : 'Arsip',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    color: period.isActive
                                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != currentSelectedPeriod.id) {
                          onPeriodChanged(val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isHistorical) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF78350F).withValues(alpha: 0.25)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFD97706).withValues(alpha: 0.4)
                      : const Color(0xFFFCD34D),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    size: 14.sp,
                    color: const Color(0xFFD97706),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'Mode Histori (${currentSelectedPeriod.name}): Data bersifat READ-ONLY untuk keperluan arsip/pengecekan. Tahun ajaran aktif sekolah tetap ${activePeriod.name}.',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
