class JournalAttachmentModel {
  final String id;
  final String filePath;
  final String fileType; // 'image' | 'pdf'
  final String fileName;

  JournalAttachmentModel({
    required this.id,
    required this.filePath,
    required this.fileType,
    required this.fileName,
  });

  factory JournalAttachmentModel.fromJson(Map<String, dynamic> json) {
    return JournalAttachmentModel(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      fileType: json['fileType'] as String,
      fileName: json['fileName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'fileType': fileType,
      'fileName': fileName,
    };
  }

  JournalAttachmentModel copyWith({
    String? id,
    String? filePath,
    String? fileType,
    String? fileName,
  }) {
    return JournalAttachmentModel(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileName: fileName ?? this.fileName,
    );
  }
}
