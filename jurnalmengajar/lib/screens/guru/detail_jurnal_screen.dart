import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/journal_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/teacher_model.dart';
import '../../core/utils/helper.dart';

class DetailJurnalScreen extends StatelessWidget {
  final String journalId;
  const DetailJurnalScreen({super.key, required this.journalId});

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final journalProvider = context.watch<JournalProvider>();

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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cls.name,
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            subject.name,
                            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
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
                      _buildAttachmentPreview(journal),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20.w, color: const Color(0xFF0D9488)),
        SizedBox(width: 12.w),
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: Colors.grey[500], fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
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

  Widget _buildAttachmentPreview(JournalModel journal) {
    final attachment = journal.attachment;
    if (attachment == null) {
      return Text(
        'Tidak ada lampiran diunggah.',
        style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
      );
    }

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
                  ? Image.network(
                      attachment.filePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50),
                    )
                  : Image.file(
                      File(attachment.filePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, size: 50),
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
              icon: const Icon(Icons.open_in_new, color: Color(0xFF0D9488)),
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
