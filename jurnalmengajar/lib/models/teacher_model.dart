import '../core/constants/teacher_roles.dart';

class TeacherModel {
  final String id;
  final String name;
  final String position;
  final String address;
  final String phoneNumber;
  final String email;
  final String? photoUrl;
  final String? nip;
  final bool isDeleted;

  TeacherModel({
    required this.id,
    required this.name,
    required this.position,
    required this.address,
    required this.phoneNumber,
    required this.email,
    this.photoUrl,
    this.nip,
    this.isDeleted = false,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    String name = '';
    final rawFullName = json['full_name']?.toString().trim();
    final rawName = json['name']?.toString().trim();
    if (rawFullName != null && rawFullName.isNotEmpty) {
      name = rawFullName;
    } else if (rawName != null && rawName.isNotEmpty) {
      name = rawName;
    } else {
      final rawEmail = json['email']?.toString().trim();
      name = (rawEmail != null && rawEmail.isNotEmpty) ? rawEmail : 'Guru';
    }

    String position = 'Guru Bidang Studi';
    final rawPos = json['position']?.toString().trim();
    if (rawPos != null && rawPos.isNotEmpty) {
      position = rawPos;
    }

    final isDeleted =
        json['isDeleted'] == true ||
        json['is_deleted'] == true ||
        json['deleted_at'] != null ||
        TeacherRoles.isSoftDeleted(json['role']?.toString());

    return TeacherModel(
      id: json['id']?.toString() ?? '',
      name: name,
      position: position,
      address: json['address']?.toString() ?? '',
      phoneNumber:
          json['phoneNumber']?.toString() ??
          json['phone']?.toString() ??
          json['phone_number']?.toString() ??
          '',
      email: json['email']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString() ?? json['photo_url']?.toString(),
      nip: json['nip']?.toString(),
      isDeleted: isDeleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'address': address,
      'phoneNumber': phoneNumber,
      'email': email,
      'photoUrl': photoUrl,
      'nip': nip,
      'isDeleted': isDeleted,
    };
  }

  TeacherModel copyWith({
    String? id,
    String? name,
    String? position,
    String? address,
    String? phoneNumber,
    String? email,
    String? photoUrl,
    String? nip,
    bool? isDeleted,
    bool clearNip = false,
  }) {
    return TeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      nip: clearNip ? null : (nip ?? this.nip),
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
