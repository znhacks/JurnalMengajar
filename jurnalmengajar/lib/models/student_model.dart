class StudentModel {
  final String id;
  final String classId;
  final String name;
  final String? nis;
  final String? gender; // 'L' (Laki-laki) or 'P' (Perempuan)
  final String? parentPhoneNumber;

  StudentModel({
    required this.id,
    required this.classId,
    required this.name,
    this.nis,
    this.gender,
    this.parentPhoneNumber,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      classId: json['class_id'] as String? ?? json['classId'] as String,
      name: json['name'] as String,
      nis: json['nis'] as String?,
      gender: json['gender'] as String?,
      parentPhoneNumber: json['parent_phone_number'] as String? ?? json['parent_phone'] as String? ?? json['parentPhoneNumber'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'class_id': classId,
      'name': name,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (nis != null) {
      map['nis'] = nis;
    }
    if (gender != null) {
      map['gender'] = gender;
    }
    if (parentPhoneNumber != null) {
      map['parent_phone_number'] = parentPhoneNumber;
    }
    return map;
  }

  StudentModel copyWith({
    String? id,
    String? classId,
    String? name,
    String? nis,
    String? gender,
    String? parentPhoneNumber,
  }) {
    return StudentModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      name: name ?? this.name,
      nis: nis ?? this.nis,
      gender: gender ?? this.gender,
      parentPhoneNumber: parentPhoneNumber ?? this.parentPhoneNumber,
    );
  }
}
