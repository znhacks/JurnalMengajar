import '../core/utils/helper.dart';

class HourModel {
  final String id;
  final int teachingHour; // e.g. 1, 2, 3...
  final String startTime;  // e.g. '07:00'
  final String endTime;    // e.g. '07:45'
  final String? schoolId;

  HourModel({
    required this.id,
    required this.teachingHour,
    required this.startTime,
    required this.endTime,
    this.schoolId,
  });

  factory HourModel.fromJson(Map<String, dynamic> json) {
    int teachingHour = 1;
    final rawHour = json['teaching_hour'] ?? json['teachingHour'];
    if (rawHour is int) {
      teachingHour = rawHour;
    } else if (rawHour != null) {
      teachingHour = int.tryParse(rawHour.toString()) ?? 1;
    }

    return HourModel(
      id: json['id']?.toString() ?? '',
      teachingHour: teachingHour,
      startTime: json['start_time']?.toString() ?? json['startTime']?.toString() ?? '07:00',
      endTime: json['end_time']?.toString() ?? json['endTime']?.toString() ?? '07:45',
      schoolId: AppHelper.parseSingleCleanSchoolId(json['school_id']),
    );
  }


  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'teaching_hour': teachingHour,
      'start_time': startTime,
      'end_time': endTime,
    };
    if (schoolId != null && schoolId!.isNotEmpty) {
      map['school_id'] = schoolId;
    }
    return map;
  }

  HourModel copyWith({
    String? id,
    int? teachingHour,
    String? startTime,
    String? endTime,
    String? schoolId,
  }) {
    return HourModel(
      id: id ?? this.id,
      teachingHour: teachingHour ?? this.teachingHour,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      schoolId: schoolId ?? this.schoolId,
    );
  }
}
