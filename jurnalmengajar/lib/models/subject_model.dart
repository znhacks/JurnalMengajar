import '../core/utils/helper.dart';

class SubjectModel {
  final String id;
  final String name;
  final bool isActive;
  final String? schoolId;

  SubjectModel({
    required this.id,
    required this.name,
    required this.isActive,
    this.schoolId,
  });

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    bool active = true;
    final rawActive = json['is_active'] ?? json['isActive'];
    if (rawActive is bool) {
      active = rawActive;
    } else if (rawActive != null) {
      active = rawActive.toString().toLowerCase() == 'true' || rawActive == 1 || rawActive.toString() == '1';
    }

    return SubjectModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: active,
      schoolId: AppHelper.parseSingleCleanSchoolId(json['school_id']),
    );
  }


  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'is_active': isActive,
    };
    if (schoolId != null && schoolId!.isNotEmpty) {
      map['school_id'] = schoolId;
    }
    return map;
  }

  SubjectModel copyWith({
    String? id,
    String? name,
    bool? isActive,
    String? schoolId,
  }) {
    return SubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      schoolId: schoolId ?? this.schoolId,
    );
  }
}
