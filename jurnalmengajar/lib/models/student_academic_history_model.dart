import '../core/utils/helper.dart';

class StudentAcademicHistoryModel {
  final String id;
  final String studentId;
  final String? studentName;
  final String? studentNis;
  final String schoolId;
  final String periodId;
  final String classId;
  final String academicYear;
  final String className;
  final String status; // 'aktif', 'naik', 'tidak_naik', 'lulus', 'pindah', 'tetap'
  final String? fromPeriodId;
  final String? fromClassId;
  final String? fromClassName;
  final String? toPeriodId;
  final String? toClassId;
  final String? toClassName;
  final DateTime? transferDate;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StudentAcademicHistoryModel({
    required this.id,
    required this.studentId,
    this.studentName,
    this.studentNis,
    required this.schoolId,
    required this.periodId,
    required this.classId,
    required this.academicYear,
    required this.className,
    required this.status,
    this.fromPeriodId,
    this.fromClassId,
    this.fromClassName,
    this.toPeriodId,
    this.toClassId,
    this.toClassName,
    this.transferDate,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory StudentAcademicHistoryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return StudentAcademicHistoryModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? json['student']?['name']?.toString(),
      studentNis: json['student_nis']?.toString() ?? json['student']?['nis']?.toString(),
      schoolId: AppHelper.parseSingleCleanSchoolId(json['school_id']) ?? '',
      periodId: json['period_id']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      academicYear: json['academic_year']?.toString() ?? '',
      className: json['class_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'aktif',
      fromPeriodId: json['from_period_id']?.toString(),
      fromClassId: json['from_class_id']?.toString(),
      fromClassName: json['from_class_name']?.toString(),
      toPeriodId: json['to_period_id']?.toString(),
      toClassId: json['to_class_id']?.toString(),
      toClassName: json['to_class_name']?.toString(),
      transferDate: parseDate(json['transfer_date']),
      note: json['note']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'student_id': studentId,
      'school_id': schoolId,
      'period_id': periodId,
      'class_id': classId,
      'academic_year': academicYear,
      'class_name': className,
      'status': status,
    };

    if (id.isNotEmpty) map['id'] = id;
    if (fromPeriodId != null) map['from_period_id'] = fromPeriodId;
    if (fromClassId != null) map['from_class_id'] = fromClassId;
    if (fromClassName != null) map['from_class_name'] = fromClassName;
    if (toPeriodId != null) map['to_period_id'] = toPeriodId;
    if (toClassId != null) map['to_class_id'] = toClassId;
    if (toClassName != null) map['to_class_name'] = toClassName;
    if (transferDate != null) map['transfer_date'] = transferDate!.toIso8601String().split('T')[0];
    if (note != null) map['note'] = note;

    return map;
  }

  String get formattedStatus {
    switch (status.toLowerCase()) {
      case 'naik':
        return 'Naik Kelas';
      case 'tidak_naik':
        return 'Tidak Naik Kelas';
      case 'lulus':
        return 'Lulus';
      case 'pindah':
        return 'Pindah Kelas';
      case 'tetap':
        return 'Tetap';
      case 'aktif':
      default:
        return 'Aktif';
    }
  }
}
