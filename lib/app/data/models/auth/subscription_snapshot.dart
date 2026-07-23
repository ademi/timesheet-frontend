class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.status,
    required this.isActive,
    required this.isReadonly,
    this.trialEndAt,
    this.daysLeft,
    this.message,
  });

  final String status;
  final bool isActive;
  final bool isReadonly;
  final String? trialEndAt;
  final int? daysLeft;
  final String? message;

  factory SubscriptionSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SubscriptionSnapshot(
        status: 'unknown',
        isActive: true,
        isReadonly: false,
      );
    }
    return SubscriptionSnapshot(
      status: json['status'] as String? ?? 'unknown',
      isActive: json['is_active'] as bool? ?? true,
      isReadonly: json['is_readonly'] as bool? ?? false,
      trialEndAt: json['trial_end_at'] as String?,
      daysLeft: json['days_left'] as int?,
      message: json['message'] as String?,
    );
  }
}
