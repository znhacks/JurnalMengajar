import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class BigstarterTenantFilterChips extends StatelessWidget {
  final List<String> schoolNames;
  final String selectedSchoolId; // 'ALL' or specific schoolId
  final Function(String schoolId) onSelectSchool;

  const BigstarterTenantFilterChips({
    super.key,
    required this.schoolNames,
    required this.selectedSchoolId,
    required this.onSelectSchool,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Construct items list with 'Semua Sekolah' first
    final items = [
      {'id': 'ALL', 'name': 'Semua Sekolah'},
      ...schoolNames.map((sName) => {'id': sName, 'name': sName}),
    ];

    return SizedBox(
      height: 40.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: items.length,
        separatorBuilder: (context, index) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selectedSchoolId == item['id'];

          return InkWell(
            onTap: () => onSelectSchool(item['id']!),
            borderRadius: BorderRadius.circular(20.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4338CA)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  item['name']!,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.sp,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class BigstarterManageTenantSchoolsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> availableSchools;
  final List<String> currentlyMonitoredSchoolIds;
  final Function(List<String> updatedSchoolIds) onSave;

  const BigstarterManageTenantSchoolsSheet({
    super.key,
    required this.availableSchools,
    required this.currentlyMonitoredSchoolIds,
    required this.onSave,
  });

  static void show(
    BuildContext context, {
    required List<Map<String, dynamic>> availableSchools,
    required List<String> currentlyMonitoredSchoolIds,
    required Function(List<String> updatedSchoolIds) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BigstarterManageTenantSchoolsSheet(
        availableSchools: availableSchools,
        currentlyMonitoredSchoolIds: currentlyMonitoredSchoolIds,
        onSave: onSave,
      ),
    );
  }

  @override
  State<BigstarterManageTenantSchoolsSheet> createState() => _BigstarterManageTenantSchoolsSheetState();
}

class _BigstarterManageTenantSchoolsSheetState extends State<BigstarterManageTenantSchoolsSheet> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set<String>.from(widget.currentlyMonitoredSchoolIds);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 18.h),
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF312E81).withValues(alpha: 0.4)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 24),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kelola Pemantauan Sekolah',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Pilih sekolah yang ingin dipantau di HP',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          SizedBox(height: 10.h),

          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.availableSchools.length,
              itemBuilder: (context, index) {
                final school = widget.availableSchools[index];
                final id = school['id'] as String;
                final name = school['name'] as String? ?? 'Sekolah';
                final isChecked = _selectedIds.contains(id);

                return CheckboxListTile(
                  activeColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  title: Text(
                    name,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  value: isChecked,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedIds.add(id);
                      } else {
                        _selectedIds.remove(id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          SizedBox(height: 16.h),

          SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                elevation: 0,
              ),
              onPressed: () {
                widget.onSave(_selectedIds.toList());
                Navigator.pop(context);
              },
              child: Text(
                'Simpan Perubahan',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
