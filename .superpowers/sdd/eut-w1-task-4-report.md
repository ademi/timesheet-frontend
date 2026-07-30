# EUT W1 Task 4 Report — Frontend registration invite UX

## Delivered

- Parses the `EngagementInviteResponse` union and shows “Registration email sent” when a new contractor receives a registration invite; existing contractors retain the “Engagement created” confirmation.
- Adds the public contractor-invite API path, public-summary fetch, and registration request `invite_token`.
- `/contractor/register?invite=<token>` now validates the invite, pre-fills its email address, displays the inviting tenant, and sends the token on registration.
- Maps `email_required_for_registration_invite`, `invite_token_invalid`, and `invite_email_mismatch` to actionable user messages.

## Verification

- Red phase: the new union, invite-token, and failure-mapping tests failed before implementation because the types/field/error mappings were absent.
- Green phase: `flutter test test/features/engagements/engagement_models_test.dart test/features/contractor_register/contractor_register_repository_test.dart test/core/errors/app_failure_test.dart` — 11 passed.
- Static analysis: `dart analyze` over all touched production and test files — no issues.

## Manual smoke

Full web/mobile smoke testing was not run in this environment. Validate J1 manually by sending an invite to an unregistered email, opening the emailed `/contractor/register?invite=…` link, confirming the email is prefilled, completing registration, and verifying the engagement appears for the staff tenant.

## Review fixes (Task 4)

- **Submit gating:** `Create account` stays disabled while `isInviteLoading` is true (invite deep link fetch in progress); controller `submit()` also no-ops during invite load.
- **Email lock:** After a successful public invite summary load, the email field is read-only so users cannot edit away from the invited address and hit `invite_email_mismatch`.
- Existing `AppFailure` mappings and registration snackbars unchanged.

### Verification

- `flutter test test/features/engagements/engagement_models_test.dart test/features/contractor_register/contractor_register_repository_test.dart test/core/errors/app_failure_test.dart` — 11 passed.
- `dart analyze` on `contractor_register_view.dart` and `contractor_register_controller.dart` — no issues.
