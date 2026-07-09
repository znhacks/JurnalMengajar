import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../models/schedule_model.dart';
import '../../models/journal_model.dart';
import '../../models/journal_attachment_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/hour_model.dart';
import '../../core/utils/helper.dart';

class FormJurnalScreen extends StatefulWidget {
  final String scheduleId;
  const FormJurnalScreen({super.key, required this.scheduleId});

  @override
  State<FormJurnalScreen> createState() => _FormJurnalScreenState();
}

class _FormJurnalScreenState extends State<FormJurnalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _materialController = TextEditingController();
  final _noteController = TextEditingController();
  final _sickNamesController = TextEditingController();
  final _permissionNamesController = TextEditingController();
  final _alphaNamesController = TextEditingController();

  int _sickCount = 0;
  int _permissionCount = 0;
  int _alphaCount = 0;

  /// Bytes gambar yang dipilih (web-compatible, tidak menggunakan File)
  Uint8List? _attachmentImageBytes;
  String? _attachmentImageName;
  String? _mockPdfName;
  final ImagePicker _picker = ImagePicker();

  JournalModel? _existingJournal;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final scheduleProvider = Provider.of<ScheduleProvider>(
        context,
        listen: false,
      );
      if (scheduleProvider.schedules.isEmpty &&
          scheduleProvider.teacherSchedulesForSelectedDate.isEmpty) {
        scheduleProvider.loadAllSchedules();
      }

      final journalProvider = Provider.of<JournalProvider>(
        context,
        listen: false,
      );
      final existing = await journalProvider.getJournalForSchedule(
        widget.scheduleId,
      );
      if (existing != null && mounted) {
        setState(() {
          _existingJournal = existing;
          _isEditing = true;
          _materialController.text = existing.material;

          // Parse structured note if it exists
          final fullNote = existing.note;
          String parsedSickNames = '';
          String parsedPermissionNames = '';
          String parsedAlphaNames = '';
          String parsedGeneralNote = '';

          if (fullNote != null) {
            if (fullNote.contains('Keterangan Absensi:')) {
              final parts = fullNote.split('\n\nCatatan Pembelajaran:\n');
              final absencePart = parts[0];
              if (parts.length > 1) {
                parsedGeneralNote = parts[1];
              } else {
                if (fullNote.contains('Catatan Pembelajaran:')) {
                  final notesParts = fullNote.split('Catatan Pembelajaran:\n');
                  if (notesParts.length > 1) {
                    parsedGeneralNote = notesParts[1];
                  }
                }
              }

              final lines = absencePart.split('\n');
              for (final line in lines) {
                if (line.startsWith('Sakit (')) {
                  final colonIndex = line.indexOf('): ');
                  if (colonIndex != -1) {
                    parsedSickNames = line.substring(colonIndex + 3);
                  }
                } else if (line.startsWith('Izin (')) {
                  final colonIndex = line.indexOf('): ');
                  if (colonIndex != -1) {
                    parsedPermissionNames = line.substring(colonIndex + 3);
                  }
                } else if (line.startsWith('Alfa (')) {
                  final colonIndex = line.indexOf('): ');
                  if (colonIndex != -1) {
                    parsedAlphaNames = line.substring(colonIndex + 3);
                  }
                }
              }
            } else {
              parsedGeneralNote = fullNote;
            }
          }

          _noteController.text = parsedGeneralNote;
          _sickNamesController.text = parsedSickNames;
          _permissionNamesController.text = parsedPermissionNames;
          _alphaNamesController.text = parsedAlphaNames;

          _sickCount = existing.sickCount;
          _permissionCount = existing.permissionCount;
          _alphaCount = existing.alphaCount;
          if (existing.attachment != null) {
            if (existing.attachment!.fileType == 'pdf') {
              _mockPdfName = existing.attachment!.fileName;
            } else {
              _attachmentImageName = existing.attachment!.fileName;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _materialController.dispose();
    _noteController.dispose();
    _sickNamesController.dispose();
    _permissionNamesController.dispose();
    _alphaNamesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        // Baca sebagai bytes agar kompatibel dengan Flutter Web
        final bytes = await image.readAsBytes();
        setState(() {
          _attachmentImageBytes = bytes;
          _attachmentImageName = image.name;
          _mockPdfName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        AppHelper.showSnackBar(
          context,
          'Gagal memilih gambar: $e',
          isError: true,
        );
      }
    }
  }

  void _showAttachmentBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pilih Lampiran Jurnal',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('Kamera (Ambil Foto)'),
                onTap: () {
                  context.pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm(ScheduleModel schedule) async {
    if (_formKey.currentState!.validate()) {
      final journalProvider = Provider.of<JournalProvider>(
        context,
        listen: false,
      );
      _formKey.currentState!.save();

      JournalAttachmentModel? attachment = _existingJournal?.attachment;
      if (_attachmentImageBytes != null && _attachmentImageName != null) {
        attachment = JournalAttachmentModel(
          id:
              _existingJournal?.attachment?.id ??
              'ja_${DateTime.now().millisecondsSinceEpoch}',
          filePath: _existingJournal?.attachment?.filePath ?? 'pending_upload',
          fileType: 'image',
          fileName: _attachmentImageName!,
        );
      } else if (_mockPdfName != null) {
        attachment = JournalAttachmentModel(
          id:
              _existingJournal?.attachment?.id ??
              'ja_${DateTime.now().millisecondsSinceEpoch}',
          filePath:
              _existingJournal?.attachment?.filePath ??
              'mock_pdf_directory/$_mockPdfName',
          fileType: 'pdf',
          fileName: _mockPdfName!,
        );
      } else if (_attachmentImageBytes == null &&
          _attachmentImageName == null &&
          _mockPdfName == null) {
        attachment = null;
      }

      // Construct structured note
      String? combinedNote;
      final absenceDetails = <String>[];
      if (_sickCount > 0 && _sickNamesController.text.trim().isNotEmpty) {
        absenceDetails.add('Sakit ($_sickCount siswa): ${_sickNamesController.text.trim()}');
      }
      if (_permissionCount > 0 && _permissionNamesController.text.trim().isNotEmpty) {
        absenceDetails.add('Izin ($_permissionCount siswa): ${_permissionNamesController.text.trim()}');
      }
      if (_alphaCount > 0 && _alphaNamesController.text.trim().isNotEmpty) {
        absenceDetails.add('Alfa ($_alphaCount siswa): ${_alphaNamesController.text.trim()}');
      }

      final generalNote = _noteController.text.trim();
      if (absenceDetails.isNotEmpty) {
        combinedNote = 'Keterangan Absensi:\n${absenceDetails.join('\n')}';
        if (generalNote.isNotEmpty) {
          combinedNote = '$combinedNote\n\nCatatan Pembelajaran:\n$generalNote';
        }
      } else {
        combinedNote = generalNote.isEmpty ? null : generalNote;
      }

      if (_isEditing) {
        final updatedJournal = JournalModel(
          id: _existingJournal!.id,
          scheduleId: schedule.id,
          date: schedule.date,
          teachingHour: schedule.teachingHour,
          classId: schedule.classId,
          subjectId: schedule.subjectId,
          teacherId: schedule.teacherId,
          material: _materialController.text.trim(),
          sickCount: _sickCount,
          permissionCount: _permissionCount,
          alphaCount: _alphaCount,
          note: combinedNote,
          attachment: attachment,
          status: 'pending', // Reset status to pending when revised!
          attachmentUrl: attachment == null
              ? null
              : _existingJournal!.attachmentUrl,
        );

        final success = await journalProvider.updateJournal(
          updatedJournal,
          attachmentBytes: _attachmentImageBytes,
          attachmentFileName: _attachmentImageName,
        );

        if (success && mounted) {
          if (journalProvider.errorMessage != null) {
            AppHelper.showSnackBar(
              context,
              journalProvider.errorMessage!,
              isError: true,
            );
          } else {
            AppHelper.showSnackBar(context, 'Revisi jurnal berhasil dikirim!');
          }
          context.pop();
        } else if (mounted) {
          AppHelper.showSnackBar(
            context,
            journalProvider.errorMessage ?? 'Gagal menyimpan revisi jurnal.',
            isError: true,
          );
        }
      } else {
        final newJournal = JournalModel(
          id: '', // Will be generated in repository
          scheduleId: schedule.id,
          date: schedule.date,
          teachingHour: schedule.teachingHour,
          classId: schedule.classId,
          subjectId: schedule.subjectId,
          teacherId: schedule.teacherId,
          material: _materialController.text.trim(),
          sickCount: _sickCount,
          permissionCount: _permissionCount,
          alphaCount: _alphaCount,
          note: combinedNote,
          attachment: attachment,
          status: 'pending',
        );

        final success = await journalProvider.createJournal(
          newJournal,
          attachmentBytes: _attachmentImageBytes,
          attachmentFileName: _attachmentImageName,
        );

        if (success && mounted) {
          if (journalProvider.errorMessage != null) {
            AppHelper.showSnackBar(
              context,
              journalProvider.errorMessage!,
              isError: true,
            );
          } else {
            AppHelper.showSnackBar(
              context,
              'Jurnal berhasil dikirim untuk verifikasi!',
            );
          }
          context.pop();
        } else if (mounted) {
          AppHelper.showSnackBar(
            context,
            journalProvider.errorMessage ?? 'Gagal menyimpan jurnal.',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    ScheduleModel? schedule;
    try {
      schedule = scheduleProvider.schedules.firstWhere(
        (s) => s.id == widget.scheduleId,
        orElse: () => scheduleProvider.teacherSchedulesForSelectedDate
            .firstWhere((s) => s.id == widget.scheduleId),
      );
    } catch (_) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Revisi Jurnal' : 'Isi Jurnal'),
        ),
        body: const Center(child: Text('Jadwal tidak ditemukan')),
      );
    }

    final cls = masterProvider.classes.firstWhere(
      (c) => c.id == schedule?.classId,
      orElse: () =>
          ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
    );

    final subject = masterProvider.subjects.firstWhere(
      (s) => s.id == schedule?.subjectId,
      orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
    );

    final hr = masterProvider.hours.firstWhere(
      (h) => h.teachingHour == schedule?.teachingHour,
      orElse: () => HourModel(
        id: '',
        teachingHour: schedule?.teachingHour ?? 1,
        startTime: '00:00',
        endTime: '00:00',
      ),
    );

    final isLoading = journalProvider.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Revisi Jurnal Mengajar' : 'Isi Jurnal Mengajar',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Summary Card (Read-only)
                Card(
                  color: const Color(0xFFF1F5F9),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        _buildSummaryRow('Kelas', cls.name),
                        const Divider(height: 16),
                        _buildSummaryRow('Mata Pelajaran', subject.name),
                        const Divider(height: 16),
                        _buildSummaryRow(
                          'Tanggal',
                          AppHelper.formatDate(schedule.date),
                        ),
                        const Divider(height: 16),
                        _buildSummaryRow(
                          'Jam Pelajaran',
                          'Jam Ke-${schedule.teachingHour} (${hr.startTime} - ${hr.endTime})',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Materi Pembelajaran (Required)
                Text(
                  'Materi Pembelajaran *',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _materialController,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Materi pembelajaran tidak boleh kosong';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    hintText:
                        'Jelaskan secara ringkas materi yang diajarkan hari ini...',
                    fillColor: Colors.white,
                  ),
                ),
                SizedBox(height: 20.h),

                // Absensi Siswa
                Text(
                  'Absensi Siswa (Jumlah Siswa)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCounterWidget(
                      'Sakit',
                      _sickCount,
                      (val) => setState(() => _sickCount = val),
                    ),
                    _buildCounterWidget(
                      'Izin',
                      _permissionCount,
                      (val) => setState(() => _permissionCount = val),
                    ),
                    _buildCounterWidget(
                      'Alpha',
                      _alphaCount,
                      (val) => setState(() => _alphaCount = val),
                    ),
                  ],
                ),
                if (_sickCount > 0) ...[
                  SizedBox(height: 16.h),
                  Text(
                    'Siapa yang Sakit?',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _sickNamesController,
                    validator: (value) {
                      if (_sickCount > 0 && (value == null || value.trim().isEmpty)) {
                        return 'Nama siswa yang sakit tidak boleh kosong';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Nama siswa yang sakit (misal: Budi, Ani)',
                      fillColor: Colors.white,
                    ),
                  ),
                ],
                if (_permissionCount > 0) ...[
                  SizedBox(height: 16.h),
                  Text(
                    'Siapa yang Izin?',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _permissionNamesController,
                    validator: (value) {
                      if (_permissionCount > 0 && (value == null || value.trim().isEmpty)) {
                        return 'Nama siswa yang izin tidak boleh kosong';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Nama siswa yang izin (misal: Candra, Dedi)',
                      fillColor: Colors.white,
                    ),
                  ),
                ],
                if (_alphaCount > 0) ...[
                  SizedBox(height: 16.h),
                  Text(
                    'Siapa yang Alfa?',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  TextFormField(
                    controller: _alphaNamesController,
                    validator: (value) {
                      if (_alphaCount > 0 && (value == null || value.trim().isEmpty)) {
                        return 'Nama siswa yang alfa tidak boleh kosong';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText: 'Nama siswa yang alfa (misal: Eki, Fani)',
                      fillColor: Colors.white,
                    ),
                  ),
                ],
                SizedBox(height: 24.h),

                // Catatan Mengajar
                Text(
                  'Catatan Pembelajaran',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Catatan tambahan seperti siswa yang tidak kondusif, kendala sarana, dll (Opsional)...',
                    fillColor: Colors.white,
                  ),
                ),
                SizedBox(height: 20.h),

                // Lampiran Jurnal
                Text(
                  'Lampiran (Foto)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8.h),
                InkWell(
                  onTap: _showAttachmentBottomSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: 24.h,
                      horizontal: 16.w,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        if (_attachmentImageBytes == null &&
                            _attachmentImageName == null &&
                            _mockPdfName == null) ...[
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 40.w,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Klik untuk mengunggah Lampiran',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'Mendukung Foto (Kamera)',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[450],
                            ),
                          ),
                        ] else if (_attachmentImageBytes != null ||
                            _attachmentImageName != null) ...[
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _attachmentImageBytes != null
                                    ? Image.memory(
                                        _attachmentImageBytes!,
                                        height: 60.h,
                                        width: 60.h,
                                        fit: BoxFit.cover,
                                      )
                                    : (_existingJournal?.attachment?.filePath !=
                                                  null &&
                                              _existingJournal!
                                                  .attachment!
                                                  .filePath
                                                  .startsWith('http')
                                          ? Image.network(
                                              _existingJournal!
                                                  .attachment!
                                                  .filePath,
                                              height: 60.h,
                                              width: 60.h,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Icon(
                                                    Icons.image,
                                                    size: 30,
                                                  ),
                                            )
                                          : Container(
                                              height: 60.h,
                                              width: 60.h,
                                              color: Colors.grey[200],
                                              child: const Icon(Icons.image),
                                            )),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _attachmentImageName ?? 'Foto Lampiran',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Tipe: Image (Foto)',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => setState(() {
                                  _attachmentImageBytes = null;
                                  _attachmentImageName = null;
                                }),
                              ),
                            ],
                          ),
                        ] else if (_mockPdfName != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _mockPdfName!,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Tipe: PDF Dokumen',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    setState(() => _mockPdfName = null),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 40.h),

                // Submit Button
                ElevatedButton(
                  onPressed: isLoading ? null : () => _submitForm(schedule!),
                  child: isLoading
                      ? SizedBox(
                          height: 24.w,
                          width: 24.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _isEditing ? 'Kirim Revisi Jurnal' : 'Simpan Jurnal',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterWidget(
    String title,
    int count,
    ValueChanged<int> onChanged,
  ) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.grey[750],
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: count > 0 ? () => onChanged(count - 1) : null,
              ),
              Text(
                '$count',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => onChanged(count + 1),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
