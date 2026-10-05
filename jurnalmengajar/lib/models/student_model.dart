import '../core/utils/helper.dart';

class StudentModel {
  final String id;
  final String classId;
  final String name;
  final String? nis;
  final String? gender; // 'L' (Laki-laki) or 'P' (Perempuan)
  final String? parentPhoneNumber;
  final String? schoolId;
  final String status; // 'aktif', 'naik', 'tidak_naik', 'lulus', 'pindah', 'tetap'
  final String? enrollmentStatus; // Status specifically in the context of the queried class

  StudentModel({
    required this.id,
    required this.classId,
    required this.name,
    this.nis,
    this.gender,
    this.parentPhoneNumber,
    this.schoolId,
    this.status = 'aktif',
    this.enrollmentStatus,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? json['classId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nis: json['nis']?.toString(),
      gender: json['gender']?.toString(),
      parentPhoneNumber: json['parent_phone_number']?.toString() ?? json['parent_phone']?.toString() ?? json['parentPhoneNumber']?.toString(),
      schoolId: AppHelper.parseSingleCleanSchoolId(json['school_id']),
      status: json['status']?.toString() ?? 'aktif',
      enrollmentStatus: json['enrollment_status']?.toString() ?? json['history_status']?.toString(),
    );
  }


  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'class_id': classId,
      'name': name,
      'status': status,
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
    if (schoolId != null && schoolId!.isNotEmpty) {
      map['school_id'] = schoolId;
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
    String? schoolId,
    String? status,
    String? enrollmentStatus,
  }) {
    return StudentModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      name: name ?? this.name,
      nis: nis ?? this.nis,
      gender: gender ?? this.gender,
      parentPhoneNumber: parentPhoneNumber ?? this.parentPhoneNumber,
      schoolId: schoolId ?? this.schoolId,
      status: status ?? this.status,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
    );
  }
}
