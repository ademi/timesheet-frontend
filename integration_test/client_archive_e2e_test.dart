/// Staff client-archive E2E — device entry (Task 8 / eng-review D16=C).
///
/// Focused client-detail slice: mocked [ClientsRepository] →
/// [ClientsController.deleteClient] → [ClientDetailView] archive chrome.
///
/// Device (needs desktop plugins, e.g. `libsecret-1-dev` on Linux):
///   cd frontend && flutter test integration_test/client_archive_e2e_test.dart -d linux
///
/// VM / CI (identical asserts, no device build):
///   cd frontend && flutter test test/features/clients/client_archive_e2e_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/clients/helpers/client_archive_e2e_shared.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  declareClientArchiveStaffE2e();
}
