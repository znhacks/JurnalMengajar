import '../core/utils/helper.dart';

class WarningLetterModel {
  final String id;
  final String teacherId;
  final String scheduleId;
  final DateTime issuedAt;
  final String reason;
  final String status; // 'unread' | 'read'
  final String? schoolId;

  WarningLetterModel({
    required this.id,
    required this.teacherId,
    required this.scheduleId,
    required this.issuedAt,
    required this.reason,
    required this.status,
    this.schoolId,
  });

  factory WarningLetterModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedIssuedAt = DateTime.now();
    final rawIssued = json['issued_at'] ?? json['issuedAt'];
    if (rawIssued is String) {
      parsedIssuedAt = DateTime.tryParse(rawIssued)?.toLocal() ?? DateTime.now();
    } else if (rawIssued is DateTime) {
      parsedIssuedAt = rawIssued.toLocal();
    }

    return WarningLetterModel(
      id: json['id']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? json['teacherId']?.toString() ?? '',
      scheduleId: json['schedule_id']?.toString() ?? json['scheduleId']?.toString() ?? '',
      issuedAt: parsedIssuedAt,
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unread',
      schoolId: AppHelper.parseSingleCleanSchoolId(json['school_id']),
    );
  }


  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      if (id.isNotEmpty) 'id': id,
      'teacher_id': teacherId,
      'schedule_id': scheduleId,
      'issued_at': issuedAt.toUtc().toIso8601String(),
      'reason': reason,
      'status': status,
    };
    if (schoolId != null && schoolId!.isNotEmpty) {
      map['school_id'] = schoolId;
    }
    return map;
  }

  WarningLetterModel copyWith({
    String? id,
    String? teacherId,
    String? scheduleId,
    DateTime? issuedAt,
    String? reason,
    String? status,
    String? schoolId,
  }) {
    return WarningLetterModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      scheduleId: scheduleId ?? this.scheduleId,
      issuedAt: issuedAt ?? this.issuedAt,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      schoolId: schoolId ?? this.schoolId,
    );
  }
}
