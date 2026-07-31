# DF-B12 Task 3 Report

## Status

Implemented the contractor documents-needed banner on home. It is shown only
when `SessionService.needsDocsAttention` is true for a non-staff actor, and
its CTA navigates to contractor credentials. Engagement acceptance copy now
points contractors to the home banner or Credentials instead of a forced next
step.

## Verification

- `flutter test test/features/compliance_ops/home_alerts_view_test.dart` — pass
- `flutter analyze lib/features/compliance_ops/views/home_alerts_view.dart lib/features/engagements/views/engagement_accept_panel.dart test/features/compliance_ops/home_alerts_view_test.dart` — pass
- `flutter test` — existing unrelated failures in `test/widget_test.dart` and
  four legacy admin-route assertions in `test/core/responsive/responsive_qa_test.dart`.

## Scope Notes

No notification-feed 403 mapping change was made: the local code confirms that
403s surface as an inline error, but it does not establish that the issue
persists after `switchTenant`, so changing ACL behavior would be speculative.
