import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/master_data_provider.dart';
import 'school_avatar.dart';

class SchoolSwitcherModal extends StatelessWidget {
  const SchoolSwitcherModal({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SchoolSwitcherModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userMemberships = authProvider.userMemberships;
    final activeSchoolId = authProvider.activeSchoolId;
    final activeRole = authProvider.activeRole;

    final List<SchoolRoleOption> options = [];
    final isExclusiveAdmin = authProvider.isExclusiveAdmin;

    for (final m in userMemberships) {
      if (m.role.toLowerCase() == 'admin' && !isExclusiveAdmin) {
        options.add(SchoolRoleOption(
          schoolId: m.schoolId,
          schoolName: m.schoolName,
          role: 'admin',
          logoUrl: m.logoUrl,
        ));
        final isSmkn8 = m.schoolName.toLowerCase().contains('smkn 8');
        if (!isSmkn8) {
          options.add(SchoolRoleOption(
            schoolId: m.schoolId,
            schoolName: m.schoolName,
            role: 'guru',
            logoUrl: m.logoUrl,
          ));
        }
      } else {
        options.add(SchoolRoleOption(
          schoolId: m.schoolId,
          schoolName: m.schoolName,
          role: m.role,
          logoUrl: m.logoUrl,
        ));
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          SizedBox(height: 20.h),

          // Title & subtitle
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF312E81).withValues(alpha: 0.5)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.business_rounded,
                  color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                  size: 24,
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Sekolah Aktif',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Pindah konteks sekolah & hak akses',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          SizedBox(height: 14.h),

          // School List
          if (options.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: Text(
                  'Belum ada sekolah terdaftar',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: options.length,
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  final item = options[index];
                  final isSelected = item.schoolId == activeSchoolId &&
                      item.role.toLowerCase() == activeRole.toLowerCase();
                  final isAdmin = item.role.toLowerCase() == 'admin';

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? const Color(0xFF312E81).withValues(alpha: 0.35)
                              : const Color(0xFFEEF2FF))
                          : (isDark
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      onTap: () {
                        if (isSelected) {
                          Navigator.pop(context);
                          return;
                        }

                        final scheduleProvider =
                            Provider.of<ScheduleProvider>(context, listen: false);
                        final journalProvider =
                            Provider.of<JournalProvider>(context, listen: false);
                        final masterProvider =
                            Provider.of<MasterDataProvider>(context, listen: false);

                        // Close modal immediately for snappy, instantaneous UX
                        Navigator.pop(context);

                        scheduleProvider.clearTeacherSchedulesCache();
                        journalProvider.clearTeacherJournalsCache();

                        authProvider.switchActiveSchool(
                          item.schoolId,
                          item.schoolName,
                          item.role,
                        );

                        masterProvider.loadAllData(item.schoolId);
                      },
                      leading: SchoolAvatar(
                        logoUrl: item.logoUrl,
                        schoolName: item.schoolName,
                        radius: 20,
                        isSelected: isSelected,
                      ),
                      title: Text(
                        item.schoolName,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 15.sp,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFFA5B4FC)
                                  : const Color(0xFF312E81))
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 4.h),
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? (isDark
                                      ? const Color(0xFF7F1D1D).withValues(alpha: 0.35)
                                      : const Color(0xFFFEF2F2))
                                  : (isDark
                                      ? const Color(0xFF14532D).withValues(alpha: 0.35)
                                      : const Color(0xFFF0FDF4)),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: isAdmin
                                    ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.5) : const Color(0xFFFCA5A5))
                                    : (isDark ? const Color(0xFF22C55E).withValues(alpha: 0.5) : const Color(0xFF86EFAC)),
                              ),
                            ),
                            child: Text(
                              isAdmin ? 'ADMIN' : 'GURU',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: isAdmin
                                    ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                    : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: isSelected
                          ? Container(
                              padding: EdgeInsets.all(4.w),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4F46E5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                          : null,
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

class SchoolRoleOption {
  final String schoolId;
  final String schoolName;
  final String role;
  final String? logoUrl;

  SchoolRoleOption({
    required this.schoolId,
    required this.schoolName,
    required this.role,
    this.logoUrl,
  });
}
