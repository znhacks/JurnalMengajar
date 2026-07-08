class WarningLetterModel {
  final String id;
  final String teacherId;
  final String scheduleId;
  final DateTime issuedAt;
  final String reason;
  final String status; // 'unread' | 'read'

  WarningLetterModel({
    required this.id,
    required this.teacherId,
    required this.scheduleId,
    required this.issuedAt,
    required this.reason,
    required this.status,
  });

  factory WarningLetterModel.fromJson(Map<String, dynamic> json) {
    return WarningLetterModel(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String? ?? json['teacherId'] as String,
      scheduleId: json['schedule_id'] as String? ?? json['scheduleId'] as String,
      issuedAt: json['issued_at'] is String
          ? DateTime.parse(json['issued_at'] as String).toLocal()
          : (json['issued_at'] as DateTime).toLocal(),
      reason: json['reason'] as String,
      status: json['status'] as String? ?? 'unread',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'teacher_id': teacherId,
      'schedule_id': scheduleId,
      'issued_at': issuedAt.toUtc().toIso8601String(),
      'reason': reason,
      'status': status,
    };
  }

  WarningLetterModel copyWith({
    String? id,
    String? teacherId,
    String? scheduleId,
    DateTime? issuedAt,
    String? reason,
    String? status,
  }) {
    return WarningLetterModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      scheduleId: scheduleId ?? this.scheduleId,
      issuedAt: issuedAt ?? this.issuedAt,
      reason: reason ?? this.reason,
      status: status ?? this.status,
    );
  }
}
