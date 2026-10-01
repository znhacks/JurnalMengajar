class LeaveSubstituteItem {
  final String scheduleId;
  final DateTime date;
  final int teachingHour;
  final String classId;
  final String subjectId;
  final String substituteTeacherId;
  final String? substituteTeacherName;

  LeaveSubstituteItem({
    required this.scheduleId,
    required this.date,
    required this.teachingHour,
    required this.classId,
    required this.subjectId,
    required this.substituteTeacherId,
    this.substituteTeacherName,
  });

  factory LeaveSubstituteItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    final rawDate = json['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    }
    return LeaveSubstituteItem(
      scheduleId: json['schedule_id']?.toString() ?? '',
      date: parsedDate,
      teachingHour: int.tryParse(json['teaching_hour']?.toString() ?? '1') ?? 1,
      classId: json['class_id']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? '',
      substituteTeacherId: json['substitute_teacher_id']?.toString() ?? '',
      substituteTeacherName: json['substitute_teacher_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schedule_id': scheduleId,
      'date': date.toIso8601String().split('T').first,
      'teaching_hour': teachingHour,
      'class_id': classId,
      'subject_id': subjectId,
      'substitute_teacher_id': substituteTeacherId,
      'substitute_teacher_name': substituteTeacherName,
    };
  }
}

class TeacherLeaveModel {
  final String id;
  final String schoolId;
  final String teacherId;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
  final String status;
  final List<LeaveSubstituteItem> substitutes;
  final String? createdBy;
  final DateTime? createdAt;

  TeacherLeaveModel({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    required this.startDate,
    required this.endDate,
    this.reason,
    this.status = 'active',
    this.substitutes = const [],
    this.createdBy,
    this.createdAt,
  });

  factory TeacherLeaveModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedStartDate = DateTime.now();
    final rawStart = json['start_date'];
    if (rawStart is String) {
      parsedStartDate = DateTime.tryParse(rawStart) ?? DateTime.now();
    } else if (rawStart is DateTime) {
      parsedStartDate = rawStart;
    }

    DateTime parsedEndDate = DateTime.now();
    final rawEnd = json['end_date'];
    if (rawEnd is String) {
      parsedEndDate = DateTime.tryParse(rawEnd) ?? DateTime.now();
    } else if (rawEnd is DateTime) {
      parsedEndDate = rawEnd;
    }

    List<LeaveSubstituteItem> subs = [];
    final rawSubs = json['substitutes'];
    if (rawSubs is List) {
      subs = rawSubs
          .whereType<Map>()
          .map((m) => LeaveSubstituteItem.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    }

    return TeacherLeaveModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? '',
      startDate: parsedStartDate,
      endDate: parsedEndDate,
      reason: json['reason']?.toString(),
      status: json['status']?.toString() ?? 'active',
      substitutes: subs,
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'teacher_id': teacherId,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'reason': reason,
      'status': status,
      'substitutes': substitutes.map((s) => s.toJson()).toList(),
      'created_by': createdBy,
    };
  }

  TeacherLeaveModel copyWith({
    String? id,
    String? schoolId,
    String? teacherId,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    String? status,
    List<LeaveSubstituteItem>? substitutes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return TeacherLeaveModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      teacherId: teacherId ?? this.teacherId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      substitutes: substitutes ?? this.substitutes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
