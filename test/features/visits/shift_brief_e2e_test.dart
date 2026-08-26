/// Contractor shift-brief E2E — VM / CI entry (Task 11).
///
/// Same suite as [integration_test/shift_brief_e2e_test.dart]. Prefer this
/// command when Linux desktop deps (libsecret) or a device are unavailable:
///
///   cd frontend && flutter test test/features/visits/shift_brief_e2e_test.dart
library;

import 'package:flutter_test/flutter_test.dart';

import 'helpers/shift_brief_e2e_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  declareShiftBriefContractorE2e();
}
