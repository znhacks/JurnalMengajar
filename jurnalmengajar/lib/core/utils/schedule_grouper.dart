import '../../models/schedule_model.dart';

class GroupedMasterSchedule {
  final String periodId;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String? note;
  final bool isActive;
  final List<int> teachingHours;
  final DateTime startDate;
  final DateTime endDate;
  final List<int> weekdays;
  final List<String> scheduleIds;

  GroupedMasterSchedule({
    required this.periodId,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    this.note,
    required this.isActive,
    required this.teachingHours,
    required this.startDate,
    required this.endDate,
    required this.weekdays,
    required this.scheduleIds,
  });
}

class GroupedDailySchedule {
  final DateTime date;
  final String periodId;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String? note;
  final bool isActive;
  final List<int> teachingHours;
  final List<String> scheduleIds;
  final ScheduleModel primarySchedule;

  GroupedDailySchedule({
    required this.date,
    required this.periodId,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    this.note,
    required this.isActive,
    required this.teachingHours,
    required this.scheduleIds,
    required this.primarySchedule,
  });
}

List<GroupedMasterSchedule> groupMasterSchedules(List<ScheduleModel> flatSchedules) {
  final Map<String, List<ScheduleModel>> groups = {};
  for (final s in flatSchedules) {
    final noteKey = (s.note == null || s.note!.trim().isEmpty) ? "" : s.note!.trim();
    final key = '${s.classId}_${s.subjectId}_${s.teacherId}_${s.periodId}_${s.isActive}_$noteKey';
    groups.putIfAbsent(key, () => []).add(s);
  }

  final List<GroupedMasterSchedule> result = [];
  for (final entry in groups.entries) {
    final list = entry.value;
    if (list.isEmpty) continue;

    DateTime minDate = list[0].date;
    DateTime maxDate = list[0].date;
    final Set<int> weekdays = {};
    final Set<int> hours = {};
    final List<String> ids = [];

    for (final s in list) {
      if (s.date.isBefore(minDate)) minDate = s.date;
      if (s.date.isAfter(maxDate)) maxDate = s.date;
      weekdays.add(s.date.weekday);
      hours.add(s.teachingHour);
      ids.add(s.id);
    }

    result.add(
      GroupedMasterSchedule(
        periodId: list[0].periodId,
        classId: list[0].classId,
        subjectId: list[0].subjectId,
        teacherId: list[0].teacherId,
        note: list[0].note,
        isActive: list[0].isActive,
        teachingHours: hours.toList()..sort(),
        startDate: minDate,
        endDate: maxDate,
        weekdays: weekdays.toList()..sort(),
        scheduleIds: ids,
      ),
    );
  }

  result.sort((a, b) {
    final classCompare = a.classId.compareTo(b.classId);
    if (classCompare != 0) return classCompare;
    final hourA = a.teachingHours.isNotEmpty ? a.teachingHours.first : 0;
    final hourB = b.teachingHours.isNotEmpty ? b.teachingHours.first : 0;
    final hourCompare = hourA.compareTo(hourB);
    if (hourCompare != 0) return hourCompare;
    return a.startDate.compareTo(b.startDate);
  });

  return result;
}

List<GroupedDailySchedule> groupDailySchedules(List<ScheduleModel> flatSchedules) {
  final Map<String, List<ScheduleModel>> groups = {};
  for (final s in flatSchedules) {
    final noteKey = (s.note == null || s.note!.trim().isEmpty) ? "" : s.note!.trim();
    final dateStr = '${s.date.year}-${s.date.month}-${s.date.day}';
    final key = '${dateStr}_${s.classId}_${s.subjectId}_${s.teacherId}_${s.periodId}_${s.isActive}_$noteKey';
    groups.putIfAbsent(key, () => []).add(s);
  }

  final List<GroupedDailySchedule> result = [];
  for (final entry in groups.entries) {
    final list = entry.value;
    if (list.isEmpty) continue;

    list.sort((a, b) => a.teachingHour.compareTo(b.teachingHour));

    final List<int> hours = list.map((s) => s.teachingHour).toList();
    final List<String> ids = list.map((s) => s.id).toList();

    result.add(
      GroupedDailySchedule(
        date: list[0].date,
        periodId: list[0].periodId,
        classId: list[0].classId,
        subjectId: list[0].subjectId,
        teacherId: list[0].teacherId,
        note: list[0].note,
        isActive: list[0].isActive,
        teachingHours: hours,
        scheduleIds: ids,
        primarySchedule: list[0],
      ),
    );
  }

  result.sort((a, b) {
    final dayCompare = a.date.weekday.compareTo(b.date.weekday);
    if (dayCompare != 0) return dayCompare;
    final hourA = a.teachingHours.isNotEmpty ? a.teachingHours.first : 0;
    final hourB = b.teachingHours.isNotEmpty ? b.teachingHours.first : 0;
    return hourA.compareTo(hourB);
  });

  return result;
}
