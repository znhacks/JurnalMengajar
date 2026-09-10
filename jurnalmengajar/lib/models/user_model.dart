import '../core/utils/helper.dart';

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
  final String? status; // 'active' | 'pending' | 'inactive' | 'requested_exit'
  final String? membershipRole; // role assigned within active school membership

  bool get isPending =>
      (status != null && status!.toLowerCase() == 'pending') ||
      role.toLowerCase() == 'pending_guru';

  bool get isActive =>
      !isPending &&
      (status == null || status!.toLowerCase() == 'active') &&
      role.toLowerCase() != 'pending_guru' &&
      role.toLowerCase() != 'pending_admin';

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
    this.status,
    this.membershipRole,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final parsedFromSchoolId = AppHelper.parseAndCleanSchoolIds(json['school_id']);
    final parsedFromSchoolIds = AppHelper.parseAndCleanSchoolIds(json['school_ids']);
    final allSchoolIds = <String>{...parsedFromSchoolId, ...parsedFromSchoolIds}.toList();
    final cleanSchoolId = AppHelper.parseSingleCleanSchoolId(json['school_id']) ??
        (allSchoolIds.isNotEmpty ? allSchoolIds.first : null);

    String fullName = '';
    final rawFullName = json['full_name']?.toString().trim();
    final rawName = json['fullName']?.toString().trim() ?? json['name']?.toString().trim();
    if (rawFullName != null && rawFullName.isNotEmpty) {
      fullName = rawFullName;
    } else if (rawName != null && rawName.isNotEmpty) {
      fullName = rawName;
    } else {
      final rawEmail = json['email']?.toString().trim();
      fullName = (rawEmail != null && rawEmail.isNotEmpty) ? rawEmail : 'Pengguna';
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: fullName,
      role: json['role']?.toString() ?? 'guru',
      photoUrl: json['photo_url']?.toString() ?? json['photoUrl']?.toString(),
      phoneNumber: json['phone']?.toString() ?? json['phoneNumber']?.toString() ?? json['phone_number']?.toString(),
      position: json['position']?.toString(),
      address: json['address']?.toString(),
      schoolName: json['school_name']?.toString() ?? json['schoolName']?.toString(),
      schoolId: cleanSchoolId,
      schoolIds: allSchoolIds,
      status: json['status']?.toString() ?? json['membership_status']?.toString(),
      membershipRole: json['membership_role']?.toString() ?? json['membershipRole']?.toString(),
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

  Map<String, dynamic> toCacheJson() {
    final map = toJson();
    if (status != null && status!.isNotEmpty) {
      map['status'] = status;
    }
    if (membershipRole != null && membershipRole!.isNotEmpty) {
      map['membership_role'] = membershipRole;
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
    bool clearSchoolId = false,
    List<String>? schoolIds,
    String? status,
    String? membershipRole,
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
      schoolName: clearSchoolId ? null : (schoolName ?? this.schoolName),
      schoolId: clearSchoolId ? null : (schoolId ?? this.schoolId),
      schoolIds: schoolIds ?? this.schoolIds,
      status: status ?? this.status,
      membershipRole: membershipRole ?? this.membershipRole,
    );
  }
}
