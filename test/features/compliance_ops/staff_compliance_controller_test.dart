import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/compliance_ops/controllers/staff_compliance_controller.dart';
import 'package:rostiq/features/compliance_ops/data/repositories/compliance_ops_repository.dart';
import 'package:rostiq/features/credentials/data/repositories/credentials_repository.dart';
import 'package:rostiq/features/engagements/data/models/engagement_models.dart';
import 'package:rostiq/features/engagements/data/repositories/engagements_repository.dart';

class _MockComplianceOpsRepository extends Mock
    implements ComplianceOpsRepository {}

class _MockCredentialsRepository extends Mock
    implements CredentialsRepository {}

class _MockEngagementsRepository extends Mock
    implements EngagementsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  test(
    'loads unique contractors and uses the selected contractor for credentials',
    () async {
      final compliance = _MockComplianceOpsRepository();
      final credentials = _MockCredentialsRepository();
      final engagements = _MockEngagementsRepository();
      final session = _MockSessionService();
      final contractor = EngagementOut(
        id: 'engagement-1',
        tenantId: 'tenant-1',
        contractorId: 'contractor-1',
        contractorName: 'Ada Lovelace',
        status: 'active',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      when(() => session.hasPermission(any())).thenReturn(true);
      when(() => engagements.listTenantEngagements()).thenAnswer(
        (_) async => [
          contractor,
          EngagementOut(
            id: 'engagement-2',
            tenantId: 'tenant-1',
            contractorId: 'contractor-1',
            contractorName: 'Ada Lovelace',
            status: 'active',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      );
      when(
        () => credentials.listForTenantContractor('contractor-1'),
      ).thenAnswer((_) async => []);
      final controller = StaffComplianceController(
        repository: compliance,
        credentialsRepository: credentials,
        engagementsRepository: engagements,
        session: session,
      );

      await controller.loadContractors();
      controller.selectContractor(controller.contractorOptions.single);
      await controller.loadContractorCredentials();

      expect(controller.contractorOptions, hasLength(1));
      expect(
        controller.contractorOptions.single.contractorName,
        'Ada Lovelace',
      );
      verify(
        () => credentials.listForTenantContractor('contractor-1'),
      ).called(1);
    },
  );
}
