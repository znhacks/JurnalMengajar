import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../models/teacher_model.dart';
import '../../models/schedule_model.dart';
import '../../models/warning_letter_model.dart';
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
      final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);

      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        await masterProvider.loadAllData();
        final teacher = masterProvider.teachers.firstWhere(
          (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
          orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
        );

        if (teacher.id.isNotEmpty) {
          await Future.wait([
            warningProvider.loadTeacherWarningLetters(teacher.id),
            scheduleProvider.loadTeacherSchedules(teacher.id, DateTime.now()),
          ]);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final warningProvider = context.watch<WarningLetterProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final isLoading = warningProvider.isLoading || scheduleProvider.isLoading;

    // Group warnings by schedule date (fallback to issuedAt date)
    final Map<String, List<WarningLetterModel>> groupedMap = {};
    final Map<String, DateTime> dateMap = {};

    for (final warning in warningProvider.warningLetters) {
      final schedule = scheduleProvider.cachedTeacherSchedules.firstWhere(
        (s) => s.id == warning.scheduleId,
        orElse: () => ScheduleModel(
          id: '',
          teacherId: '',
          classId: '',
          subjectId: '',
          periodId: '',
          date: warning.issuedAt,
          teachingHour: 0,
          isActive: false,
        ),
      );

      final dateKey = '${schedule.date.year}-${schedule.date.month}-${schedule.date.day}';
      groupedMap.putIfAbsent(dateKey, () => []).add(warning);
      dateMap.putIfAbsent(dateKey, () => DateTime(schedule.date.year, schedule.date.month, schedule.date.day));
    }

    final sortedGroups = groupedMap.entries.toList()
      ..sort((a, b) {
        final dateA = dateMap[a.key]!;
        final dateB = dateMap[b.key]!;
        return dateB.compareTo(dateA);
      });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Surat Peringatan Saya',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.bold,
            color: AppTheme.onBackground,
          ),
        ),
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
                  final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
                  final currentUser = authProvider.currentUser;
                  if (currentUser != null) {
                    final teacher = masterProvider.teachers.firstWhere(
                      (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
                    );
                    await Future.wait([
                      warningProvider.loadTeacherWarningLetters(teacher.id),
                      scheduleProvider.loadTeacherSchedules(teacher.id, DateTime.now()),
                    ]);
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
                        itemCount: sortedGroups.length,
                        separatorBuilder: (context, _) => SizedBox(height: 16.h),
                        itemBuilder: (context, index) {
                          final group = sortedGroups[index];
                          final groupDate = dateMap[group.key]!;
                          final groupWarnings = group.value;

                          final hasUnread = groupWarnings.any((w) => w.status == 'unread');
                          final unreadList = groupWarnings.where((w) => w.status == 'unread').toList();

                          return Card(
                            margin: EdgeInsets.zero,
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                              side: BorderSide(
                                color: hasUnread
                                    ? const Color(0xFFFECACA)
                                    : AppTheme.outlineVariant,
                                width: hasUnread ? 1.5 : 1.0,
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
                                          color: hasUnread
                                              ? const Color(0xFFFEE2E2)
                                              : const Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          color: hasUnread
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
                                              AppHelper.formatDate(groupDate),
                                              style: GoogleFonts.hankenGrotesk(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.sp,
                                                color: AppTheme.onBackground,
                                              ),
                                            ),
                                            Text(
                                              'Peringatan Keterlambatan (${groupWarnings.length} Surat)',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 11.sp,
                                                color: AppTheme.outline,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!hasUnread)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.w,
                                            vertical: 4.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Dikonfirmasi',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 9.sp,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF15803D),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: groupWarnings.map((w) {
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 8.h),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '• ',
                                              style: TextStyle(
                                                color: w.status == 'unread' ? const Color(0xFFB91C1C) : const Color(0xFF64748B),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                w.reason,
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 13.sp,
                                                  color: AppTheme.onBackground,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  if (hasUnread) ...[
                                    SizedBox(height: 12.h),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          for (final w in unreadList) {
                                            await warningProvider.markWarningLetterAsRead(w.id);
                                          }
                                        },
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: Text('Konfirmasi Telah Membaca (${unreadList.length})'),
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
