class SettingsModel {
  final String id;
  final int maxJournalInputDays; // Batas input jurnal dalam hari
  final String? supervisorName;
  final String? supervisorNip;

  SettingsModel({
    required this.id,
    required this.maxJournalInputDays,
    this.supervisorName,
    this.supervisorNip,
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
      supervisorName: json['supervisor_name']?.toString() ?? json['supervisorName']?.toString(),
      supervisorNip: json['supervisor_nip']?.toString() ?? json['supervisorNip']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'max_journal_input_days': maxJournalInputDays,
    };
    if (supervisorName != null) {
      map['supervisor_name'] = supervisorName;
    }
    if (supervisorNip != null) {
      map['supervisor_nip'] = supervisorNip;
    }
    return map;
  }

  SettingsModel copyWith({
    String? id,
    int? maxJournalInputDays,
    String? supervisorName,
    String? supervisorNip,
    bool clearSupervisor = false,
  }) {
    return SettingsModel(
      id: id ?? this.id,
      maxJournalInputDays: maxJournalInputDays ?? this.maxJournalInputDays,
      supervisorName: clearSupervisor ? null : (supervisorName ?? this.supervisorName),
      supervisorNip: clearSupervisor ? null : (supervisorNip ?? this.supervisorNip),
    );
  }
}
