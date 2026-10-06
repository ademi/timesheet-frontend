import '../../../../app/routes/app_navigator.dart';
import '../../../../app/routes/app_routes.dart';
import 'compliance_ops_models.dart';

/// Where a notification event should navigate when tapped (B1).
class NotificationDestination {
  const NotificationDestination({required this.location});

  /// Full path including query (`AppNavigator.location`).
  final String location;
}

/// Resolve tap target from event type + payload.
///
/// Returns null when the event has no in-app destination (or the actor
/// should not open that screen — e.g. staff must not land on contractor Open).
NotificationDestination? resolveNotificationDestination(
  NotificationEventOut event, {
  required bool isContractor,
}) {
  final payload = event.payload;

  String? payloadId(String key) {
    final raw = payload[key]?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    return raw;
  }

  final visitId = payloadId('visit_id') ?? event.entityId;
  final shiftId = payloadId('shift_id') ?? event.entityId;
  final engagementId = payloadId('engagement_id') ?? event.entityId;
  final clientId = payloadId('client_id') ?? event.entityId;

  switch (event.eventType) {
    case 'visit.assigned':
    case 'visit.checked_in':
    case 'visit.completed':
      if (visitId == null) return null;
      return NotificationDestination(
        location: AppNavigator.location(
          isContractor
              ? AppRoutes.contractorVisitDetail
              : AppRoutes.staffVisitDetail,
          query: {'id': visitId},
        ),
      );

    case 'shift.slot_opened':
      if (!isContractor) return null;
      return NotificationDestination(
        location: AppNavigator.location(
          AppRoutes.contractorVisits,
          query: {
            'tab': 'open',
            if (shiftId != null) 'shiftId': shiftId,
          },
        ),
      );

    case 'engagement.invited':
    case 'engagement.accepted':
    case 'engagement.awaiting_approval':
    case 'engagement.activated':
    case 'engagement.suspended':
    case 'engagement.ended':
      if (isContractor || engagementId == null) return null;
      return NotificationDestination(
        location: AppNavigator.location(
          AppRoutes.staffWorkforceDetail,
          query: {'id': engagementId},
        ),
      );

    case 'client.invite':
      if (isContractor || clientId == null) return null;
      return NotificationDestination(
        location: AppNavigator.location(
          AppRoutes.staffClientDetail,
          query: {'id': clientId},
        ),
      );

    case 'docs.required_reminder':
    case 'compliance.credential_expiring':
    case 'compliance.review_rejected':
      if (!isContractor) return null;
      return const NotificationDestination(
        location: AppRoutes.contractorCredentials,
      );

    case 'sharing.access_requested':
      if (isContractor) {
        return const NotificationDestination(
          location: AppRoutes.contractorProfile,
        );
      }
      return null;

    default:
      return null;
  }
}
