class SettingsModel {
  final String id;
  final int maxJournalInputDays; // Batas input jurnal dalam hari

  SettingsModel({
    required this.id,
    required this.maxJournalInputDays,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    int maxDays = 3;
    final rawDays = json['max_journal_input_days'] ?? json['maxJournalInputDays'];
    if (rawDays is int) {
      maxDays = rawDays;
    } else if (rawDays != null) {
      maxDays = int.tryParse(rawDays.toString()) ?? 3;
    }

    return SettingsModel(
      id: json['id']?.toString() ?? '',
      maxJournalInputDays: maxDays,
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
