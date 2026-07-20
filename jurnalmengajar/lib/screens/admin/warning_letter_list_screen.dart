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

    final Map<String, List<dynamic>> groupedWarnings = {};
    for (final warning in filteredWarnings) {
      groupedWarnings.putIfAbsent(warning.teacherId, () => []).add(warning);
    }
    final teacherIds = groupedWarnings.keys.toList();

    teacherIds.sort((a, b) {
      final warningsA = groupedWarnings[a]!;
      final warningsB = groupedWarnings[b]!;
      final unreadA = warningsA.any((w) => w.status == 'unread');
      final unreadB = warningsB.any((w) => w.status == 'unread');
      if (unreadA && !unreadB) return -1;
      if (!unreadA && unreadB) return 1;
      final latestA = warningsA.map((w) => w.issuedAt).reduce((x, y) => x.isAfter(y) ? x : y);
      final latestB = warningsB.map((w) => w.issuedAt).reduce((x, y) => x.isAfter(y) ? x : y);
      return latestB.compareTo(latestA);
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Surat Peringatan (SP)',
          style: GoogleFonts.hankenGrotesk(
            fontWeight: FontWeight.bold,
            color: AppTheme.onBackground,
          ),
        ),
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
                      child: teacherIds.isEmpty
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
                              itemCount: teacherIds.length,
                              separatorBuilder: (context, _) => SizedBox(height: 12.h),
                              itemBuilder: (context, index) {
                                final teacherId = teacherIds[index];
                                final warnings = groupedWarnings[teacherId]!;
                                final teacher = masterProvider.teachers.firstWhere(
                                  (t) => t.id == teacherId,
                                  orElse: () => TeacherModel(
                                      id: '',
                                      name: 'Guru--',
                                      position: '',
                                      address: '',
                                      phoneNumber: '',
                                      email: ''),
                                );

                                final unreadCount = warnings.where((w) => w.status == 'unread').length;
                                final totalCount = warnings.length;

                                return Card(
                                  margin: EdgeInsets.zero,
                                  color: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    side: BorderSide(
                                      color: unreadCount > 0
                                          ? const Color(0xFFFECACA)
                                          : AppTheme.outlineVariant,
                                      width: unreadCount > 0 ? 1.5 : 1.0,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      backgroundColor: Colors.white,
                                      collapsedBackgroundColor: Colors.white,
                                      leading: CircleAvatar(
                                        backgroundColor: unreadCount > 0
                                            ? const Color(0xFFFEE2E2)
                                            : const Color(0xFFF1F5F9),
                                        backgroundImage: teacher.photoUrl != null && teacher.photoUrl!.isNotEmpty
                                            ? NetworkImage(teacher.photoUrl!)
                                            : null,
                                        child: teacher.photoUrl == null || teacher.photoUrl!.isEmpty
                                            ? Icon(
                                                Icons.warning_amber_rounded,
                                                color: unreadCount > 0
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF64748B),
                                              )
                                            : null,
                                      ),
                                      title: Text(
                                        teacher.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.hankenGrotesk(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.sp,
                                          color: AppTheme.onBackground,
                                        ),
                                      ),
                                      subtitle: Text(
                                        teacher.position,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 11.sp,
                                          color: AppTheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: unreadCount > 0
                                                  ? const Color(0xFFFEE2E2)
                                                  : const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              unreadCount > 0 ? '$unreadCount Belum Dibaca' : '$totalCount SP',
                                              style: GoogleFonts.hankenGrotesk(
                                                fontSize: 9.sp,
                                                fontWeight: FontWeight.w700,
                                                color: unreadCount > 0
                                                    ? const Color(0xFFB91C1C)
                                                    : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.outline),
                                        ],
                                      ),
                                      children: warnings.map((warning) {
                                        final isUnread = warning.status == 'unread';
                                        return Container(
                                          margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 8.h),
                                          padding: EdgeInsets.all(12.w),
                                          decoration: BoxDecoration(
                                            color: isUnread ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8.r),
                                            border: Border.all(
                                              color: isUnread ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                                              width: isUnread ? 1.2 : 1.0,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 6.w,
                                                      vertical: 2.h,
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
                                                        fontSize: 8.sp,
                                                        fontWeight: FontWeight.w700,
                                                        color: isUnread
                                                            ? const Color(0xFFB91C1C)
                                                            : const Color(0xFF15803D),
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${AppHelper.formatDate(warning.issuedAt)} ${DateFormat('HH:mm').format(warning.issuedAt)}',
                                                    style: GoogleFonts.hankenGrotesk(
                                                      fontSize: 10.sp,
                                                      color: AppTheme.outline,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Divider(height: 16),
                                              Text(
                                                warning.reason,
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 12.sp,
                                                  color: AppTheme.onBackground,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
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
