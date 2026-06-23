class SettingsModel {
  final String id;
  final int maxJournalInputDays; // Batas input jurnal dalam hari

  SettingsModel({
    required this.id,
    required this.maxJournalInputDays,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      id: json['id'] as String,
      maxJournalInputDays: json['max_journal_input_days'] as int? ?? json['maxJournalInputDays'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'max_journal_input_days': maxJournalInputDays,
    };
  }

  SettingsModel copyWith({
    String? id,
    int? maxJournalInputDays,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      maxJournalInputDays: maxJournalInputDays ?? this.maxJournalInputDays,
    );
  }
}
