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
  });

  factory ScheduleModel.fromJson(Map<String, dynamic> json) {
    return ScheduleModel(
      id: json['id'] as String,
      periodId: json['period_id'] as String? ?? json['periodId'] as String,
      date: json['date'] is String ? DateTime.parse(json['date'] as String) : json['date'] as DateTime,
      teachingHour: json['teaching_hour'] as int? ?? json['teachingHour'] as int,
      classId: json['class_id'] as String? ?? json['classId'] as String,
      subjectId: json['subject_id'] as String? ?? json['subjectId'] as String,
      teacherId: json['teacher_id'] as String? ?? json['teacherId'] as String,
      note: json['note'] as String?,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    );
  }
}
