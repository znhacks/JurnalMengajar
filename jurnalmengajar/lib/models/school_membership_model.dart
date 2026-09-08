import '../core/utils/helper.dart';

class SchoolMembershipModel {
  final String id;
  final String userId;
  final String schoolId;
  final String schoolName;
  final String role; // 'admin' | 'guru' | 'superadmin'
  final DateTime? joinedAt;

  SchoolMembershipModel({
    required this.id,
    required this.userId,
    required this.schoolId,
    required this.schoolName,
    required this.role,
    this.joinedAt,
  });

  factory SchoolMembershipModel.fromJson(Map<String, dynamic> json) {
    final schoolData = json['schools'] as Map<String, dynamic>?;
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(json['school_id']) ?? '';
    return SchoolMembershipModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      schoolId: cleanSchoolId,
      schoolName: schoolData != null
          ? (schoolData['name']?.toString() ?? 'Sekolah')
          : (json['school_name']?.toString() ?? 'Sekolah'),
      role: json['role']?.toString() ?? 'guru',
      joinedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'school_id': schoolId,
      'role': role,
    };
  }
}
