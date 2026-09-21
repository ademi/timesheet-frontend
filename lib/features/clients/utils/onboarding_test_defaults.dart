import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/client_onboarding_controller.dart';
import '../widgets/onboarding/onboarding_preferences_step.dart';

/// TEMP — local create-client form testing.
///
/// Reverse when done:
/// 1. Set [kFillOnboardingTestDefaults] to `false`, **or**
/// 2. Delete this file and remove its import/call from
///    `ClientOnboardingController.onInit`.
///
/// Never runs in release builds ([kDebugMode] gate).
const kFillOnboardingTestDefaults = true;

/// Prefills wizard fields with AU-ish sample data so you can click through.
///
/// Skips when [Get.testMode] is on (unit/widget tests). Does not fake address
/// geocode confirmation — still tap Look up + Confirm on the Address step.
void applyOnboardingTestDefaults(ClientOnboardingController c) {
  if (!kDebugMode) return;
  if (!kFillOnboardingTestDefaults) return;
  if (Get.testMode) return;
  if (c.client.value != null) return;

  // Identity
  c.fullName.text = 'Alex Test Participant';
  c.email.text = 'alex.test@example.com';
  c.phone.text = '+61412345678';
  c.dob.value = DateTime(1990, 5, 15);
  c.sexGender.value = 'Female';
  c.referralSource.value = 'Self Referred';
  c.atsiStatus.value = 'No';
  c.allergiesCtrl.text = 'Peanuts';
  c.medicareCtrl.text = '1234567890';
  c.companionCardNumberCtrl.text = 'CC-1001';
  c.pensionCardNumberCtrl.text = 'PC-2002';
  c.photoIdNumberCtrl.text = 'P1234567';

  // Address (Look up + Confirm still required)
  c.siteNameCtrl.text = 'Home';
  c.siteAddressCtrl.text = '1 Campbell avenue';
  c.siteCityCtrl.text = 'Sydney';
  c.siteState.value = 'NSW';
  c.siteStateCtrl.text = 'NSW';
  c.sitePostalCtrl.text = '2000';
  c.siteAccessNotesCtrl.text = 'Gate code 1234';

  // Preferences
  c.preferredLanguageCtrl.text = 'English';
  c.culturalPreferencesCtrl.text = 'Prefers female workers for personal care';
  c.homeVisitConsent.value = true;
  c.swGenderPreference.value =
      OnboardingPreferencesStep.swGenderOptions.first;
  c.interpreterRequired.value = false;
  c.preferredContactMethod.value =
      OnboardingPreferencesStep.contactMethodOptions.first;

  // Contacts draft (emergency) — save on that step if desired
  c.contactNameCtrl.text = 'Sam Emergency';
  c.contactEmailCtrl.text = 'sam.emergency@example.com';
  c.contactPhoneCtrl.text = '+61487654321';
  c.contactRelationshipPreset.value = 'mother';
  c.contactIsEmergency.value = true;
  c.contactIsPrimary.value = true;
  c.contactDraftMode.value = 'emergency';

  // Support Plan
  c.ndisCtrl.text = '430123456';
  c.planManagementType.value = 'self_managed';
  c.planStartDate.value = DateTime(2025, 1, 1);
  c.planEndDate.value = DateTime(2026, 12, 31);
  c.budgetCoreCtrl.text = '12000';
  c.budgetCbCtrl.text = '5000';
  c.budgetCapitalCtrl.text = '0';
  c.supportPlanOtherCtrl.text = 'Prefers morning visits';
}
