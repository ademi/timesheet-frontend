/// Public platform trust metadata (`GET /v1/public/platform-info`).
class PlatformInfoOut {
  const PlatformInfoOut({
    required this.dataResidencyClaimable,
    this.dataRegion,
    this.dataResidencyLabel,
  });

  final bool dataResidencyClaimable;
  final String? dataRegion;
  final String? dataResidencyLabel;

  /// Safe customer-facing line — only when backend says claimable.
  String? get residencyLine {
    if (!dataResidencyClaimable) return null;
    final label = dataResidencyLabel?.trim();
    if (label == null || label.isEmpty) return null;
    return label;
  }

  factory PlatformInfoOut.fromJson(Map<String, dynamic> json) {
    return PlatformInfoOut(
      dataResidencyClaimable:
          json['data_residency_claimable'] as bool? ?? false,
      dataRegion: json['data_region'] as String?,
      dataResidencyLabel: json['data_residency_label'] as String?,
    );
  }

  static const empty = PlatformInfoOut(dataResidencyClaimable: false);
}
