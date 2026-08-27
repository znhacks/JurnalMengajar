class UserSchoolModel {
  final String id;
  final String userId;
  final String schoolId;
  final String role; // 'guru' | 'admin' | 'tenant'
  final String schoolName;
  final String? schoolCode;
  final String? status; // 'active' | 'requested_exit'
  final String? logoUrl;

  UserSchoolModel({
    required this.id,
    required this.userId,
    required this.schoolId,
    required this.role,
    required this.schoolName,
    this.schoolCode,
    this.status,
    this.logoUrl,
  });

  factory UserSchoolModel.fromJson(Map<String, dynamic> json) {
    String name = 'Sekolah';
    String? code;
    String? logo;

    if (json['schools'] != null && json['schools'] is Map) {
      final sMap = json['schools'] as Map<String, dynamic>;
      name = sMap['name'] as String? ?? 'Sekolah';
      code = sMap['code'] as String?;
      logo = sMap['logo_url'] as String? ?? sMap['logoUrl'] as String?;
    } else if (json['school_name'] != null) {
      name = json['school_name'] as String;
    }

    return UserSchoolModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      role: json['role'] as String? ?? 'guru',
      schoolName: name,
      schoolCode: code,
      status: json['status'] as String? ?? 'active',
      logoUrl: logo ?? json['logo_url'] as String? ?? json['logoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'school_id': schoolId,
      'role': role,
      'school_name': schoolName,
      'school_code': schoolCode,
      'status': status,
      'logo_url': logoUrl,
    };
  }
}
