class ClassModel {
  final String id;
  final String periodId;
  final String name;
  final int studentCount;
  final String? schoolId;

  ClassModel({
    required this.id,
    required this.periodId,
    required this.name,
    required this.studentCount,
    this.schoolId,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      periodId: json['period_id'] as String? ?? json['periodId'] as String,
      name: json['name'] as String,
      studentCount: json['student_count'] as int? ?? json['studentCount'] as int,
      schoolId: json['school_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'period_id': periodId,
      'name': name,
      'student_count': studentCount,
    };
    if (schoolId != null && schoolId!.isNotEmpty) {
      map['school_id'] = schoolId;
    }
    return map;
  }

  ClassModel copyWith({
    String? id,
    String? periodId,
    String? name,
    int? studentCount,
    String? schoolId,
  }) {
    return ClassModel(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      name: name ?? this.name,
      studentCount: studentCount ?? this.studentCount,
      schoolId: schoolId ?? this.schoolId,
    );
  }
}
