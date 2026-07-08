import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../models/teacher_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';

class GuruWarningLetterListScreen extends StatefulWidget {
  const GuruWarningLetterListScreen({super.key});

  @override
  State<GuruWarningLetterListScreen> createState() => _GuruWarningLetterListScreenState();
}

class _GuruWarningLetterListScreenState extends State<GuruWarningLetterListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
      final warningProvider = Provider.of<WarningLetterProvider>(context, listen: false);

      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        await masterProvider.loadAllData();
        final teacher = masterProvider.teachers.firstWhere(
          (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
          orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
        );

        if (teacher.id.isNotEmpty) {
          await warningProvider.loadTeacherWarningLetters(teacher.id);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final warningProvider = context.watch<WarningLetterProvider>();
    final isLoading = warningProvider.isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Surat Peringatan Saya'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
                  final currentUser = authProvider.currentUser;
                  if (currentUser != null) {
                    final teacher = masterProvider.teachers.firstWhere(
                      (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
                    );
                    await warningProvider.loadTeacherWarningLetters(teacher.id);
                  }
                },
                color: AppTheme.primaryColor,
                child: warningProvider.warningLetters.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: 120.h),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(20.w),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 64,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                                SizedBox(height: 20.h),
                                Text(
                                  'Kinerja Luar Biasa!',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 40.w),
                                  child: Text(
                                    'Anda tidak memiliki surat peringatan. Terus pertahankan kedisiplinan dalam mengisi jurnal mengajar!',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      color: AppTheme.outline,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount: warningProvider.warningLetters.length,
                        separatorBuilder: (context, _) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final warning = warningProvider.warningLetters[index];
                          final isUnread = warning.status == 'unread';

                          return Card(
                            margin: EdgeInsets.zero,
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              side: BorderSide(
                                color: isUnread
                                    ? const Color(0xFFFECACA)
                                    : AppTheme.outlineVariant,
                                width: isUnread ? 1.5 : 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(8.w),
                                        decoration: BoxDecoration(
                                          color: isUnread
                                              ? const Color(0xFFFEE2E2)
                                              : const Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          color: isUnread
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF64748B),
                                          size: 20,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Peringatan Keterlambatan',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.sp,
                                                color: AppTheme.onBackground,
                                              ),
                                            ),
                                            Text(
                                              '${AppHelper.formatDate(warning.issuedAt)} ${DateFormat('HH:mm').format(warning.issuedAt)}',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 11.sp,
                                                color: AppTheme.outline,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8.w,
                                          vertical: 4.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isUnread
                                              ? const Color(0xFFFEE2E2)
                                              : const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          isUnread ? 'Belum Konfirmasi' : 'Dikonfirmasi',
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w700,
                                            color: isUnread
                                                ? const Color(0xFFB91C1C)
                                                : const Color(0xFF15803D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Text(
                                    warning.reason,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 13.sp,
                                      color: AppTheme.onBackground,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (isUnread) ...[
                                    SizedBox(height: 16.h),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          warningProvider.markWarningLetterAsRead(warning.id);
                                        },
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: const Text('Konfirmasi Telah Membaca'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 10.h),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.r),
                                          ),
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
            ),
    );
  }
}
