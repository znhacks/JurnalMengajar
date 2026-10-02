import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'animated_widgets.dart';

class AdminFilterItem {
  final String id;
  final String label;
  final int? count;
  final IconData? icon;

  const AdminFilterItem({
    required this.id,
    required this.label,
    this.count,
    this.icon,
  });
}

class AdminSearchFilterBar extends StatefulWidget {
  final TextEditingController? searchController;
  final String? hintText;
  final String? searchHint;
  final String? searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClearSearch;
  final VoidCallback? onSearchCleared;
  final List<AdminFilterItem>? filterItems;
  final String? selectedFilterId;
  final ValueChanged<String>? onFilterSelected;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const AdminSearchFilterBar({
    super.key,
    this.searchController,
    this.hintText,
    this.searchHint,
    this.searchQuery,
    this.onSearchChanged,
    this.onClearSearch,
    this.onSearchCleared,
    this.filterItems,
    this.selectedFilterId,
    this.onFilterSelected,
    this.trailing,
    this.padding,
  });

  @override
  State<AdminSearchFilterBar> createState() => _AdminSearchFilterBarState();
}

class _AdminSearchFilterBarState extends State<AdminSearchFilterBar> {
  late TextEditingController _internalController;
  bool _isLocalController = false;

  @override
  void initState() {
    super.initState();
    if (widget.searchController != null) {
      _internalController = widget.searchController!;
    } else {
      _internalController = TextEditingController();
      _isLocalController = true;
    }
  }

  @override
  void didUpdateWidget(covariant AdminSearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchController != null && widget.searchController != _internalController) {
      if (_isLocalController) {
        _internalController.dispose();
        _isLocalController = false;
      }
      _internalController = widget.searchController!;
    }
  }

  @override
  void dispose() {
    if (_isLocalController) {
      _internalController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBlue = const Color(0xFF2563EB);

    return Padding(
      padding: widget.padding ?? EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search row
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _internalController,
                  builder: (context, value, _) {
                    return TextField(
                      controller: _internalController,
                      onChanged: widget.onSearchChanged,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13.sp,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.searchHint ?? widget.hintText ?? 'Cari data...',
                        hintStyle: GoogleFonts.hankenGrotesk(
                          fontSize: 13.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: primaryBlue,
                          size: 20.r,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 18.r,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () {
                                  _internalController.clear();
                                  widget.onSearchChanged?.call('');
                                  widget.onClearSearch?.call();
                                  widget.onSearchCleared?.call();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : Colors.white,
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.r),
                          borderSide: BorderSide(color: primaryBlue, width: 1.5),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.trailing != null) ...[
                SizedBox(width: 8.w),
                widget.trailing!,
              ],
            ],
          ),

          // Optional Filter Chips Row
          if (widget.filterItems != null && widget.filterItems!.isNotEmpty) ...[
            SizedBox(height: 10.h),
            SizedBox(
              height: 36.h,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.filterItems!.length,
                separatorBuilder: (context, _) => SizedBox(width: 8.w),
                itemBuilder: (context, index) {
                  final item = widget.filterItems![index];
                  final isSelected = widget.selectedFilterId == item.id;

                  return ScaleTap(
                    onTap: () {
                      if (!isSelected) {
                        widget.onFilterSelected?.call(item.id);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.6)
                                : const Color(0xFFEFF6FF))
                            : (isDark
                                ? Theme.of(context).colorScheme.surface
                                : Colors.white),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: isSelected
                              ? primaryBlue
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryBlue.withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.icon != null) ...[
                            Icon(
                              item.icon,
                              size: 14.r,
                              color: isSelected
                                  ? primaryBlue
                                  : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                            ),
                            SizedBox(width: 5.w),
                          ],
                          Text(
                            item.label,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 12.sp,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF93C5FD) : primaryBlue)
                                  : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                            ),
                          ),
                          if (item.count != null) ...[
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryBlue
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: Text(
                                '${item.count}',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.grey[300] : const Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
