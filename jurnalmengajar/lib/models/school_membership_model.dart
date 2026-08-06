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
    return SchoolMembershipModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      schoolName: schoolData != null
          ? (schoolData['name'] as String? ?? 'Sekolah')
          : (json['school_name'] as String? ?? 'Sekolah'),
      role: json['role'] as String? ?? 'guru',
      joinedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
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
