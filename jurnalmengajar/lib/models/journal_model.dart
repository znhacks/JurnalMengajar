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
  });

  factory JournalModel.fromJson(Map<String, dynamic> json) {
    final attachmentUrl = json['attachment_url'] as String? ?? json['attachmentUrl'] as String?;
    
    JournalAttachmentModel? attachment;
    if (json['attachment'] != null) {
      attachment = JournalAttachmentModel.fromJson(
          json['attachment'] as Map<String, dynamic>);
    } else if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
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
    }

    return JournalModel(
      id: json['id'] as String,
      scheduleId: json['schedule_id'] as String? ?? json['scheduleId'] as String,
      date: json['date'] is String ? DateTime.parse(json['date'] as String) : json['date'] as DateTime,
      teachingHour: json['teaching_hour'] as int? ?? json['teachingHour'] as int,
      classId: json['class_id'] as String? ?? json['classId'] as String,
      subjectId: json['subject_id'] as String? ?? json['subjectId'] as String,
      teacherId: json['teacher_id'] as String? ?? json['teacherId'] as String,
      material: json['material'] as String,
      sickCount: json['sick_count'] as int? ?? json['sickCount'] as int? ?? 0,
      permissionCount: json['permission_count'] as int? ?? json['permissionCount'] as int? ?? 0,
      alphaCount: json['alpha_count'] as int? ?? json['alphaCount'] as int? ?? 0,
      note: json['note'] as String?,
      attachment: attachment,
      status: json['status'] as String,
      attachmentUrl: attachmentUrl,
      rejectionNote: json['rejection_note'] as String? ?? json['rejectionNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
    };
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
    );
  }
}
