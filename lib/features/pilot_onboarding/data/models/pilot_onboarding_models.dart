/// Tenant pilot getting-started checklist (`GET .../pilot-onboarding`).
class PilotOnboardingOut {
  const PilotOnboardingOut({
    required this.invitedWorker,
    required this.createdClient,
    required this.publishedShift,
    required this.allComplete,
    required this.dismissed,
    this.dismissedAt,
  });

  final bool invitedWorker;
  final bool createdClient;
  final bool publishedShift;
  final bool allComplete;
  final bool dismissed;
  final DateTime? dismissedAt;

  bool get shouldShowCard => !dismissed && !allComplete;

  factory PilotOnboardingOut.fromJson(Map<String, dynamic> json) {
    final steps = json['steps'];
    final map =
        steps is Map
            ? Map<String, dynamic>.from(steps)
            : const <String, dynamic>{};
    return PilotOnboardingOut(
      invitedWorker: map['invited_worker'] as bool? ?? false,
      createdClient: map['created_client'] as bool? ?? false,
      publishedShift: map['published_shift'] as bool? ?? false,
      allComplete: json['all_complete'] as bool? ?? false,
      dismissed: json['dismissed'] as bool? ?? false,
      dismissedAt:
          json['dismissed_at'] != null
              ? DateTime.tryParse(json['dismissed_at'] as String)
              : null,
    );
  }
}
