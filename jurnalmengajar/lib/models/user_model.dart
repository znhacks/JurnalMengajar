class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'guru' | 'admin' | 'pending_guru' | 'superadmin'
  final String? photoUrl;
  final String? phoneNumber;
  final String? position;
  final String? address;
  final String? schoolName; // e.g. 'SMKN 11 Malang'
  final String? schoolId;
  final List<String> schoolIds;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.photoUrl,
    this.phoneNumber,
    this.position,
    this.address,
    this.schoolName,
    this.schoolId,
    this.schoolIds = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedSchoolIds = [];
    String? rawSchoolId = json['school_id']?.toString().trim();
    if (json['school_ids'] != null) {
      if (json['school_ids'] is List) {
        parsedSchoolIds = (json['school_ids'] as List).map((e) => e.toString().trim()).toList();
      } else if (json['school_ids'] is String) {
        parsedSchoolIds = (json['school_ids'] as String).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    } else if (rawSchoolId != null && rawSchoolId.isNotEmpty) {
      if (rawSchoolId.contains(',')) {
        parsedSchoolIds = rawSchoolId.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } else {
        parsedSchoolIds = [rawSchoolId];
      }
    }

    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? json['fullName'] as String,
      role: json['role'] as String,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      phoneNumber: json['phone'] as String? ?? json['phoneNumber'] as String?,
      position: json['position'] as String?,
      address: json['address'] as String?,
      schoolName: json['school_name'] as String? ?? json['schoolName'] as String?,
      schoolId: rawSchoolId,
      schoolIds: parsedSchoolIds,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'photo_url': photoUrl,
      'phone': phoneNumber,
      'position': position,
      'address': address,
      'school_name': schoolName,
      'school_ids': schoolIds,
    };
    if (schoolId != null && schoolId!.isNotEmpty) {
      map['school_id'] = schoolId;
    }
    return map;
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? photoUrl,
    String? phoneNumber,
    String? position,
    String? address,
    String? schoolName,
    String? schoolId,
    List<String>? schoolIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      position: position ?? this.position,
      address: address ?? this.address,
      schoolName: schoolName ?? this.schoolName,
      schoolId: schoolId ?? this.schoolId,
      schoolIds: schoolIds ?? this.schoolIds,
    );
  }
}
