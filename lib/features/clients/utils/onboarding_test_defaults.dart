import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../controllers/client_onboarding_controller.dart';
import '../models/support_plan_specialist_entry.dart';
import '../models/support_plan_specialist_types.dart';
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

  // ── Identity ──────────────────────────────────────────────────────────
  c.fullName.text = 'Alex Test Participant';
  c.email.text = 'alex.test@example.com';
  c.phone.text = '+61412345678';
  c.dob.value = DateTime(1990, 5, 15);
  c.sexGender.value = 'Female';
  c.referralSource.value = 'Self Referred';
  c.atsiStatus.value = 'No';
  c.medicareCtrl.text = '1234567890';
  c.companionCardNumberCtrl.text = 'CC-1001';
  c.disabilityCardNumberCtrl.text = 'DC-3003';
  c.pensionCardNumberCtrl.text = 'PC-2002';
  c.photoIdNumberCtrl.text = 'P1234567';

  // ── Address (Look up + Confirm still required) ────────────────────────
  c.siteNameCtrl.text = 'Home';
  c.siteAddressCtrl.text = '1 Campbell Avenue';
  c.siteCityCtrl.text = 'Sydney';
  c.siteState.value = 'NSW';
  c.siteStateCtrl.text = 'NSW';
  c.sitePostalCtrl.text = '2000';
  c.siteAccessNotesCtrl.text = 'Gate code 1234';

  // ── Preferences ───────────────────────────────────────────────────────
  c.preferredLanguageCtrl.text = 'English';
  c.interpreterRequired.value = false;
  c.homeVisitConsent.value = true;
  c.preferredContactMethod.value =
      OnboardingPreferencesStep.contactMethodOptions.first;
  c.swGenderPreference.value =
      OnboardingPreferencesStep.swGenderOptions.first;
  c.culturalPreferencesCtrl.text = 'Prefers female workers for personal care';

  // ── Contacts (emergency draft — save on that step if desired) ─────────
  c.contactNameCtrl.text = 'Sam Emergency';
  c.contactEmailCtrl.text = 'sam.emergency@example.com';
  c.contactPhoneCtrl.text = '+61487654321';
  c.contactRelationshipPreset.value = 'mother';
  c.contactIsEmergency.value = true;
  c.contactIsPrimary.value = true;
  c.contactDraftMode.value = 'emergency';

  // ── NDIS ──────────────────────────────────────────────────────────────
  c.ndisCtrl.text = '430123456';
  c.planManagementType.value = 'self_managed';
  c.planStartDate.value = DateTime(2025, 1, 1);
  c.planEndDate.value = DateTime(2026, 12, 31);
  c.budgetCoreCtrl.text = '12000';
  c.budgetCbCtrl.text = '5000';
  c.budgetCapitalCtrl.text = '0';
  c.budgetOtherLabelCtrl.text = 'Transport';
  c.budgetOtherCtrl.text = '800';

  // ── Care plan ─────────────────────────────────────────────────────────
  c.allergiesCtrl.text = 'Peanuts';
  c.primaryDisabilityCtrl.text = 'Autism Spectrum Disorder';
  c.supportPlanOtherCtrl.text = 'Prefers morning visits';
  c.infoShareConsent.value = true;
  c.specificSupportsConsent.value = true;

  // ── Support Coordinator ───────────────────────────────────────────────
  final sc = c.supportCoordinatorEntry.fields;
  sc.nameCtrl.text = 'Jordan SC';
  sc.companyCtrl.text = 'Connect Coordinators';
  sc.abnAcnCtrl.text = '12 345 678 901';
  sc.orgIdCtrl.text = 'ORG-SC-001';
  sc.phoneCtrl.text = '+61411112222';
  sc.emailCtrl.text = 'jordan.sc@example.com';
  sc.addressCtrl.text = '10 Support St, Sydney NSW 2000';
  c.supportCoordinatorEntry.revision.value++;

  // ── Support Specialists ───────────────────────────────────────────────
  final ot = SupportPlanSpecialistEntry.create(
    SupportPlanSpecialistTypes.occupationalTherapist,
    expanded: true,
  );
  ot.fields.nameCtrl.text = 'Casey OT';
  ot.fields.companyCtrl.text = 'Allied Health Partners';
  ot.fields.phoneCtrl.text = '+61433334444';
  ot.fields.emailCtrl.text = 'casey.ot@example.com';
  c.supportSpecialists.assignAll([ot]);
}
