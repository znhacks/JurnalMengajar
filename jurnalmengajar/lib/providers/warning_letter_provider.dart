import 'package:flutter/material.dart';
import '../models/warning_letter_model.dart';
import '../models/schedule_model.dart';
import '../models/journal_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';
import '../repositories/warning_letter_repository.dart';
import 'master_data_provider.dart';
import '../core/utils/helper.dart';

class WarningLetterProvider with ChangeNotifier {
  final WarningLetterRepository warningLetterRepository;

  List<WarningLetterModel> _warningLetters = [];
  bool _isLoading = false;
  String? _errorMessage;

  WarningLetterProvider({required this.warningLetterRepository});

  List<WarningLetterModel> get warningLetters => _warningLetters;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadAllWarningLetters() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _warningLetters = await warningLetterRepository.getAll();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTeacherWarningLetters(String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _warningLetters = await warningLetterRepository.getByTeacherId(teacherId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markWarningLetterAsRead(String id) async {
    try {
      await warningLetterRepository.markAsRead(id);
      final index = _warningLetters.indexWhere((w) => w.id == id);
      if (index != -1) {
        _warningLetters[index] = _warningLetters[index].copyWith(status: 'read');
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> checkAndIssueWarnings({
    required List<ScheduleModel> schedules,
    required List<JournalModel> journals,
    required int maxDays,
    required MasterDataProvider masterProvider,
  }) async {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    for (final schedule in schedules) {
      if (!schedule.isActive) continue;

      final schedOnly = DateTime(schedule.date.year, schedule.date.month, schedule.date.day);
      final diffDays = todayOnly.difference(schedOnly).inDays;

      if (diffDays > maxDays) {
        final hasJournal = journals.any((j) => j.scheduleId == schedule.id);
        if (!hasJournal) {
          final cls = masterProvider.classes.firstWhere(
            (c) => c.id == schedule.classId,
            orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
          );
          final subject = masterProvider.subjects.firstWhere(
            (s) => s.id == schedule.subjectId,
            orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
          );
          final dateStr = AppHelper.formatDateShort(schedule.date);

          final reason = 'Terlambat mengisi jurnal mengajar untuk kelas ${cls.name} pada tanggal $dateStr (Mata Pelajaran: ${subject.name}, Jam ke-${schedule.teachingHour}).';

          final newWarning = WarningLetterModel(
            id: '',
            teacherId: schedule.teacherId,
            scheduleId: schedule.id,
            issuedAt: DateTime.now(),
            reason: reason,
            status: 'unread',
          );

          try {
            await warningLetterRepository.create(newWarning);
          } catch (_) {
            // Ignore errors (like duplicate warning constraint)
          }
        }
      }
    }
  }
}
