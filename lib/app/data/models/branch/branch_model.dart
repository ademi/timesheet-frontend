class BranchModel {
  const BranchModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final String location;
  final String createdAt;
  final String updatedAt;

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenant_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}
