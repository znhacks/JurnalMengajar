class SchoolModel {
  final String id;
  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final String status;

  SchoolModel({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.phone,
    this.status = 'active',
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'status': status,
    };
  }
}
