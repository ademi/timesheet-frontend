class EmployeeBulkDeleteResponse {
  const EmployeeBulkDeleteResponse({
    required this.message,
    required this.deletedCount,
    required this.notFoundIds,
  });

  final String message;
  final int deletedCount;
  final List<String> notFoundIds;

  factory EmployeeBulkDeleteResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeBulkDeleteResponse(
      message: json['message'] as String? ?? '',
      deletedCount: (json['deleted_count'] as num?)?.toInt() ?? 0,
      notFoundIds: (json['not_found_ids'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          const [],
    );
  }
}
