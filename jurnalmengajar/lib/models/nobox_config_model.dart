class NoboxConfigModel {
  final String schoolId;
  final bool hasApiKey;
  final String? maskedApiKey;
  final String channelId;
  final String accountId;
  final bool isActive;
  final String connectionStatus; // 'connected', 'failed', 'untested'
  final DateTime? lastTestedAt;
  final String? lastErrorMessage;

  const NoboxConfigModel({
    required this.schoolId,
    this.hasApiKey = false,
    this.maskedApiKey,
    this.channelId = '1',
    this.accountId = '',
    this.isActive = true,
    this.connectionStatus = 'untested',
    this.lastTestedAt,
    this.lastErrorMessage,
  });

  bool get isConnected => connectionStatus == 'connected';
  bool get isFailed => connectionStatus == 'failed';
  bool get isUntested => connectionStatus == 'untested' || connectionStatus.isEmpty;

  factory NoboxConfigModel.fromJson(String schoolId, Map<String, dynamic> json) {
    DateTime? testedAt;
    if (json['last_tested_at'] != null) {
      testedAt = DateTime.tryParse(json['last_tested_at'].toString());
    }

    return NoboxConfigModel(
      schoolId: schoolId,
      hasApiKey: json['has_api_key'] == true,
      maskedApiKey: json['masked_api_key']?.toString(),
      channelId: json['channel_id']?.toString() ?? '1',
      accountId: json['account_id']?.toString() ?? '',
      isActive: json['is_active'] != false,
      connectionStatus: json['connection_status']?.toString() ?? 'untested',
      lastTestedAt: testedAt,
      lastErrorMessage: json['last_error_message']?.toString(),
    );
  }

  NoboxConfigModel copyWith({
    String? schoolId,
    bool? hasApiKey,
    String? maskedApiKey,
    String? channelId,
    String? accountId,
    bool? isActive,
    String? connectionStatus,
    DateTime? lastTestedAt,
    String? lastErrorMessage,
  }) {
    return NoboxConfigModel(
      schoolId: schoolId ?? this.schoolId,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      maskedApiKey: maskedApiKey ?? this.maskedApiKey,
      channelId: channelId ?? this.channelId,
      accountId: accountId ?? this.accountId,
      isActive: isActive ?? this.isActive,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastTestedAt: lastTestedAt ?? this.lastTestedAt,
      lastErrorMessage: lastErrorMessage ?? this.lastErrorMessage,
    );
  }
}
