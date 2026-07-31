import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/features/shell/contractor_shell.dart';

void main() {
  group('ContractorShellNav.selectedIndex', () {
    test('maps each primary contractor route to its tab', () {
      expect(ContractorShellNav.selectedIndex(AppRoutes.contractorHome), 0);
      expect(ContractorShellNav.selectedIndex(AppRoutes.contractorVisits), 1);
      expect(ContractorShellNav.selectedIndex(AppRoutes.contractorSchedule), 2);
      expect(
        ContractorShellNav.selectedIndex(AppRoutes.contractorCredentials),
        3,
      );
      expect(ContractorShellNav.selectedIndex(AppRoutes.contractorProfile), 4);
    });

    test('keeps nested visit and credential routes on their parent tabs', () {
      expect(
        ContractorShellNav.selectedIndex(AppRoutes.contractorVisitDetail),
        1,
      );
      expect(
        ContractorShellNav.selectedIndex(AppRoutes.contractorCredentialCreate),
        3,
      );
      expect(
        ContractorShellNav.selectedIndex(AppRoutes.contractorCredentialDetail),
        3,
      );
    });
  });
}
