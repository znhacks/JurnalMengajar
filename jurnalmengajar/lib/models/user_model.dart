class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'guru' | 'admin'
  final String? photoUrl;
  final String? phoneNumber;
  final String? position;
  final String? address;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.photoUrl,
    this.phoneNumber,
    this.position,
    this.address,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String? ?? json['fullName'] as String,
      role: json['role'] as String,
      photoUrl: json['photo_url'] as String? ?? json['photoUrl'] as String?,
      phoneNumber: json['phone'] as String? ?? json['phoneNumber'] as String?,
      position: json['position'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'photo_url': photoUrl,
      'phone': phoneNumber,
      'position': position,
      'address': address,
    };
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
    );
  }
}
