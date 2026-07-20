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
import '../../providers/auth_provider.dart';

class DetailJurnalScreen extends StatelessWidget {
  final String journalId;
  const DetailJurnalScreen({super.key, required this.journalId});

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final journalProvider = context.watch<JournalProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.currentUser;
    final isAdmin = currentUser?.role == 'admin';

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
                color: Colors.white,
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
                              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              subject.name,
                              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: AppHelper.getStatusColor(journal.status).withValues(alpha: 0.1),
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
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Info Details
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.person_outline, 'Pengajar', teacher.name),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.calendar_today_outlined, 'Tanggal', AppHelper.formatDate(journal.date)),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.access_time_outlined, 'Jam Ke', '${journal.teachingHour}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Materi Pembelajaran
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Materi Pembelajaran',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        journal.material,
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[750], height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Absensi Siswa
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kehadiran Siswa',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildAbsentStats('Sakit', journal.sickCount, Colors.amber),
                          _buildAbsentStats('Izin', journal.permissionCount, Colors.blue),
                          _buildAbsentStats('Alpha', journal.alphaCount, Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Catatan
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catatan Guru',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        journal.note ?? 'Tidak ada catatan.',
                        style: TextStyle(fontSize: 14.sp, color: Colors.grey[700], height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Lampiran
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lampiran Dokumen',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
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
                  color: Colors.red.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.red, width: 1.2),
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
                                color: Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          journal.rejectionNote!,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.red[900],
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
                const Text(
                  'Masukkan alasan penolakan jurnal ini. Catatan wajib diisi agar guru dapat merevisi dengan jelas.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20.w, color: const Color(0xFF2563EB)),
        SizedBox(width: 12.w),
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: Colors.grey[500], fontWeight: FontWeight.w500),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAbsentStats(String title, int count, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[500], fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 4.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
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
    final attachmentUrl = journal.attachmentUrl;
    if (attachmentUrl == null || attachmentUrl.isEmpty) {
      final attachment = journal.attachment;
      if (attachment == null) {
        return Text(
          'Tidak ada lampiran diunggah.',
          style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
        );
      }
      return _buildSingleAttachment(context, attachment);
    }

    final urls = attachmentUrl.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (urls.isEmpty) {
      return Text(
        'Tidak ada lampiran diunggah.',
        style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
      );
    }

    if (urls.length == 1) {
      final url = urls.first;
      final uri = Uri.parse(url);
      final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'attachment';
      final fileType = fileName.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image';
      final att = JournalAttachmentModel(
        id: 'ja_remote_0',
        filePath: url,
        fileType: fileType,
        fileName: fileName,
      );
      return _buildSingleAttachment(context, att);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(urls.length, (index) {
        final url = urls[index];
        final uri = Uri.parse(url);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'attachment_${index + 1}';
        final fileType = fileName.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image';
        final att = JournalAttachmentModel(
          id: 'ja_remote_$index',
          filePath: url,
          fileType: fileType,
          fileName: fileName,
        );
        return Padding(
          padding: EdgeInsets.only(bottom: index == urls.length - 1 ? 0 : 12.h),
          child: _buildSingleAttachment(context, att),
        );
      }),
    );
  }

  Widget _buildSingleAttachment(BuildContext context, JournalAttachmentModel attachment) {
    if (attachment.fileType == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 200.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: attachment.filePath.startsWith('http')
                  ? GestureDetector(
                      onTap: () {
                        FullScreenImageViewer.show(
                          context,
                          attachment.filePath,
                          'journal_attachment_${attachment.id}',
                        );
                      },
                      child: Hero(
                        tag: 'journal_attachment_${attachment.id}',
                        child: Image.network(
                          attachment.filePath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 50),
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            attachment.fileName,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            attachment.fileName,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Text('Tipe: PDF Dokumen', style: TextStyle(fontSize: 11.sp, color: Colors.grey[600])),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Color(0xFF2563EB)),
              onPressed: () {
                // PDF opening simulation
              },
            ),
          ],
        ),
      );
    }
  }
}
