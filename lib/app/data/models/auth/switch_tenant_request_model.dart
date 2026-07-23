class SwitchTenantRequestModel {
  const SwitchTenantRequestModel({required this.tenantId});

  final String tenantId;

  Map<String, dynamic> toJson() => {'tenant_id': tenantId};
}
