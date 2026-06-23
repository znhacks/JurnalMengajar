class PeriodModel {
  final String id;
  final String name;
  final bool isActive;

  PeriodModel({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory PeriodModel.fromJson(Map<String, dynamic> json) {
    return PeriodModel(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
    };
  }

  PeriodModel copyWith({
    String? id,
    String? name,
    bool? isActive,
  }) {
    return PeriodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
    );
  }
}
