class SchoolModel {
  final String id;
  final String name;
  final String? code;
  final String? address;
  final String? phone;
  final String status; // 'active' or 'inactive'
  final String? governmentHeader; // e.g. PEMERINTAH KABUPATEN SIAK
  final String? departmentHeader; // e.g. DINAS PENDIDIKAN DAN KEBUDAYAAN
  final String? website;
  final String? email;
  final String? nss;
  final String? npsn;
  final String? postalCode;
  final String? logoUrl;
  final String plan; // 'free', 'pro', or 'enterprise'
  final String? activationCode;
  final int maxTeachers;
  final DateTime? subscriptionUntil;

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
    this.plan = 'free',
    this.activationCode,
    this.maxTeachers = 30,
    this.subscriptionUntil,
  });

  bool get isActive => status.toLowerCase() == 'active';
  bool get isInactive => status.toLowerCase() == 'inactive';

  bool get isSubscriptionActive {
    if (subscriptionUntil == null) return true;
    return DateTime.now().isBefore(subscriptionUntil!);
  }

  bool get isPro => (plan.toLowerCase() == 'pro' || plan.toLowerCase() == 'enterprise') && isSubscriptionActive;
  bool get isEnterprise => plan.toLowerCase() == 'enterprise' && isSubscriptionActive;
  bool get isFree => !isPro && !isEnterprise;

  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['subscription_plan'] as String? ?? json['plan'] as String? ?? 'free';
    final parsedPlan = rawPlan.toLowerCase().trim();
    final defaultMax = parsedPlan == 'pro' ? 50 : (parsedPlan == 'enterprise' ? 999 : 30);

    DateTime? parsedSubscriptionUntil;
    if (json['subscription_until'] != null) {
      if (json['subscription_until'] is String) {
        parsedSubscriptionUntil = DateTime.tryParse(json['subscription_until'] as String);
      } else if (json['subscription_until'] is DateTime) {
        parsedSubscriptionUntil = json['subscription_until'] as DateTime;
      }
    } else if (json['subscriptionUntil'] != null) {
      if (json['subscriptionUntil'] is String) {
        parsedSubscriptionUntil = DateTime.tryParse(json['subscriptionUntil'] as String);
      } else if (json['subscriptionUntil'] is DateTime) {
        parsedSubscriptionUntil = json['subscriptionUntil'] as DateTime;
      }
    }

    return SchoolModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sekolah',
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
      plan: parsedPlan,
      activationCode: json['code'] as String? ?? json['activation_code'] as String? ?? json['activationCode'] as String?,
      maxTeachers: json['max_teachers'] as int? ?? defaultMax,
      subscriptionUntil: parsedSubscriptionUntil,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code ?? activationCode,
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
      'subscription_plan': plan,
      'max_teachers': maxTeachers,
      'subscription_until': subscriptionUntil?.toIso8601String(),
    };
  }

  SchoolModel copyWith({
    String? id,
    String? name,
    String? code,
    String? address,
    String? phone,
    String? status,
    String? governmentHeader,
    String? departmentHeader,
    String? website,
    String? email,
    String? nss,
    String? npsn,
    String? postalCode,
    String? logoUrl,
    String? plan,
    String? activationCode,
    int? maxTeachers,
    DateTime? subscriptionUntil,
  }) {
    return SchoolModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      governmentHeader: governmentHeader ?? this.governmentHeader,
      departmentHeader: departmentHeader ?? this.departmentHeader,
      website: website ?? this.website,
      email: email ?? this.email,
      nss: nss ?? this.nss,
      npsn: npsn ?? this.npsn,
      postalCode: postalCode ?? this.postalCode,
      logoUrl: logoUrl ?? this.logoUrl,
      plan: plan ?? this.plan,
      activationCode: activationCode ?? this.activationCode,
      maxTeachers: maxTeachers ?? this.maxTeachers,
      subscriptionUntil: subscriptionUntil ?? this.subscriptionUntil,
    );
  }
}

