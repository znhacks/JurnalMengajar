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
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helper.dart';

class FormJurnalScreen extends StatefulWidget {
  final String scheduleId;
  final String? dateStr;
  const FormJurnalScreen({super.key, required this.scheduleId, this.dateStr});

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

  final Map<String, String> _studentAttendance = {};

  /// Multi-image support (max 3)
  final List<Uint8List> _imageBytesList = [];
  final List<String> _imageNamesList = [];
  final List<String> _existingImageUrls = []; // URLs existing saat edit
  static const int _maxImages = 3;
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

      final journalProvider = Provider.of<JournalProvider>(
        context,
        listen: false,
      );
      final existing = await journalProvider.getJournalForSchedule(
        widget.scheduleId,
      );

      ScheduleModel? schedule;
      try {
        schedule = scheduleProvider.cachedTeacherSchedules.firstWhere(
          (s) => s.id == widget.scheduleId,
          orElse: () => scheduleProvider.schedules.firstWhere(
            (s) => s.id == widget.scheduleId,
            orElse: () => scheduleProvider.teacherSchedulesForSelectedDate.firstWhere(
              (s) => s.id == widget.scheduleId,
            ),
          ),
        );
      } catch (_) {}

      if (schedule == null && mounted) {
        await scheduleProvider.loadAllSchedules();
        try {
          schedule = scheduleProvider.schedules.firstWhere(
            (s) => s.id == widget.scheduleId,
          );
        } catch (_) {}
      }

      if (schedule != null && mounted) {
        final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
        await masterProvider.loadStudentsForClass(schedule.classId);

        if (existing != null) {
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

            final sickNames = parsedSickNames.split(',').map((e) => e.trim().toLowerCase()).toList();
            final permNames = parsedPermissionNames.split(',').map((e) => e.trim().toLowerCase()).toList();
            final alphaNames = parsedAlphaNames.split(',').map((e) => e.trim().toLowerCase()).toList();

            for (final s in masterProvider.students) {
              final sName = s.name.trim().toLowerCase();
              if (sickNames.contains(sName)) {
                _studentAttendance[s.id] = 'S';
              } else if (permNames.contains(sName)) {
                _studentAttendance[s.id] = 'I';
              } else if (alphaNames.contains(sName)) {
                _studentAttendance[s.id] = 'A';
              } else {
                _studentAttendance[s.id] = 'H';
              }
            }

            // Restore existing attachment URLs into list
            if (existing.attachmentUrl != null && existing.attachmentUrl!.isNotEmpty) {
              _existingImageUrls.addAll(
                existing.attachmentUrl!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
              );
            } else if (existing.attachment?.filePath != null) {
              _existingImageUrls.add(existing.attachment!.filePath);
            }
          });
        } else {
          setState(() {
            for (final s in masterProvider.students) {
              _studentAttendance[s.id] = 'H';
            }
          });
        }
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
    final totalSlots = _existingImageUrls.length + _imageBytesList.length;
    if (totalSlots >= _maxImages) {
      AppHelper.showSnackBar(context, 'Maksimal $_maxImages foto lampiran.', isError: true);
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytesList.add(bytes);
          _imageNamesList.add(image.name);
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


  /// Helper widget untuk satu tile foto dengan tombol hapus
  Widget _buildPhotoTile({
    required Widget child,
    required VoidCallback onDelete,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 80.w,
            height: 80.w,
            child: child,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitForm(ScheduleModel schedule) async {
    final masterProvider = Provider.of<MasterDataProvider>(context, listen: false);
    final sickNamesList = masterProvider.students
        .where((s) => _studentAttendance[s.id] == 'S')
        .map((s) => s.name)
        .toList();
    final permNamesList = masterProvider.students
        .where((s) => _studentAttendance[s.id] == 'I')
        .map((s) => s.name)
        .toList();
    final alphaNamesList = masterProvider.students
        .where((s) => _studentAttendance[s.id] == 'A')
        .map((s) => s.name)
        .toList();

    _sickCount = sickNamesList.length;
    _permissionCount = permNamesList.length;
    _alphaCount = alphaNamesList.length;

    _sickNamesController.text = sickNamesList.join(', ');
    _permissionNamesController.text = permNamesList.join(', ');
    _alphaNamesController.text = alphaNamesList.join(', ');

    if (_formKey.currentState!.validate()) {
      final journalProvider = Provider.of<JournalProvider>(
        context,
        listen: false,
      );
      _formKey.currentState!.save();

      // Build first attachment model (for legacy compat)
      JournalAttachmentModel? attachment;
      final hasNewImages = _imageBytesList.isNotEmpty;
      final hasExisting = _existingImageUrls.isNotEmpty;
      if (hasNewImages) {
        attachment = JournalAttachmentModel(
          id: _existingJournal?.attachment?.id ?? 'ja_${DateTime.now().millisecondsSinceEpoch}',
          filePath: _existingJournal?.attachment?.filePath ?? 'pending_upload',
          fileType: 'image',
          fileName: _imageNamesList.first,
        );
      } else if (hasExisting) {
        attachment = _existingJournal?.attachment;
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
          imageBytesList: _imageBytesList,
          imageNamesList: _imageNamesList,
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
          date: widget.dateStr != null ? DateTime.parse(widget.dateStr!) : schedule.date,
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
          imageBytesList: _imageBytesList,
          imageNamesList: _imageNamesList,
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
      schedule = scheduleProvider.cachedTeacherSchedules.firstWhere(
        (s) => s.id == widget.scheduleId,
        orElse: () => scheduleProvider.schedules.firstWhere(
          (s) => s.id == widget.scheduleId,
          orElse: () => scheduleProvider.teacherSchedulesForSelectedDate.firstWhere(
            (s) => s.id == widget.scheduleId,
          ),
        ),
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
                          AppHelper.formatDate(widget.dateStr != null ? DateTime.parse(widget.dateStr!) : schedule.date),
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
                  'Absensi Siswa (Daftar Kelas)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 8.h),
                // Attendance Summary Header Card
                Builder(
                  builder: (context) {
                    final totalStudents = masterProvider.students.length;
                    final totalHadir = masterProvider.students.where((s) => _studentAttendance[s.id] == 'H' || _studentAttendance[s.id] == null).length;
                    final totalSakit = masterProvider.students.where((s) => _studentAttendance[s.id] == 'S').length;
                    final totalIzin = masterProvider.students.where((s) => _studentAttendance[s.id] == 'I').length;
                    final totalAlfa = masterProvider.students.where((s) => _studentAttendance[s.id] == 'A').length;

                    return Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppTheme.outlineVariant),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSummaryItem('Total', '$totalStudents', Colors.black87),
                          _buildSummaryItem('Hadir', '$totalHadir', const Color(0xFF10B981)),
                          _buildSummaryItem('Sakit', '$totalSakit', const Color(0xFF2563EB)),
                          _buildSummaryItem('Izin', '$totalIzin', const Color(0xFFF59E0B)),
                          _buildSummaryItem('Alfa', '$totalAlfa', Colors.red),
                        ],
                      ),
                    );
                  }
                ),
                SizedBox(height: 12.h),
                // Students List
                Container(
                  constraints: BoxConstraints(maxHeight: 280.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: masterProvider.students.isEmpty
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(
                              'Tidak ada siswa terdaftar di kelas ini',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.all(10.w),
                          itemCount: masterProvider.students.length,
                          separatorBuilder: (context, _) => const Divider(height: 8, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final student = masterProvider.students[index];
                            final status = _studentAttendance[student.id] ?? 'H';

                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 4.h),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          style: GoogleFonts.hankenGrotesk(
                                            fontSize: 12.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.onBackground,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (student.nis != null && student.nis!.isNotEmpty)
                                          Text(
                                            'NIS: ${student.nis}',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontSize: 10.sp,
                                              color: AppTheme.outline,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  // H, S, I, A Status Toggle Buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStatusToggle('H', status == 'H', const Color(0xFF10B981), () {
                                        setState(() {
                                          _studentAttendance[student.id] = 'H';
                                        });
                                      }),
                                      SizedBox(width: 4.w),
                                      _buildStatusToggle('S', status == 'S', const Color(0xFF2563EB), () {
                                        setState(() {
                                          _studentAttendance[student.id] = 'S';
                                        });
                                      }),
                                      SizedBox(width: 4.w),
                                      _buildStatusToggle('I', status == 'I', const Color(0xFFF59E0B), () {
                                        setState(() {
                                          _studentAttendance[student.id] = 'I';
                                        });
                                      }),
                                      SizedBox(width: 4.w),
                                      _buildStatusToggle('A', status == 'A', Colors.red, () {
                                        setState(() {
                                          _studentAttendance[student.id] = 'A';
                                        });
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
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
                  'Lampiran Foto (Maks 3)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Tambahkan foto bukti kegiatan mengajar',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
                ),
                SizedBox(height: 10.h),
                Builder(builder: (context) {
                  final totalSlots = _existingImageUrls.length + _imageBytesList.length;
                  final canAdd = totalSlots < _maxImages;
                  return Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: [
                      // Existing photos (from edit mode)
                      for (int i = 0; i < _existingImageUrls.length; i++)
                        _buildPhotoTile(
                          child: _existingImageUrls[i].startsWith('http')
                              ? Image.network(
                                  _existingImageUrls[i],
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, st) =>
                                      const Icon(Icons.broken_image, color: Colors.grey),
                                )
                              : const Icon(Icons.image, color: Colors.grey),
                          onDelete: () => setState(() => _existingImageUrls.removeAt(i)),
                        ),
                      // New photos
                      for (int i = 0; i < _imageBytesList.length; i++)
                        _buildPhotoTile(
                          child: Image.memory(_imageBytesList[i], fit: BoxFit.cover),
                          onDelete: () => setState(() {
                            _imageBytesList.removeAt(i);
                            _imageNamesList.removeAt(i);
                          }),
                        ),
                      // Add button slot
                      if (canAdd)
                        InkWell(
                          onTap: () => _pickImage(ImageSource.camera),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 80.w,
                            height: 80.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 22.r, color: const Color(0xFF2563EB)),
                                SizedBox(height: 4.h),
                                Text(
                                  'Tambah\nFoto',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: const Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }),
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

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.8),
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          value,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusToggle(
    String label,
    bool isSelected,
    Color activeColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
