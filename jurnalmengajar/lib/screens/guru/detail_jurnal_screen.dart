import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/image_viewer.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_model.dart';
import '../../models/journal_attachment_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../core/utils/helper.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class DetailJurnalScreen extends StatelessWidget {
  final String journalId;
  const DetailJurnalScreen({super.key, required this.journalId});

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.activeRole == 'admin';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    late JournalModel journal;
    try {
      journal = journalProvider.journals.firstWhere((j) => j.id == journalId);
    } catch (_) {
      // Check in teacher journals list as well
      try {
        journal = journalProvider.teacherJournals.firstWhere((j) => j.id == journalId);
      } catch (_) {
        return Scaffold(
          appBar: AppBar(title: const Text('Detail Jurnal')),
          body: const Center(child: Text('Jurnal tidak ditemukan')),
        );
      }
    }

    final cls = masterProvider.classes.firstWhere(
      (c) => c.id == journal.classId,
      orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );

    final subject = masterProvider.subjects.firstWhere(
      (s) => s.id == journal.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final teacher = masterProvider.teachers.firstWhere(
      (t) => t.id == journal.teacherId,
      orElse: () => TeacherModel(id: '', name: 'Guru--', position: '', address: '', phoneNumber: '', email: ''),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Detail Jurnal'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Status Badge Card
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cls.name,
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              subject.name,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: AppHelper.getStatusColor(journal.status).withValues(alpha: isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              AppHelper.getStatusLabel(journal.status),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppHelper.getStatusColor(journal.status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (journal.isTeacherAbsence) ...[
                            SizedBox(height: 6.h),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: journal.isTeacherSick
                                    ? const Color(0xFFEF4444).withValues(alpha: isDark ? 0.25 : 0.12)
                                    : const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: journal.isTeacherSick
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                      : const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    journal.isTeacherSick
                                        ? Icons.local_hospital_rounded
                                        : Icons.assignment_outlined,
                                    size: 12.sp,
                                    color: journal.isTeacherSick ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    journal.isTeacherSick ? 'Guru Sakit' : 'Guru Izin',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: journal.isTeacherSick ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Info Details
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      _buildInfoRow(context, Icons.person_outline, 'Pengajar', teacher.name),
                      const Divider(height: 24),
                      _buildInfoRow(context, Icons.calendar_today_outlined, 'Tanggal', AppHelper.formatDate(journal.date)),
                      const Divider(height: 24),
                      _buildInfoRow(context, Icons.access_time_outlined, 'Jam Ke', '${journal.teachingHour}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Teacher Absence Card OR Normal Material + Attendance
              if (journal.isTeacherAbsence) ...[
                Card(
                  margin: EdgeInsets.zero,
                  color: journal.isTeacherSick
                      ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.4) : const Color(0xFFFEF2F2))
                      : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: journal.isTeacherSick
                          ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFECACA))
                          : (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          journal.isTeacherSick ? Icons.medical_services_outlined : Icons.assignment_outlined,
                          color: journal.isTeacherSick ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                          size: 24.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                journal.isTeacherSick
                                    ? 'Keterangan Sakit Guru (Surat Terlampir)'
                                    : 'Keterangan Izin Guru (Surat Terlampir)',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: journal.isTeacherSick
                                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                                      : (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E)),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Text(
                                journal.material,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
              ] else ...[
                // Materi Pembelajaran
                Card(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Materi Pembelajaran',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          journal.material,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Absensi Siswa
                Card(
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kehadiran Siswa',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildAbsentStats(context, 'Sakit', journal.sickCount, Colors.amber),
                            _buildAbsentStats(context, 'Izin', journal.permissionCount, Colors.blue),
                            _buildAbsentStats(context, 'Alpha', journal.alphaCount, Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),
              ],

              // Catatan
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journal.isTeacherAbsence ? 'Catatan / Alasan' : 'Catatan Guru',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        journal.note ?? 'Tidak ada catatan.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Lampiran
              Card(
                margin: EdgeInsets.zero,
                color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journal.isTeacherAbsence
                            ? (journal.isTeacherSick ? 'Lampiran Surat Dokter' : 'Lampiran Surat Izin')
                            : 'Lampiran Dokumen',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildAttachmentPreview(context, journal),
                    ],
                  ),
                ),
              ),
              if (journal.status == 'rejected' && journal.rejectionNote != null && journal.rejectionNote!.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Card(
                  margin: EdgeInsets.zero,
                  color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? const Color(0xFFEF4444) : Colors.red, width: 1.2),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.red),
                            SizedBox(width: 8.w),
                            Text(
                              'Catatan Penolakan Admin:',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFFCA5A5) : Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          journal.rejectionNote!,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: isDark ? const Color(0xFFFECACA) : Colors.red[900],
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (journal.status == 'rejected' && !isAdmin) ...[
                SizedBox(height: 24.h),
                ElevatedButton.icon(
                  onPressed: () {
                    final dateStr = DateFormat('yyyy-MM-dd').format(journal.date);
                    context.push(
                      '/guru/journal-form?scheduleId=${journal.scheduleId}&journalId=${journal.id}&date=$dateStr',
                    );
                  },
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Revisi Jurnal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ],
              if (isAdmin && journal.status == 'pending') ...[
                SizedBox(height: 24.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleReject(context, journalProvider, journal),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Tolak'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleApprove(context, journalProvider, journal),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('Setujui'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  void _handleApprove(BuildContext context, JournalProvider journalProvider, JournalModel journal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui Jurnal'),
        content: const Text('Apakah Anda yakin ingin menyetujui jurnal mengajar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await journalProvider.verifyJournal(
                journal.id,
                'verified',
                teacherId: journal.teacherId,
              );
              if (success && context.mounted) {
                AppHelper.showSnackBar(context, 'Jurnal berhasil diverifikasi!');
                Navigator.pop(context);
              } else if (context.mounted) {
                AppHelper.showSnackBar(context, 'Gagal memverifikasi jurnal', isError: true);
              }
            },
            child: const Text('Setujui', style: TextStyle(color: Color(0xFF10B981))),
          ),
        ],
      ),
    );
  }

  void _handleReject(BuildContext context, JournalProvider journalProvider, JournalModel journal) {
    final commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isButtonEnabled = commentController.text.trim().isNotEmpty;
          
          return AlertDialog(
            title: const Text('Tolak Jurnal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Masukkan alasan penolakan jurnal ini. Catatan wajib diisi agar guru dapat merevisi dengan jelas.',
                  style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Alasan Penolakan',
                    hintText: 'Contoh: Foto lampiran buram / materi tidak sesuai...',
                  ),
                  onChanged: (_) {
                    setDialogState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: isButtonEnabled
                    ? () async {
                        Navigator.pop(ctx);
                        final success = await journalProvider.verifyJournal(
                          journal.id,
                          'rejected',
                          rejectionNote: commentController.text.trim(),
                          teacherId: journal.teacherId,
                        );
                        if (success && context.mounted) {
                          AppHelper.showSnackBar(context, 'Jurnal berhasil ditolak');
                          Navigator.pop(context);
                        } else if (context.mounted) {
                          AppHelper.showSnackBar(context, 'Gagal menolak jurnal', isError: true);
                        }
                      }
                    : null,
                child: const Text('Tolak Jurnal', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20.w, color: AppTheme.primaryColor),
        SizedBox(width: 12.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAbsentStats(BuildContext context, String title, int count, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12.sp,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentPreview(BuildContext context, JournalModel journal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attachmentUrl = journal.attachmentUrl;
    final List<JournalAttachmentModel> attachments = [];

    if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
      final urls = attachmentUrl.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      for (int i = 0; i < urls.length; i++) {
        final url = urls[i];
        final uri = Uri.parse(url);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'lampiran_${i + 1}';
        final fileType = fileName.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image';
        attachments.add(
          JournalAttachmentModel(
            id: 'ja_remote_$i',
            filePath: url,
            fileType: fileType,
            fileName: fileName,
          ),
        );
      }
    } else if (journal.attachment != null) {
      attachments.add(journal.attachment!);
    }

    if (attachments.isEmpty) {
      return Text(
        'Tidak ada lampiran diunggah.',
        style: TextStyle(fontSize: 13.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }

    final imageAttachments = attachments.where((a) => a.fileType == 'image').toList();
    final nonImageAttachments = attachments.where((a) => a.fileType != 'image').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageAttachments.isNotEmpty) ...[
          Wrap(
            spacing: 10.w,
            runSpacing: 10.h,
            children: imageAttachments
                .map((att) => _buildPhotoThumbnail(context, att, isDark))
                .toList(),
          ),
          SizedBox(height: 6.h),
          Text(
            'Ketuk foto untuk melihat ukuran penuh',
            style: TextStyle(
              fontSize: 11.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (imageAttachments.isNotEmpty && nonImageAttachments.isNotEmpty)
          SizedBox(height: 12.h),
        if (nonImageAttachments.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: nonImageAttachments
                .map((att) => _buildPdfAttachment(context, att, isDark))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildPhotoThumbnail(BuildContext context, JournalAttachmentModel attachment, bool isDark) {
    final isNetwork = attachment.filePath.startsWith('http');
    return GestureDetector(
      onTap: isNetwork
          ? () {
              FullScreenImageViewer.show(
                context,
                attachment.filePath,
                'journal_attachment_${attachment.id}',
              );
            }
          : null,
      child: Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.r),
          child: isNetwork
              ? Hero(
                  tag: 'journal_attachment_${attachment.id}',
                  child: Image.network(
                    attachment.filePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(Icons.broken_image, size: 28.sp, color: Colors.grey),
                    ),
                  ),
                )
              : Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 28.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPdfAttachment(BuildContext context, JournalAttachmentModel attachment, bool isDark) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: isDark ? 0.35 : 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Tipe: Dokumen PDF',
                  style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
