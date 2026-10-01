class HolidayModel {
  final String id;
  final String schoolId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String? category;
  final String? description;
  final String? createdBy;
  final DateTime? createdAt;

  HolidayModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.category,
    this.description,
    this.createdBy,
    this.createdAt,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    final cat = json['category'] as String?;
    final desc = json['description'] as String?;
    return HolidayModel(
      id: json['id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      startDate: json['start_date'] is String
          ? DateTime.parse(json['start_date'] as String)
          : json['start_date'] as DateTime,
      endDate: json['end_date'] is String
          ? DateTime.parse(json['end_date'] as String)
          : json['end_date'] as DateTime,
      category: (cat != null && cat.isNotEmpty) ? cat : desc,
      description: (desc != null && desc.isNotEmpty) ? desc : cat,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final cat = category ?? description;
    return {
      'id': id,
      'school_id': schoolId,
      'title': title,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'category': cat,
      'description': cat,
      'created_by': createdBy,
    };
  }

  HolidayModel copyWith({
    String? id,
    String? schoolId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    String? description,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return HolidayModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      category: category ?? this.category,
      description: description ?? this.description,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
