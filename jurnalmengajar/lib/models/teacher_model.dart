class TeacherModel {
  final String id;
  final String name;
  final String position;
  final String address;
  final String phoneNumber;
  final String email;
  final String? photoUrl;

  TeacherModel({
    required this.id,
    required this.name,
    required this.position,
    required this.address,
    required this.phoneNumber,
    required this.email,
    this.photoUrl,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    return TeacherModel(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String,
      address: json['address'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String,
      photoUrl: json['photoUrl'] as String?,
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
  }) {
    return TeacherModel(
      id: id ?? this.id,
      name: name ?? this.name,
      position: position ?? this.position,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
