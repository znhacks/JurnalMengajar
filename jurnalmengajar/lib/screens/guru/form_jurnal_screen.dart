import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/master_data_provider.dart';
import '../../providers/schedule_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/schedule_model.dart';
import '../../models/journal_model.dart';
import '../../models/journal_attachment_model.dart';
import '../../models/class_model.dart';
import '../../models/subject_model.dart';
import '../../models/student_model.dart';
import '../../models/teacher_model.dart';
import '../../models/hour_model.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/helper.dart';
import '../../services/nobox_wa_service.dart';
import '../../core/services/cache_service.dart';

class FormJurnalScreen extends StatefulWidget {
  final String scheduleId;
  final String? dateStr;
  final String? journalId;
  const FormJurnalScreen({
    super.key,
    required this.scheduleId,
    this.dateStr,
    this.journalId,
  });

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
  String? _selectedScheduleId;
  bool _isSaving = false;
  String _teacherAttendanceStatus = 'hadir'; // 'hadir' | 'sakit' | 'izin'
  bool _applyToAllSchedulesToday = false;

  @override
  void initState() {
    super.initState();
    _selectedScheduleId = widget.scheduleId.isNotEmpty ? widget.scheduleId : null;

    _materialController.addListener(_autoSaveDraft);
    _noteController.addListener(_autoSaveDraft);
    _sickNamesController.addListener(_autoSaveDraft);
    _permissionNamesController.addListener(_autoSaveDraft);
    _alphaNamesController.addListener(_autoSaveDraft);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final scheduleProvider = Provider.of<ScheduleProvider>(
        context,
        listen: false,
      );

      final journalProvider = Provider.of<JournalProvider>(
        context,
        listen: false,
      );

      final masterProvider = Provider.of<MasterDataProvider>(
        context,
        listen: false,
      );

      DateTime? targetDate;
      if (widget.dateStr != null) {
        try {
          targetDate = DateTime.parse(widget.dateStr!);
        } catch (_) {}
      }

      // If no scheduleId provided (e.g. opened via Tambah Task), auto-select first schedule for target date
      if (_selectedScheduleId == null || _selectedScheduleId!.isEmpty) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          final teacher = masterProvider.teachers.firstWhere(
            (t) => t.email.toLowerCase() == currentUser.email.toLowerCase(),
            orElse: () => TeacherModel(id: '', name: '', position: '', address: '', phoneNumber: '', email: ''),
          );
          if (teacher.id.isNotEmpty && targetDate != null) {
            await scheduleProvider.loadTeacherSchedules(teacher.id, targetDate);
          }
        }

        final availableSchedules = scheduleProvider.cachedTeacherSchedules.where((s) {
          if (!s.isActive) return false;
          if (targetDate != null) {
            return s.date.year == targetDate.year &&
                s.date.month == targetDate.month &&
                s.date.day == targetDate.day;
          }
          return true;
        }).toList();

        if (availableSchedules.isNotEmpty) {
          setState(() {
            _selectedScheduleId = availableSchedules.first.id;
          });
        }
      }

      final activeId = _selectedScheduleId ?? widget.scheduleId;
      JournalModel? existing;

      // 1. Try finding by journalId
      if (widget.journalId != null && widget.journalId!.isNotEmpty) {
        try {
          existing = journalProvider.teacherJournals.firstWhere(
            (j) => j.id == widget.journalId,
            orElse: () => journalProvider.journals.firstWhere(
              (j) => j.id == widget.journalId,
            ),
          );
        } catch (_) {}
      }

      // 2. Try finding in loaded journals by scheduleId and date
      if (existing == null && activeId.isNotEmpty) {
        try {
          existing = journalProvider.teacherJournals.firstWhere(
            (j) {
              final sameSchedule = j.scheduleId == activeId;
              if (targetDate != null) {
                return sameSchedule &&
                    j.date.year == targetDate.year &&
                    j.date.month == targetDate.month &&
                    j.date.day == targetDate.day;
              }
              return sameSchedule;
            },
            orElse: () => journalProvider.journals.firstWhere(
              (j) {
                final sameSchedule = j.scheduleId == activeId;
                if (targetDate != null) {
                  return sameSchedule &&
                      j.date.year == targetDate.year &&
                      j.date.month == targetDate.month &&
                      j.date.day == targetDate.day;
                }
                return sameSchedule;
              },
            ),
          );
        } catch (_) {}

        // 3. Fallback DB lookup
        existing ??= await journalProvider.getJournalForSchedule(
          activeId,
          date: targetDate,
        );
      }

      ScheduleModel? schedule;
      if (activeId.isNotEmpty) {
        try {
          schedule = scheduleProvider.cachedTeacherSchedules.firstWhere(
            (s) => s.id == activeId,
            orElse: () => scheduleProvider.schedules.firstWhere(
              (s) => s.id == activeId,
              orElse: () => scheduleProvider.teacherSchedulesForSelectedDate.firstWhere(
                (s) => s.id == activeId,
              ),
            ),
          );
        } catch (_) {}
      }

      if (schedule == null && activeId.isNotEmpty && mounted) {
        await scheduleProvider.loadAllSchedules();
        try {
          schedule = scheduleProvider.schedules.firstWhere(
            (s) => s.id == activeId,
          );
        } catch (_) {}
      }

      if (schedule != null && mounted) {
        await masterProvider.loadStudentsForClass(schedule.classId);

        if (existing != null) {
          final journalData = existing;
          setState(() {
            _existingJournal = journalData;
            _isEditing = true;
            _teacherAttendanceStatus = journalData.teacherAttendanceStatus;
            _materialController.text = journalData.material;

            // Parse structured note if it exists
            final fullNote = journalData.note;
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

            _sickCount = journalData.sickCount;
            _permissionCount = journalData.permissionCount;
            _alphaCount = journalData.alphaCount;

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
            if (journalData.attachmentUrl != null && journalData.attachmentUrl!.isNotEmpty) {
              _existingImageUrls.addAll(
                journalData.attachmentUrl!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
              );
            } else if (journalData.attachment?.filePath != null) {
              _existingImageUrls.add(journalData.attachment!.filePath);
            }
          });
        } else {
          // Restore saved draft if user previously typed on weak signal
          final draft = await CacheService().loadMap('draft_journal_$activeId');
          if (draft != null && mounted) {
            setState(() {
              _teacherAttendanceStatus = draft['teacherAttendanceStatus']?.toString() ?? 'hadir';
              _materialController.text = draft['material']?.toString() ?? '';
              _noteController.text = draft['note']?.toString() ?? '';
              _sickNamesController.text = draft['sickNames']?.toString() ?? '';
              _permissionNamesController.text = draft['permissionNames']?.toString() ?? '';
              _alphaNamesController.text = draft['alphaNames']?.toString() ?? '';
              _sickCount = draft['sickCount'] as int? ?? 0;
              _permissionCount = draft['permissionCount'] as int? ?? 0;
              _alphaCount = draft['alphaCount'] as int? ?? 0;
              if (draft['studentAttendance'] != null && draft['studentAttendance'] is Map) {
                final rawAtt = draft['studentAttendance'] as Map;
                rawAtt.forEach((k, v) {
                  _studentAttendance[k.toString()] = v.toString();
                });
              }
              for (final s in masterProvider.students) {
                _studentAttendance.putIfAbsent(s.id, () => 'H');
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
      }
    });
  }

  void _autoSaveDraft() {
    final activeId = _selectedScheduleId ?? widget.scheduleId;
    if (activeId.isEmpty || _isEditing) return;

    CacheService().save('draft_journal_$activeId', {
      'teacherAttendanceStatus': _teacherAttendanceStatus,
      'material': _materialController.text,
      'note': _noteController.text,
      'sickNames': _sickNamesController.text,
      'permissionNames': _permissionNamesController.text,
      'alphaNames': _alphaNamesController.text,
      'sickCount': _sickCount,
      'permissionCount': _permissionCount,
      'alphaCount': _alphaCount,
      'studentAttendance': _studentAttendance,
    });
  }

  @override
  void dispose() {
    _materialController.removeListener(_autoSaveDraft);
    _noteController.removeListener(_autoSaveDraft);
    _sickNamesController.removeListener(_autoSaveDraft);
    _permissionNamesController.removeListener(_autoSaveDraft);
    _alphaNamesController.removeListener(_autoSaveDraft);
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

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Sumber Foto',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                ),
                title: Text(
                  'Ambil Foto dari Kamera',
                  style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                ),
                title: Text(
                  'Pilih dari Galeri Foto / Dokumen',
                  style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm(ScheduleModel schedule) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final isAbsence = _teacherAttendanceStatus == 'sakit' || _teacherAttendanceStatus == 'izin';

      if (isAbsence) {
        final totalPhotos = _imageBytesList.length + _existingImageUrls.length;
        if (totalPhotos < 1) {
          AppHelper.showSnackBar(
            context,
            'Wajib melampirkan minimal 1 foto surat keterangan / izin!',
            isError: true,
          );
          return;
        }

        final journalProvider = Provider.of<JournalProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final effectiveSchoolId = authProvider.activeSchoolId ?? schedule.schoolId ?? _existingJournal?.schoolId;

        final absenceLabel = _teacherAttendanceStatus == 'sakit'
            ? '[GURU SAKIT] Surat Keterangan Dokter'
            : '[GURU IZIN] Surat Izin / Dispensasi';

        final customNote = _noteController.text.trim();
        final finalNote = customNote.isNotEmpty ? 'Keterangan: $customNote' : null;

        JournalAttachmentModel? attachment;
        if (_imageBytesList.isNotEmpty) {
          attachment = JournalAttachmentModel(
            id: _existingJournal?.attachment?.id ?? 'ja_${DateTime.now().millisecondsSinceEpoch}',
            filePath: _existingJournal?.attachment?.filePath ?? 'pending_upload',
            fileType: 'image',
            fileName: _imageNamesList.first,
          );
        } else if (_existingImageUrls.isNotEmpty) {
          attachment = _existingJournal?.attachment;
        }

        if (_isEditing) {
          final updatedJournal = JournalModel(
            id: _existingJournal!.id,
            scheduleId: schedule.id,
            date: _existingJournal!.date,
            teachingHour: schedule.teachingHour,
            classId: schedule.classId,
            subjectId: schedule.subjectId,
            teacherId: schedule.teacherId,
            material: absenceLabel,
            sickCount: 0,
            permissionCount: 0,
            alphaCount: 0,
            note: finalNote,
            attachment: attachment,
            status: 'pending',
            attachmentUrl: _existingImageUrls.isNotEmpty ? _existingImageUrls.join(',') : null,
            rejectionNote: null,
            schoolId: effectiveSchoolId,
            teacherAttendanceStatus: _teacherAttendanceStatus,
          );

          final success = await journalProvider.updateJournal(
            updatedJournal,
            imageBytesList: _imageBytesList,
            imageNamesList: _imageNamesList,
          );

          if (success && mounted) {
            AppHelper.showSnackBar(context, 'Surat keterangan berhasil diperbarui & dikirim!');
            context.pop();
          } else if (mounted) {
            AppHelper.showSnackBar(
              context,
              journalProvider.errorMessage ?? 'Gagal memperbarui surat keterangan.',
              isError: true,
            );
          }
        } else {
          final targetDate = widget.dateStr != null ? DateTime.parse(widget.dateStr!) : schedule.date;
          final newJournal = JournalModel(
            id: '',
            scheduleId: schedule.id,
            date: targetDate,
            teachingHour: schedule.teachingHour,
            classId: schedule.classId,
            subjectId: schedule.subjectId,
            teacherId: schedule.teacherId,
            material: absenceLabel,
            sickCount: 0,
            permissionCount: 0,
            alphaCount: 0,
            note: finalNote,
            attachment: attachment,
            status: 'pending',
            schoolId: effectiveSchoolId,
            teacherAttendanceStatus: _teacherAttendanceStatus,
          );

          final success = await journalProvider.createJournal(
            newJournal,
            imageBytesList: _imageBytesList,
            imageNamesList: _imageNamesList,
          );

          if (success && mounted) {
            CacheService().remove('draft_journal_${schedule.id}');

            // Multi-schedule batch apply if checked
            if (_applyToAllSchedulesToday) {
              final scheduleProvider = Provider.of<ScheduleProvider>(context, listen: false);
              final availableSchedules = scheduleProvider.cachedTeacherSchedules.where((s) {
                if (!s.isActive) return false;
                return s.date.year == targetDate.year &&
                    s.date.month == targetDate.month &&
                    s.date.day == targetDate.day;
              }).toList();

              final otherSchedules = availableSchedules.where((s) => s.id != schedule.id).toList();
              if (otherSchedules.isNotEmpty) {
                final created = await journalProvider.getJournalForSchedule(schedule.id, date: newJournal.date);
                final uploadedUrl = created?.attachmentUrl;
                final sharedAttachment = created?.attachment ?? attachment;

                for (final otherSched in otherSchedules) {
                  final existingOther = await journalProvider.getJournalForSchedule(otherSched.id, date: otherSched.date);
                  if (existingOther == null) {
                    final multiJournal = JournalModel(
                      id: '',
                      scheduleId: otherSched.id,
                      date: otherSched.date,
                      teachingHour: otherSched.teachingHour,
                      classId: otherSched.classId,
                      subjectId: otherSched.subjectId,
                      teacherId: otherSched.teacherId,
                      material: absenceLabel,
                      sickCount: 0,
                      permissionCount: 0,
                      alphaCount: 0,
                      note: finalNote,
                      attachment: sharedAttachment,
                      attachmentUrl: uploadedUrl,
                      status: 'pending',
                      schoolId: effectiveSchoolId,
                      teacherAttendanceStatus: _teacherAttendanceStatus,
                    );
                    await journalProvider.createJournal(multiJournal);
                  }
                }
              }
            }

            if (mounted) {
              AppHelper.showSnackBar(
                context,
                _applyToAllSchedulesToday
                    ? 'Surat ${_teacherAttendanceStatus == "sakit" ? "sakit" : "izin"} berhasil diterapkan untuk seluruh jadwal hari ini!'
                    : 'Surat ${_teacherAttendanceStatus == "sakit" ? "sakit" : "izin"} berhasil dikirim untuk verifikasi!',
              );
              context.pop();
            }
          } else if (mounted) {
            AppHelper.showSnackBar(
              context,
              journalProvider.errorMessage ?? 'Gagal menyimpan surat keterangan.',
              isError: true,
            );
          }
        }
        return;
      }

      // Normal teaching journal flow (hadir)
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
        final totalPhotos = _imageBytesList.length + _existingImageUrls.length;
        if (totalPhotos < 1) {
          AppHelper.showSnackBar(
            context,
            'Wajib melampirkan minimal 1 foto kegiatan pembelajaran!',
            isError: true,
          );
          return;
        }

        final journalProvider = Provider.of<JournalProvider>(
          context,
          listen: false,
        );
        final authProvider = Provider.of<AuthProvider>(
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

        final effectiveSchoolId = authProvider.activeSchoolId ?? schedule.schoolId ?? _existingJournal?.schoolId;

        if (_isEditing) {
          final updatedJournal = JournalModel(
            id: _existingJournal!.id,
            scheduleId: schedule.id,
            date: _existingJournal!.date,
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
            attachmentUrl: _existingImageUrls.isNotEmpty
                ? _existingImageUrls.join(',')
                : null,
            rejectionNote: null, // Clear rejection note when revised!
            schoolId: effectiveSchoolId,
            teacherAttendanceStatus: 'hadir',
          );

          final success = await journalProvider.updateJournal(
            updatedJournal,
            imageBytesList: _imageBytesList,
            imageNamesList: _imageNamesList,
          );

          if (success && mounted) {
            final cls = masterProvider.classes.firstWhere(
              (c) => c.id == schedule.classId,
              orElse: () => ClassModel(id: '', name: 'Kelas', periodId: '', studentCount: 0),
            );
            final subject = masterProvider.subjects.firstWhere(
              (s) => s.id == schedule.subjectId,
              orElse: () => SubjectModel(id: '', name: 'Mata Pelajaran', isActive: true),
            );

            final activeSchoolId = context.read<AuthProvider>().activeSchoolId;
            // Trigger Nobox AI WhatsApp Student Absence notifications (Sakit / Izin / Alpha)
            _studentAttendance.forEach((studentId, status) {
              if (status == 'S' || status == 'I' || status == 'A') {
                final student = masterProvider.students.firstWhere(
                  (s) => s.id == studentId,
                  orElse: () => StudentModel(
                    id: '',
                    classId: '',
                    name: 'Siswa',
                  ),
                );
                NoboxWaService.sendAbsenceNotification(
                  student: student,
                  statusType: status,
                  classModel: cls,
                  subjectModel: subject,
                  date: updatedJournal.date,
                  schoolId: activeSchoolId,
                );
              }
            });

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
            schoolId: effectiveSchoolId,
            teacherAttendanceStatus: 'hadir',
          );

          final success = await journalProvider.createJournal(
            newJournal,
            imageBytesList: _imageBytesList,
            imageNamesList: _imageNamesList,
          );

          if (success && mounted) {
            final cls = masterProvider.classes.firstWhere(
              (c) => c.id == schedule.classId,
              orElse: () => ClassModel(id: '', name: 'Kelas', periodId: '', studentCount: 0),
            );
            final subject = masterProvider.subjects.firstWhere(
              (s) => s.id == schedule.subjectId,
              orElse: () => SubjectModel(id: '', name: 'Mata Pelajaran', isActive: true),
            );

            final activeSchoolId = context.read<AuthProvider>().activeSchoolId;
            // Trigger Nobox AI WhatsApp Student Absence notifications (Sakit / Izin / Alpha)
            _studentAttendance.forEach((studentId, status) {
              if (status == 'S' || status == 'I' || status == 'A') {
                final student = masterProvider.students.firstWhere(
                  (s) => s.id == studentId,
                  orElse: () => StudentModel(
                    id: '',
                    classId: '',
                    name: 'Siswa',
                  ),
                );
                NoboxWaService.sendAbsenceNotification(
                  student: student,
                  statusType: status,
                  classModel: cls,
                  subjectModel: subject,
                  date: newJournal.date,
                  schoolId: activeSchoolId,
                );
              }
            });

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
            CacheService().remove('draft_journal_${schedule.id}');
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
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final masterProvider = context.watch<MasterDataProvider>();
    final scheduleProvider = context.watch<ScheduleProvider>();
    final journalProvider = context.watch<JournalProvider>();

    final activeId = _selectedScheduleId ?? widget.scheduleId;
    DateTime? targetDate;
    if (widget.dateStr != null) {
      try {
        targetDate = DateTime.parse(widget.dateStr!);
      } catch (_) {}
    }

    final availableSchedules = scheduleProvider.cachedTeacherSchedules.where((s) {
      if (!s.isActive) return false;
      if (targetDate != null) {
        return s.date.year == targetDate.year &&
            s.date.month == targetDate.month &&
            s.date.day == targetDate.day;
      }
      return true;
    }).toList();

    ScheduleModel? schedule;
    if (activeId.isNotEmpty) {
      try {
        schedule = scheduleProvider.cachedTeacherSchedules.firstWhere(
          (s) => s.id == activeId,
          orElse: () => scheduleProvider.schedules.firstWhere(
            (s) => s.id == activeId,
            orElse: () => scheduleProvider.teacherSchedulesForSelectedDate.firstWhere(
              (s) => s.id == activeId,
            ),
          ),
        );
      } catch (_) {}
    }

    if (schedule == null && availableSchedules.isNotEmpty) {
      schedule = availableSchedules.first;
    }

    if (schedule == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Revisi Jurnal' : 'Isi Jurnal'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_rounded, size: 64.r, color: Colors.grey[400]),
                SizedBox(height: 16.h),
                Text(
                  'Tidak Ada Jadwal',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Tidak ada jadwal mengajar pada tanggal ini. Silakan pilih tanggal yang memiliki jadwal mengajar.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 20.h),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Kembali ke Kalender'),
                ),
              ],
            ),
          ),
        ),
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
                if (_existingJournal?.status == 'rejected') ...[
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 22.sp),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jurnal Ditolak (Perlu Revisi)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                  fontSize: 13.sp,
                                ),
                              ),
                              if (_existingJournal?.rejectionNote != null && _existingJournal!.rejectionNote!.isNotEmpty) ...[
                                SizedBox(height: 4.h),
                                Text(
                                  'Catatan Penolakan: ${_existingJournal!.rejectionNote}',
                                  style: TextStyle(
                                    color: Colors.red.shade800,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                ],
                // Info Summary Card (Read-only)
                Builder(
                  builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Card(
                      color: isDark
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : const Color(0xFFF1F5F9),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          children: [
                            _buildSummaryRow(context, 'Kelas', cls.name),
                            const Divider(height: 16),
                            _buildSummaryRow(context, 'Mata Pelajaran', subject.name),
                            const Divider(height: 16),
                            _buildSummaryRow(
                              context,
                              'Tanggal',
                              AppHelper.formatDate(_existingJournal?.date ?? (widget.dateStr != null ? DateTime.parse(widget.dateStr!) : (schedule?.date ?? DateTime.now()))),
                            ),
                            const Divider(height: 16),
                            _buildSummaryRow(
                              context,
                              'Jam Pelajaran',
                              'Jam Ke-${schedule?.teachingHour ?? 1} (${hr.startTime} - ${hr.endTime})',
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                ),
                SizedBox(height: 20.h),

                // Status Kehadiran Guru Selector
                Text(
                  'Status Kehadiran Guru *',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildAttendanceTypeOption(
                        context,
                        id: 'hadir',
                        label: 'Hadir',
                        subtitle: 'Mengajar',
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF10B981),
                        isSelected: _teacherAttendanceStatus == 'hadir',
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildAttendanceTypeOption(
                        context,
                        id: 'izin',
                        label: 'Izin',
                        subtitle: 'Surat Izin',
                        icon: Icons.assignment_outlined,
                        color: const Color(0xFFF59E0B),
                        isSelected: _teacherAttendanceStatus == 'izin',
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _buildAttendanceTypeOption(
                        context,
                        id: 'sakit',
                        label: 'Sakit',
                        subtitle: 'Surat Dokter',
                        icon: Icons.local_hospital_outlined,
                        color: const Color(0xFFEF4444),
                        isSelected: _teacherAttendanceStatus == 'sakit',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                // Absence notification banner & multi-schedule toggle
                if (_teacherAttendanceStatus != 'hadir') ...[
                  Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: _teacherAttendanceStatus == 'sakit'
                          ? Colors.red.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _teacherAttendanceStatus == 'sakit'
                            ? Colors.red.shade200
                            : Colors.amber.shade200,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _teacherAttendanceStatus == 'sakit'
                              ? Icons.info_outline_rounded
                              : Icons.mark_email_read_outlined,
                          color: _teacherAttendanceStatus == 'sakit'
                              ? Colors.red.shade700
                              : Colors.amber.shade800,
                          size: 22.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _teacherAttendanceStatus == 'sakit'
                                    ? 'Keterangan Sakit Guru'
                                    : 'Keterangan Izin Guru',
                                style: GoogleFonts.hankenGrotesk(
                                  fontWeight: FontWeight.bold,
                                  color: _teacherAttendanceStatus == 'sakit'
                                      ? Colors.red.shade900
                                      : Colors.amber.shade900,
                                  fontSize: 13.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                _teacherAttendanceStatus == 'sakit'
                                    ? 'Anda tidak perlu mengisi materi atau absensi siswa. Cukup unggah foto Surat Keterangan Dokter di bawah.'
                                    : 'Anda tidak perlu mengisi materi atau absensi siswa. Cukup unggah foto Surat Izin / Dispensasi di bawah.',
                                style: GoogleFonts.hankenGrotesk(
                                  color: _teacherAttendanceStatus == 'sakit'
                                      ? Colors.red.shade800
                                      : Colors.amber.shade900,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (availableSchedules.length > 1) ...[
                    SizedBox(height: 10.h),
                    Builder(
                      builder: (context) {
                        final isDark = Theme.of(context).brightness == Brightness.dark;
                        return Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Theme.of(context).colorScheme.surfaceContainerHighest
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10.r),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: _applyToAllSchedulesToday,
                            onChanged: (val) {
                              setState(() {
                                _applyToAllSchedulesToday = val ?? false;
                              });
                            },
                            activeColor: const Color(0xFF2563EB),
                            title: Text(
                              'Terapkan surat ini untuk semua jadwal hari ini (${availableSchedules.length} jadwal)',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF1E40AF),
                              ),
                            ),
                            subtitle: Text(
                              'Foto surat yang sama akan otomatis diterapkan ke semua jam mengajar Anda hari ini.',
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 11.sp,
                                color: isDark ? Colors.grey[300] : const Color(0xFF3B82F6),
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          ),
                        );
                      }
                    ),
                  ],
                  SizedBox(height: 16.h),
                ],

                // Normal Teaching Inputs (Only when hadir)
                if (_teacherAttendanceStatus == 'hadir') ...[
                  // Materi Pembelajaran (Required)
                  Text(
                    'Materi Pembelajaran *',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextFormField(
                    controller: _materialController,
                    maxLines: 4,
                    validator: (value) {
                      if (_teacherAttendanceStatus == 'hadir' && (value == null || value.trim().isEmpty)) {
                        return 'Materi pembelajaran tidak boleh kosong';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      hintText:
                          'Jelaskan secara ringkas materi yang diajarkan hari ini...',
                    ),
                  ),
                  SizedBox(height: 20.h),

                  // Absensi Siswa
                  Text(
                    'Absensi Siswa (Daftar Kelas)',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
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

                      final isDark = Theme.of(context).brightness == Brightness.dark;

                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSummaryItem('Total', '$totalStudents', Theme.of(context).colorScheme.onSurface),
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
                  Builder(builder: (context) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return Container(
                      constraints: BoxConstraints(maxHeight: 280.h),
                      decoration: BoxDecoration(
                        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: masterProvider.students.isEmpty
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.w),
                                child: Text(
                                  'Tidak ada siswa terdaftar di kelas ini',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.all(10.w),
                              itemCount: masterProvider.students.length,
                              separatorBuilder: (context, _) => Divider(
                                height: 8,
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              ),
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
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (student.nis != null && student.nis!.isNotEmpty)
                                              Text(
                                                'NIS: ${student.nis}',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 10.sp,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                          _buildStatusToggle(context, 'H', status == 'H', const Color(0xFF10B981), () {
                                            setState(() {
                                              _studentAttendance[student.id] = 'H';
                                            });
                                          }),
                                          SizedBox(width: 4.w),
                                          _buildStatusToggle(context, 'S', status == 'S', const Color(0xFF2563EB), () {
                                            setState(() {
                                              _studentAttendance[student.id] = 'S';
                                            });
                                          }),
                                          SizedBox(width: 4.w),
                                          _buildStatusToggle(context, 'I', status == 'I', const Color(0xFFF59E0B), () {
                                            setState(() {
                                              _studentAttendance[student.id] = 'I';
                                            });
                                          }),
                                          SizedBox(width: 4.w),
                                          _buildStatusToggle(context, 'A', status == 'A', Colors.red, () {
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
                    );
                  }),
                  SizedBox(height: 24.h),
                ],

                // Catatan
                Text(
                  _teacherAttendanceStatus == 'hadir'
                      ? 'Catatan Pembelajaran'
                      : 'Keterangan Tambahan (Opsional)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: _teacherAttendanceStatus == 'hadir'
                        ? 'Catatan tambahan seperti siswa yang tidak kondusif, kendala sarana, dll (Opsional)...'
                        : 'Tuliskan alasan sakit / izin atau catatan untuk admin/kepala sekolah...',
                  ),
                ),
                SizedBox(height: 20.h),

                // Lampiran Jurnal / Lampiran Surat
                Row(
                  children: [
                    Text(
                      _teacherAttendanceStatus == 'hadir'
                          ? 'Lampiran Foto Kegiatan'
                          : 'Foto Surat Keterangan / Izin',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      ' * (Wajib min. 1)',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  _teacherAttendanceStatus == 'hadir'
                      ? 'Tambahkan foto bukti kegiatan mengajar (1 - 3 foto)'
                      : 'Lampirkan foto surat dokter / surat izin resmi (1 - 3 foto)',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 10.h),
                Builder(builder: (context) {
                  final totalSlots = _existingImageUrls.length + _imageBytesList.length;
                  final canAdd = totalSlots < _maxImages;
                  final isDark = Theme.of(context).brightness == Brightness.dark;

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
                          onTap: _showImageSourceDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 80.w,
                            height: 80.w,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _teacherAttendanceStatus == 'hadir'
                                      ? Icons.add_a_photo_outlined
                                      : Icons.upload_file_outlined,
                                  size: 22.r,
                                  color: const Color(0xFF2563EB),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  _teacherAttendanceStatus == 'hadir'
                                      ? 'Tambah\nFoto'
                                      : 'Unggah\nSurat',
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
                  style: _teacherAttendanceStatus != 'hadir'
                      ? ElevatedButton.styleFrom(
                          backgroundColor: _teacherAttendanceStatus == 'sakit'
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                        )
                      : null,
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
                          _isEditing
                              ? 'Kirim Revisi Jurnal'
                              : (_teacherAttendanceStatus == 'sakit'
                                  ? 'Kirim Surat Keterangan Sakit'
                                  : (_teacherAttendanceStatus == 'izin'
                                      ? 'Kirim Surat Izin'
                                      : 'Simpan Jurnal')),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTypeOption(
    BuildContext context, {
    required String id,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        setState(() {
          _teacherAttendanceStatus = id;
        });
      },
      borderRadius: BorderRadius.circular(12.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22.sp,
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13.sp,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 10.sp,
                color: isSelected ? color.withValues(alpha: 0.9) : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
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
    BuildContext context,
    String label,
    bool isSelected,
    Color activeColor,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 28.w,
        height: 28.w,
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}
