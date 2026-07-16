import 'package:flutter/material.dart';
import '../models/warning_letter_model.dart';
import '../models/schedule_model.dart';
import '../models/journal_model.dart';
import '../models/class_model.dart';
import '../models/subject_model.dart';
import '../repositories/warning_letter_repository.dart';
import 'master_data_provider.dart';
import '../core/utils/helper.dart';
import '../core/utils/schedule_grouper.dart';

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

    // 1. Group active schedules using groupDailySchedules
    final activeSchedules = schedules.where((s) => s.isActive).toList();
    final groupedSchedules = groupDailySchedules(activeSchedules);

    // 2. Map groups by date key (yyyy-MM-dd)
    final Map<String, List<GroupedDailySchedule>> groupsByDate = {};
    for (final group in groupedSchedules) {
      final dateKey = '${group.date.year}-${group.date.month}-${group.date.day}';
      groupsByDate.putIfAbsent(dateKey, () => []).add(group);
    }

    // 3. Process each date
    for (final entry in groupsByDate.entries) {
      final dateGroups = entry.value;
      if (dateGroups.isEmpty) continue;

      final firstGroup = dateGroups.first;
      final schedOnly = DateTime(firstGroup.date.year, firstGroup.date.month, firstGroup.date.day);
      final diffDays = todayOnly.difference(schedOnly).inDays;
      final dateStr = AppHelper.formatDateShort(firstGroup.date);

      // Find if warning for this date already exists
      final existingWarningIndex = existingWarnings.indexWhere((w) => w.reason.contains(dateStr));
      final WarningLetterModel? existingWarning = existingWarningIndex != -1 ? existingWarnings[existingWarningIndex] : null;

      if (diffDays > maxDays) {
        // Collect daily schedule groups on this day that do NOT have a journal
        final List<GroupedDailySchedule> missingJournalGroups = [];
        for (final group in dateGroups) {
          // A group has a journal if ANY of its scheduleIds has a journal in journals
          final hasJournal = journals.any((j) => group.scheduleIds.contains(j.scheduleId));
          if (!hasJournal) {
            missingJournalGroups.add(group);
          }
        }

        if (missingJournalGroups.isNotEmpty) {
          // Format classes and hours
          final Map<String, List<int>> classToHours = {};
          final Map<String, String> classIdToName = {};
          final Map<String, Set<String>> classToSubjects = {};

          for (final group in missingJournalGroups) {
            final cls = masterProvider.classes.firstWhere(
              (c) => c.id == group.classId,
              orElse: () => ClassModel(id: '', name: 'Kelas--', periodId: '', studentCount: 0),
            );
            final subject = masterProvider.subjects.firstWhere(
              (sub) => sub.id == group.subjectId,
              orElse: () => SubjectModel(id: '', name: 'Mapel--', isActive: false),
            );

            classIdToName[group.classId] = cls.name;
            classToHours.putIfAbsent(group.classId, () => []).addAll(group.teachingHours);
            classToSubjects.putIfAbsent(group.classId, () => {}).add(subject.name);
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

          if (existingWarning != null) {
            if (existingWarning.reason != reason) {
              final updatedWarning = existingWarning.copyWith(reason: reason);
              try {
                await warningLetterRepository.update(updatedWarning);
              } catch (_) {
                // Ignore errors
              }
            }
          } else {
            final representativeGroup = missingJournalGroups.first;
            final newWarning = WarningLetterModel(
              id: '',
              teacherId: representativeGroup.teacherId,
              scheduleId: representativeGroup.scheduleIds.first,
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
        } else {
          // All journals on this day are filled, delete warning if it exists
          if (existingWarning != null) {
            try {
              await warningLetterRepository.delete(existingWarning.id);
            } catch (_) {
              // Ignore errors
            }
          }
        }
      } else {
        // Not late, delete warning if it exists
        if (existingWarning != null) {
          try {
            await warningLetterRepository.delete(existingWarning.id);
          } catch (_) {
            // Ignore errors
          }
        }
      }
    }
  }
}
