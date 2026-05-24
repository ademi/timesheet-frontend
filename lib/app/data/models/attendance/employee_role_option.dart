class EmployeeRoleOption {
  const EmployeeRoleOption({
    required this.id,
    required this.name,
    this.description,
  });

  final String id;
  final String name;
  final String? description;

  factory EmployeeRoleOption.fromJson(Map<String, dynamic> json) {
    return EmployeeRoleOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}
