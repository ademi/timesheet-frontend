/// GPS body for visit check-in / complete (`VisitGpsBody`).
class VisitGpsBody {
  const VisitGpsBody({
    required this.lat,
    required this.lng,
    this.accuracyM,
  });

  final double lat;
  final double lng;
  final double? accuracyM;

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracy_m': accuracyM,
      };

  factory VisitGpsBody.fromJson(Map<String, dynamic> json) {
    return VisitGpsBody(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
    );
  }
}
