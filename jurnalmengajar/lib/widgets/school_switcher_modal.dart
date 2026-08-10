import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/schedule_provider.dart';
import '../providers/journal_provider.dart';

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
          if (userMemberships.isEmpty)
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
                itemCount: userMemberships.length,
                separatorBuilder: (context, index) => SizedBox(height: 10.h),
                itemBuilder: (context, index) {
                  final item = userMemberships[index];
                  final isSelected = item.schoolId == activeSchoolId;
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
                        scheduleProvider.clearTeacherSchedulesCache();
                        journalProvider.clearTeacherJournalsCache();
                        
                        await authProvider.switchActiveSchool(
                          item.schoolId,
                          item.schoolName,
                          item.role,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                        radius: 20.r,
                        child: Text(
                          item.schoolName.isNotEmpty ? item.schoolName[0].toUpperCase() : 'S',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                          ),
                        ),
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
                          if (item.schoolCode != null && item.schoolCode!.isNotEmpty) ...[
                            SizedBox(width: 8.w),
                            Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(
                                'Code: ${item.schoolCode}',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11.sp,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ]
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
