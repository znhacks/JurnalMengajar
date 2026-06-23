class HourModel {
  final String id;
  final int teachingHour; // e.g. 1, 2, 3...
  final String startTime;  // e.g. '07:00'
  final String endTime;    // e.g. '07:45'

  HourModel({
    required this.id,
    required this.teachingHour,
    required this.startTime,
    required this.endTime,
  });

  factory HourModel.fromJson(Map<String, dynamic> json) {
    return HourModel(
      id: json['id'] as String,
      teachingHour: json['teaching_hour'] as int? ?? json['teachingHour'] as int,
      startTime: json['start_time'] as String? ?? json['startTime'] as String,
      endTime: json['end_time'] as String? ?? json['endTime'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'teaching_hour': teachingHour,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  HourModel copyWith({
    String? id,
    int? teachingHour,
    String? startTime,
    String? endTime,
  }) {
    return HourModel(
      id: id ?? this.id,
      teachingHour: teachingHour ?? this.teachingHour,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
