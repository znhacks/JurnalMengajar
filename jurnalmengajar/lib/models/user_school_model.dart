import '../core/utils/helper.dart';

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
      final sMap = json['schools'] as Map;
      name = sMap['name']?.toString() ?? 'Sekolah';
      code = sMap['code']?.toString();
      logo = sMap['logo_url']?.toString() ?? sMap['logoUrl']?.toString();
    } else if (json['school_name'] != null) {
      name = json['school_name']?.toString() ?? 'Sekolah';
    }

    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(json['school_id']) ?? '';

    return UserSchoolModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      schoolId: cleanSchoolId,
      role: json['role']?.toString() ?? 'guru',
      schoolName: name,
      schoolCode: code,
      status: json['status']?.toString() ?? 'active',
      logoUrl: logo ?? json['logo_url']?.toString() ?? json['logoUrl']?.toString(),
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
