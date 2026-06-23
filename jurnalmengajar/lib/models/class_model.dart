class ClassModel {
  final String id;
  final String periodId;
  final String name;
  final int studentCount;

  ClassModel({
    required this.id,
    required this.periodId,
    required this.name,
    required this.studentCount,
  });

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      periodId: json['period_id'] as String? ?? json['periodId'] as String,
      name: json['name'] as String,
      studentCount: json['student_count'] as int? ?? json['studentCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'period_id': periodId,
      'name': name,
      'student_count': studentCount,
    };
  }

  ClassModel copyWith({
    String? id,
    String? periodId,
    String? name,
    int? studentCount,
  }) {
    return ClassModel(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      name: name ?? this.name,
      studentCount: studentCount ?? this.studentCount,
    );
  }
}
