import '../core/utils/helper.dart';

class ScheduleModel {
  final String id;
  final String periodId;
  final DateTime date;
  final int teachingHour; // Links to teaching hour number
  final String classId;
  final String subjectId;
  final String teacherId;
  final String? note;
  final bool isActive;
  final String? schoolId;

  ScheduleModel({
    required this.id,
    required this.periodId,
    required this.date,
    required this.teachingHour,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    this.note,
    required this.isActive,
    this.schoolId,
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    final rawDate = json['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    }

    int teachingHour = 1;
    final rawHour = json['teaching_hour'] ?? json['teachingHour'];
    if (rawHour is int) {
      teachingHour = rawHour;
    } else if (rawHour != null) {
      teachingHour = int.tryParse(rawHour.toString()) ?? 1;
    }

    bool isActive = true;
    final rawActive = json['is_active'] ?? json['isActive'];
    if (rawActive is bool) {
      isActive = rawActive;
    } else if (rawActive is int) {
      isActive = rawActive == 1;
    } else if (rawActive != null) {
      final strActive = rawActive.toString().trim().toLowerCase();
      isActive = strActive == 'true' || strActive == '1';
    }

    return ScheduleModel(
      id: json['id']?.toString() ?? '',
      periodId: json['period_id']?.toString() ?? json['periodId']?.toString() ?? '',
      date: parsedDate,
      teachingHour: teachingHour,
      classId: json['class_id']?.toString() ?? json['classId']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? json['subjectId']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? json['teacherId']?.toString() ?? '',
      note: json['note']?.toString(),
      isActive: isActive,
      schoolId: AppHelper.parseSingleCleanSchoolId(json['school_id']),
    );
  }


  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'period_id': periodId,
      'date': date.toIso8601String(),
      'teaching_hour': teachingHour,
      'class_id': classId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'note': note,
      'is_active': isActive,
    };
    if (schoolId != null && schoolId!.isNotEmpty) {
      map['school_id'] = schoolId;
    }
    return map;
  }

  ScheduleModel copyWith({
    String? id,
    String? periodId,
    DateTime? date,
    int? teachingHour,
    String? classId,
    String? subjectId,
    String? teacherId,
    String? note,
    bool? isActive,
    String? schoolId,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      date: date ?? this.date,
      teachingHour: teachingHour ?? this.teachingHour,
      classId: classId ?? this.classId,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      schoolId: schoolId ?? this.schoolId,
    );
  }
}
