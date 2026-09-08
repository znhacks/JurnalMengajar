import '../core/utils/helper.dart';

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
    int count = 0;
    final rawCount = json['student_count'] ?? json['studentCount'];
    if (rawCount is int) {
      count = rawCount;
    } else if (rawCount != null) {
      count = int.tryParse(rawCount.toString()) ?? 0;
    }

    return ClassModel(
      id: json['id']?.toString() ?? '',
      periodId: json['period_id']?.toString() ?? json['periodId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      studentCount: count,
      schoolId: AppHelper.parseSingleCleanSchoolId(json['school_id']),
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
