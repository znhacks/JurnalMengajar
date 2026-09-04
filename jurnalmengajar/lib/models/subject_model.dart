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
    return SubjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
      schoolId: json['school_id'] as String?,
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
