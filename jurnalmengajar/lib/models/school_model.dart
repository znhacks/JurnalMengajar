class SchoolModel {
  final String id;
  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final String status;
  final String? governmentHeader; // e.g. PEMERINTAH KABUPATEN SIAK
  final String? departmentHeader; // e.g. DINAS PENDIDIKAN DAN KEBUDAYAAN
  final String? website;
  final String? email;
  final String? nss;
  final String? npsn;
  final String? postalCode;
  final String? logoUrl;

  SchoolModel({
    required this.id,
    required this.name,
    this.code,
    this.address,
    this.phone,
    this.status = 'active',
    this.governmentHeader,
    this.departmentHeader,
    this.website,
    this.email,
    this.nss,
    this.npsn,
    this.postalCode,
    this.logoUrl,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      status: json['status'] as String? ?? 'active',
      governmentHeader: json['government_header'] as String? ?? json['governmentHeader'] as String?,
      departmentHeader: json['department_header'] as String? ?? json['departmentHeader'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      nss: json['nss'] as String?,
      npsn: json['npsn'] as String?,
      postalCode: json['postal_code'] as String? ?? json['postalCode'] as String?,
      logoUrl: json['logo_url'] as String? ?? json['logoUrl'] as String?,
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
      'government_header': governmentHeader,
      'department_header': departmentHeader,
      'website': website,
      'email': email,
      'nss': nss,
      'npsn': npsn,
      'postal_code': postalCode,
      'logo_url': logoUrl,
    };
  }
}

