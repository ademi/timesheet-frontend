/// Staff client-archive E2E — VM / CI entry (Task 8).
///
/// Same suite as [integration_test/client_archive_e2e_test.dart]. Prefer this
/// command when Linux desktop deps (libsecret) or a device are unavailable:
///
///   cd frontend && flutter test test/features/clients/client_archive_e2e_test.dart
library;

import 'package:flutter_test/flutter_test.dart';

import 'helpers/client_archive_e2e_shared.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  declareClientArchiveStaffE2e();
}
