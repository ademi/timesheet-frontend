class GeofenceModel {
  const GeofenceModel({
    required this.verdict,
    this.matchedZoneId,
  });

  final String verdict;
  final String? matchedZoneId;

  Map<String, dynamic> toJson() => {
        'verdict': verdict,
        'matched_zone_id': matchedZoneId,
      };

  factory GeofenceModel.fromJson(Map<String, dynamic> json) {
    return GeofenceModel(
      verdict: json['verdict'] as String? ?? 'unknown',
      matchedZoneId: json['matched_zone_id'] as String?,
    );
  }
}
