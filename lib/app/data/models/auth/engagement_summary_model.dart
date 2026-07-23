/// Engagement summary returned on login / refresh / switch-tenant / me-context.
class EngagementSummaryModel {
  const EngagementSummaryModel({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.status,
  });

  final String id;
  final String tenantId;
  final String tenantName;
  final String status;

  factory EngagementSummaryModel.fromJson(Map<String, dynamic> json) {
    return EngagementSummaryModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      tenantName: json['tenant_name'] as String,
      status: json['status'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'tenant_name': tenantName,
        'status': status,
      };
}
