/// Contractor shift-brief E2E — device entry (Task 11 / CR4).
///
/// Focused visit-detail slice: mocked [VisitsRepository] →
/// [VisitShiftBriefController.load] → [ShiftBriefPanel] (same wiring as
/// [ContractorVisitDetailView]). Full app pump omitted.
///
/// Device (needs desktop plugins, e.g. `libsecret-1-dev` on Linux):
///   cd frontend && flutter test integration_test/shift_brief_e2e_test.dart -d linux
///
/// VM / CI (identical asserts, no device build):
///   cd frontend && flutter test test/features/visits/shift_brief_e2e_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/visits/shift_brief_e2e_shared.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  declareShiftBriefContractorE2e();
}
