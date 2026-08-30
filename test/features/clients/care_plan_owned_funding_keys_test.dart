import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/controllers/clients_controller.dart';
import 'package:rostiq/features/clients/utils/clinical_keys.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';

void main() {
  test('Care-plan-owned funding keys hide from Profile drafts', () {
    expect(
      ClientsController.isCarePlanOwnedFundingRequirement(
        OnboardingKeys.planManagementType,
      ),
      isTrue,
    );
    expect(
      ClientsController.isCarePlanOwnedFundingRequirement(
        OnboardingKeys.preferredClaimingMethod,
      ),
      isTrue,
    );
    expect(
      ClientsController.isCarePlanOwnedFundingRequirement(
        OnboardingKeys.infoShareConsent,
      ),
      isTrue,
    );
    // Legal PDFs stay on Profile
    expect(
      ClientsController.isCarePlanOwnedFundingRequirement(
        OnboardingKeys.consentAgreement,
      ),
      isFalse,
    );
    expect(ClientsController.isOverviewOwnedRequirement('ndis'), isTrue);
  });

  test('Care-plan-owned clinical keys hide from Profile drafts', () {
    expect(
      ClientsController.isCarePlanOwnedClinicalRequirement(
        ClinicalKeys.bspOnFile,
      ),
      isTrue,
    );
    expect(
      ClientsController.isCarePlanOwnedClinicalRequirement(
        ClinicalKeys.behaviourSupportPlanDoc,
      ),
      isTrue,
    );
    expect(
      ClientsController.isCarePlanOwnedClinicalRequirement(
        ClinicalKeys.medicalReport,
      ),
      isFalse,
    );
  });
}
