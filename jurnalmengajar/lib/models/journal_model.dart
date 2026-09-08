import '../core/utils/helper.dart';
import 'journal_attachment_model.dart';


class JournalModel {
  final String id;
  final String scheduleId;
  final DateTime date;
  final int teachingHour;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String material;
  final int sickCount;
  final int permissionCount;
  final int alphaCount;
  final String? note;
  final JournalAttachmentModel? attachment;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? attachmentUrl;
  final String? rejectionNote;
  final bool isSoftDeleted;
  final DateTime? deletedAt;
  final String? schoolId;

  JournalModel({
    required this.id,
    required this.scheduleId,
    required this.date,
    required this.teachingHour,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.material,
    this.sickCount = 0,
    this.permissionCount = 0,
    this.alphaCount = 0,
    this.note,
    this.attachment,
    required this.status,
    this.attachmentUrl,
    this.rejectionNote,
    this.isSoftDeleted = false,
    this.deletedAt,
    this.schoolId,
  });

  factory JournalModel.fromJson(Map<String, dynamic> json) {
    final attachmentUrl = json['attachment_url']?.toString() ?? json['attachmentUrl']?.toString();
    
    JournalAttachmentModel? attachment;
    if (json['attachment'] != null && json['attachment'] is Map) {
      try {
        attachment = JournalAttachmentModel.fromJson(
            Map<String, dynamic>.from(json['attachment'] as Map));
      } catch (_) {}
    } else if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
      try {
        final firstUrl = attachmentUrl.split(',').first.trim();
        final uri = Uri.parse(firstUrl);
        final fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'attachment';
        final fileType = fileName.toLowerCase().endsWith('.pdf') ? 'pdf' : 'image';
        attachment = JournalAttachmentModel(
          id: 'ja_remote',
          filePath: firstUrl,
          fileType: fileType,
          fileName: fileName,
        );
      } catch (_) {}
    }

    DateTime parsedDate = DateTime.now();
    final rawDate = json['date'];
    if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    }

    int teachingHour = 1;
    final rawHour = json['teaching_hour'] ?? json['teachingHour'];
    if (rawHour is int) {
      teachingHour = rawHour;
    } else if (rawHour != null) {
      teachingHour = int.tryParse(rawHour.toString()) ?? 1;
    }

    int sickCount = 0;
    final rawSick = json['sick_count'] ?? json['sickCount'];
    if (rawSick is int) {
      sickCount = rawSick;
    } else if (rawSick != null) {
      sickCount = int.tryParse(rawSick.toString()) ?? 0;
    }

    int permissionCount = 0;
    final rawPerm = json['permission_count'] ?? json['permissionCount'];
    if (rawPerm is int) {
      permissionCount = rawPerm;
    } else if (rawPerm != null) {
      permissionCount = int.tryParse(rawPerm.toString()) ?? 0;
    }

    int alphaCount = 0;
    final rawAlpha = json['alpha_count'] ?? json['alphaCount'];
    if (rawAlpha is int) {
      alphaCount = rawAlpha;
    } else if (rawAlpha != null) {
      alphaCount = int.tryParse(rawAlpha.toString()) ?? 0;
    }

    bool isSoftDeleted = false;
    final rawSoftDel = json['is_soft_deleted'] ?? json['isSoftDeleted'];
    if (rawSoftDel is bool) {
      isSoftDeleted = rawSoftDel;
    } else if (rawSoftDel != null) {
      isSoftDeleted = rawSoftDel.toString().toLowerCase() == 'true' || rawSoftDel == 1;
    }

    DateTime? deletedAt;
    final rawDelAt = json['deleted_at'] ?? json['deletedAt'];
    if (rawDelAt is String) {
      deletedAt = DateTime.tryParse(rawDelAt);
    } else if (rawDelAt is DateTime) {
      deletedAt = rawDelAt;
    }

    return JournalModel(
      id: json['id']?.toString() ?? '',
      scheduleId: json['schedule_id']?.toString() ?? json['scheduleId']?.toString() ?? '',
      date: parsedDate,
      teachingHour: teachingHour,
      classId: json['class_id']?.toString() ?? json['classId']?.toString() ?? '',
      subjectId: json['subject_id']?.toString() ?? json['subjectId']?.toString() ?? '',
      teacherId: json['teacher_id']?.toString() ?? json['teacherId']?.toString() ?? '',
      material: json['material']?.toString() ?? '',
      sickCount: sickCount,
      permissionCount: permissionCount,
      alphaCount: alphaCount,
      note: json['note']?.toString(),
      attachment: attachment,
      status: json['status']?.toString() ?? 'pending',
      attachmentUrl: attachmentUrl,
      rejectionNote: json['rejection_note']?.toString() ?? json['rejectionNote']?.toString(),
      isSoftDeleted: isSoftDeleted,
      deletedAt: deletedAt,
      schoolId: AppHelper.parseSingleCleanSchoolId(json['school_id']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'schedule_id': scheduleId,
      'date': date.toIso8601String(),
      'teaching_hour': teachingHour,
      'class_id': classId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'material': material,
      'sick_count': sickCount,
      'permission_count': permissionCount,
      'alpha_count': alphaCount,
      'note': note,
      'status': status,
      'attachment_url': attachmentUrl,
      'rejection_note': rejectionNote,
      'is_soft_deleted': isSoftDeleted,
      'deleted_at': deletedAt?.toIso8601String(),
    };
    if (schoolId != null && schoolId!.isNotEmpty) {
      map['school_id'] = schoolId;
    }
    return map;
  }

  JournalModel copyWith({
    String? id,
    String? scheduleId,
    DateTime? date,
    int? teachingHour,
    String? classId,
    String? subjectId,
    String? teacherId,
    String? material,
    int? sickCount,
    int? permissionCount,
    int? alphaCount,
    String? note,
    JournalAttachmentModel? attachment,
    String? status,
    String? attachmentUrl,
    String? rejectionNote,
    bool? isSoftDeleted,
    DateTime? deletedAt,
    String? schoolId,
  }) {
    return JournalModel(
      id: id ?? this.id,
      scheduleId: scheduleId ?? this.scheduleId,
      date: date ?? this.date,
      teachingHour: teachingHour ?? this.teachingHour,
      classId: classId ?? this.classId,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      material: material ?? this.material,
      sickCount: sickCount ?? this.sickCount,
      permissionCount: permissionCount ?? this.permissionCount,
      alphaCount: alphaCount ?? this.alphaCount,
      note: note ?? this.note,
      attachment: attachment ?? this.attachment,
      status: status ?? this.status,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      rejectionNote: rejectionNote ?? this.rejectionNote,
      isSoftDeleted: isSoftDeleted ?? this.isSoftDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      schoolId: schoolId ?? this.schoolId,
    );
  }
}
