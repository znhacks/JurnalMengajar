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
    if (schedules.isEmpty) return;

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final teacherId = schedules.first.teacherId;
    List<WarningLetterModel> existingWarnings = [];
    try {
      existingWarnings = await warningLetterRepository.getByTeacherId(teacherId);
    } catch (_) {
      // If error loading existing, we continue with empty list
    }

    // Group schedules by date
    final Map<String, List<ScheduleModel>> schedulesByDate = {};
    for (final s in schedules) {
      if (!s.isActive) continue;
      final dateKey = '${s.date.year}-${s.date.month}-${s.date.day}';
      schedulesByDate.putIfAbsent(dateKey, () => []).add(s);
    }

    for (final entry in schedulesByDate.entries) {
      final dateSchedules = entry.value;
      if (dateSchedules.isEmpty) continue;

      final firstSchedule = dateSchedules.first;
      final schedOnly = DateTime(firstSchedule.date.year, firstSchedule.date.month, firstSchedule.date.day);
      final diffDays = todayOnly.difference(schedOnly).inDays;

      if (diffDays > maxDays) {
        // Collect schedules on this day that do NOT have a journal
        final List<ScheduleModel> missingJournalSchedules = [];
        for (final s in dateSchedules) {
          final hasJournal = journals.any((j) => j.scheduleId == s.id);
          if (!hasJournal) {
            missingJournalSchedules.add(s);
          }
        }

        if (missingJournalSchedules.isNotEmpty) {
          final representativeSchedule = missingJournalSchedules.first;
          final dateStr = AppHelper.formatDateShort(representativeSchedule.date);

          // Check if warning for this date already exists
          final alreadyExists = existingWarnings.any((w) => w.reason.contains(dateStr));
          if (alreadyExists) continue;

          // Format classes and hours
          final Map<String, List<int>> classToHours = {};
          final Map<String, String> classIdToName = {};
          final Map<String, Set<String>> classToSubjects = {};

          for (final s in missingJournalSchedules) {
            final cls = masterProvider.classes.firstWhere(
              (c) => c.id == s.classId,
              orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
            );
            final subject = masterProvider.subjects.firstWhere(
              (sub) => sub.id == s.subjectId,
              orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
            );

            classIdToName[s.classId] = cls.name;
            classToHours.putIfAbsent(s.classId, () => []).add(s.teachingHour);
            classToSubjects.putIfAbsent(s.classId, () => {}).add(subject.name);
          }

          final List<String> detailStrings = [];
          classToHours.forEach((classId, hours) {
            final className = classIdToName[classId] ?? 'Kelas--';
            final sortedHours = hours..sort();
            final hoursStr = sortedHours.join(', ');
            final subjectsStr = classToSubjects[classId]?.join(', ') ?? 'Mapel--';
            detailStrings.add('$className (Mapel: $subjectsStr, Jam ke-$hoursStr)');
          });

          final details = detailStrings.join(' & ');
          final reason = 'Terlambat mengisi jurnal mengajar pada tanggal $dateStr untuk kelas: $details.';

          final newWarning = WarningLetterModel(
            id: '',
            teacherId: representativeSchedule.teacherId,
            scheduleId: representativeSchedule.id,
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
