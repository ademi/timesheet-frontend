# DF-P5 Tasks 1–2 report — Evidence view/download polish

## Verdict: Approved

Contractor detail/list and staff review now surface actual document IDs as View and Download controls. Restricted image evidence previews in-app; PDFs and other proxy bytes use the platform share/save flow. Forbidden responses explain that access is missing, while transport failures tell the user to retry.

## Task 1 spike

- Credential DTOs expose only `evidence_presence`; they do not include document IDs.
- The documents list API returns contractor-owned documents but omits `credential_id`. The frontend therefore groups visible document IDs by credential category. This follows the available frontend contract, but cannot distinguish multiple same-category credential records without a future API DTO change.
- Staff metadata listing is ACL-protected by an active grant/category; source content also requires `credentials.source.read` and `allow_source_evidence`. No backend ACL change was made.

## Task 2

- Added reusable View/Download evidence controls to contractor list/detail and staff review.
- Added proxy image preview and platform share/download fallback for PDFs and non-image files.
- Added actionable 403 mapping: “You don’t have access to this file.”

## Verification

- `flutter test test/core/errors/app_failure_test.dart test/features/credentials/evidence_documents_test.dart` — passed (10 tests).
- `flutter analyze` remains blocked by the pre-existing `JobsController.openFormTemplates` undefined getter in `jobs_list_view.dart`; no new analyzer errors were reported.
