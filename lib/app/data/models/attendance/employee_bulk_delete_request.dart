class EmployeeBulkDeleteRequest {
  const EmployeeBulkDeleteRequest({required this.ids});

  final List<String> ids;

  Map<String, dynamic> toJson() => {'ids': ids};
}
