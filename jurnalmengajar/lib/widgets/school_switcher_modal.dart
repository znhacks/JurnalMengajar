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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
                color: const Color(0xFFCBD5E1),
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
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Color(0xFF4F46E5),
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
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Pindah konteks sekolah & hak akses',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 18.h),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                    color: const Color(0xFF64748B),
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
                      color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      onTap: () async {
                        final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
                        final journalProvider = Provider.of<JournalProvider>(context, listen: false);
                        final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                        
                        scheduleProvider.clearTeacherSchedulesCache();
                        journalProvider.clearTeacherJournalsCache();
                        
                        await authProvider.switchActiveSchool(
                          item.schoolId,
                          item.schoolName,
                          item.role,
                        );
                        
                        await masterProvider.loadAllData(item.schoolId);
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
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
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF312E81) : const Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(top: 4.h),
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: isAdmin ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(
                                color: isAdmin ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                              ),
                            ),
                            child: Text(
                              isAdmin ? 'ADMIN' : 'GURU',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w800,
                                color: isAdmin ? const Color(0xFF991B1B) : const Color(0xFF166534),
                              ),
                            ),
                          ),
                          // School code display removed as requested by the user
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
