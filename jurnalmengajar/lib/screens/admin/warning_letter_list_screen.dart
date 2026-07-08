import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/warning_letter_provider.dart';
import '../../providers/master_data_provider.dart';
import '../../models/teacher_model.dart';
import '../../widgets/admin_drawer.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';

class AdminWarningLetterListScreen extends StatefulWidget {
  const AdminWarningLetterListScreen({super.key});

  @override
  State<AdminWarningLetterListScreen> createState() => _AdminWarningLetterListScreenState();
}

class _AdminWarningLetterListScreenState extends State<AdminWarningLetterListScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WarningLetterProvider>(context, listen: false).loadAllWarningLetters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warningProvider = context.watch<WarningLetterProvider>();
    final masterProvider = context.watch<MasterDataProvider>();
    final isLoading = warningProvider.isLoading;

    final filteredWarnings = warningProvider.warningLetters.where((warning) {
      final teacher = masterProvider.teachers.firstWhere(
        (t) => t.id == warning.teacherId,
        orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
      );
      return teacher.name.toLowerCase().contains(_searchQuery) ||
          warning.reason.toLowerCase().contains(_searchQuery);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Surat Peringatan (SP)'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.onBackground),
      ),
      drawer: const AdminDrawer(currentRoute: '/admin/warning-letters'),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: () => warningProvider.loadAllWarningLetters(),
                color: AppTheme.primaryColor,
                child: Column(
                  children: [
                    // Search box
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Cari nama guru atau mata pelajaran...',
                          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryColor),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: BorderSide(color: AppTheme.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filteredWarnings.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(height: 100.h),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.mail_outline_rounded,
                                        size: 64.r,
                                        color: AppTheme.outlineVariant,
                                      ),
                                      SizedBox(height: 16.h),
                                      Text(
                                        'Tidak ada Surat Peringatan',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.onSurfaceVariant,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'Tidak ada hasil yang cocok dengan pencarian Anda.'
                                            : 'Semua guru tertib mengisi jurnal tepat waktu.',
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 13.sp,
                                          color: AppTheme.outline,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              itemCount: filteredWarnings.length,
                              separatorBuilder: (context, _) => SizedBox(height: 12.h),
                              itemBuilder: (context, index) {
                                final warning = filteredWarnings[index];
                                final teacher = masterProvider.teachers.firstWhere(
                                  (t) => t.id == warning.teacherId,
                                  orElse: () => TeacherModel(
                                      id: '',
                                      name: 'Guru--',
                                      position: '',
                                      address: '',
                                      phoneNumber: '',
                                      email: ''),
                                );

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
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: isUnread
                                                  ? const Color(0xFFFEE2E2)
                                                  : const Color(0xFFF1F5F9),
                                              child: Icon(
                                                Icons.warning_amber_rounded,
                                                color: isUnread
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF64748B),
                                              ),
                                            ),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    teacher.name,
                                                    style: GoogleFonts.hankenGrotesk(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 15.sp,
                                                      color: AppTheme.onBackground,
                                                    ),
                                                  ),
                                                  Text(
                                                    teacher.position,
                                                    style: GoogleFonts.hankenGrotesk(
                                                      fontSize: 12.sp,
                                                      color: AppTheme.onSurfaceVariant,
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
                                                isUnread ? 'Belum Dibaca' : 'Dibaca',
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
                                        SizedBox(height: 12.h),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Diterbitkan:',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 11.sp,
                                                color: AppTheme.outline,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${AppHelper.formatDate(warning.issuedAt)} ${DateFormat('HH:mm').format(warning.issuedAt)}',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 11.sp,
                                                color: AppTheme.onSurfaceVariant,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
