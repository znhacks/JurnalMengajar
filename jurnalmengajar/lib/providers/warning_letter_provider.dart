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

  Future<void> loadAllWarningLetters([String? schoolId]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _warningLetters = await warningLetterRepository.getAll(schoolId);
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

    // Group schedules by teacherId to correctly support multi-teacher and single-teacher contexts
    final Map<String, List<ScheduleModel>> schedulesByTeacher = {};
    for (final s in schedules) {
      if (s.isActive) {
        schedulesByTeacher.putIfAbsent(s.teacherId, () => []).add(s);
      }
    }

    for (final teacherEntry in schedulesByTeacher.entries) {
      final teacherId = teacherEntry.key;
      final teacherSchedules = teacherEntry.value;
      if (teacherSchedules.isEmpty) continue;

      List<WarningLetterModel> existingWarnings = [];
      try {
        existingWarnings = await warningLetterRepository.getByTeacherId(teacherId);
      } catch (_) {
        // If error loading existing, continue with empty list
      }

      // Group teacher's active schedules using groupDailySchedules
      final groupedSchedules = groupDailySchedules(teacherSchedules);

      // Map groups by date key (yyyy-MM-dd)
      final Map<String, List<GroupedDailySchedule>> groupsByDate = {};
      for (final group in groupedSchedules) {
        final dateKey = '${group.date.year}-${group.date.month.toString().padLeft(2, '0')}-${group.date.day.toString().padLeft(2, '0')}';
        groupsByDate.putIfAbsent(dateKey, () => []).add(group);
      }

      // Process each date for this teacher
      for (final entry in groupsByDate.entries) {
        final dateGroups = entry.value;
        if (dateGroups.isEmpty) continue;

        final firstGroup = dateGroups.first;
        final schedOnly = DateTime(firstGroup.date.year, firstGroup.date.month, firstGroup.date.day);
        final diffDays = todayOnly.difference(schedOnly).inDays;
        final dateStr = AppHelper.formatDateShort(firstGroup.date);

        // Find if warning for this date already exists for this teacher
        final existingWarningIndex = existingWarnings.indexWhere((w) => w.reason.contains(dateStr));
        final WarningLetterModel? existingWarning = existingWarningIndex != -1 ? existingWarnings[existingWarningIndex] : null;

        if (diffDays > maxDays) {
          // Collect daily schedule groups on this day that do NOT have a journal
          final List<GroupedDailySchedule> missingJournalGroups = [];
          for (final group in dateGroups) {
            final hasJournal = journals.any((j) => group.scheduleIds.contains(j.scheduleId));
            if (!hasJournal) {
              missingJournalGroups.add(group);
            }
          }

          if (missingJournalGroups.isNotEmpty) {
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
                } catch (_) {}
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
              } catch (_) {}
            }
          } else {
            // All journals on this day are filled, delete warning if it exists
            if (existingWarning != null) {
              try {
                await warningLetterRepository.delete(existingWarning.id);
              } catch (_) {}
            }
          }
        } else {
          // Not late, delete warning if it exists
          if (existingWarning != null) {
            try {
              await warningLetterRepository.delete(existingWarning.id);
            } catch (_) {}
          }
        }
      }
    }
  }

  Future<void> confirmAllWarnings(String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final unreadWarnings = _warningLetters.where((w) => w.status == 'unread' && w.teacherId == teacherId).toList();
      for (final w in unreadWarnings) {
        await warningLetterRepository.markAsRead(w.id);
        final index = _warningLetters.indexWhere((item) => item.id == w.id);
        if (index != -1) {
          _warningLetters[index] = _warningLetters[index].copyWith(status: 'read');
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteConfirmedWarnings(String teacherId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final confirmedWarnings = _warningLetters.where((w) => w.status == 'read' && w.teacherId == teacherId).toList();
      for (final w in confirmedWarnings) {
        await warningLetterRepository.delete(w.id);
      }
      _warningLetters.removeWhere((w) => w.status == 'read' && w.teacherId == teacherId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
