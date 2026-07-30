class FalseNegativeReport {
  final int? id;
  final String? soundType;
  final String? description;
  final DateTime occurredAt;
  final String? deviceInfo;

  FalseNegativeReport({
    this.id,
    this.soundType,
    this.description,
    required this.occurredAt,
    this.deviceInfo,
  });

  Map<String, dynamic> toJson() => {
    if (soundType != null) 'soundType': soundType,
    if (description != null) 'description': description,
    'occurredAt': occurredAt.toIso8601String(),
    if (deviceInfo != null) 'deviceInfo': deviceInfo,
  };
}
