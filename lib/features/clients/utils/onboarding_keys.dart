/// Canonical requirement_key / relationship constants for client onboarding.
class OnboardingKeys {
  static const ndis = 'ndis';
  static const medicareCard = 'medicare_card';
  static const sexGender = 'sex_gender';
  static const atsiStatus = 'atsi_status';
  static const referralSource = 'referral_source';
  static const allergies = 'allergies';
  static const preferredLanguage = 'preferred_language';
  static const culturalPreferences = 'cultural_preferences';
  static const homeVisitConsent = 'home_visit_consent';
  static const swGenderPreference = 'support_worker_gender_preference';
  static const interpreterRequired = 'interpreter_required';
  static const interpreterLanguage = 'interpreter_language';
  static const preferredContactMethod = 'preferred_contact_method';
  static const planManagementType = 'plan_management_type';
  static const planManagerName = 'plan_manager_name';
  static const planManagerPhone = 'plan_manager_phone';
  static const planManagerEmail = 'plan_manager_email';
  static const planStartDate = 'plan_start_date';
  static const planEndDate = 'plan_end_date';
  static const budgetCore = 'budget_core';
  static const budgetCb = 'budget_cb';
  static const budgetCapital = 'budget_capital';
  static const fundingNotToExceed = 'funding_not_to_exceed';
  static const supportCoordinatorName = 'support_coordinator_name';
  static const supportCoordinatorPhone = 'support_coordinator_phone';
  static const supportCoordinatorEmail = 'support_coordinator_email';
  static const preferredClaimingMethod = 'preferred_claiming_method';
  static const preferredClaimingOtherDetail = 'preferred_claiming_other_detail';
  static const infoShareConsent = 'info_share_consent';
  static const specificSupportsConsent = 'specific_supports_consent';
  static const consentAgreement = 'consent_agreement'; // requirement_key for accept path
  static const consentAgreementDocKey =
      'patient.consent_agreement'; // legal documents catalog
  static const serviceAgreement = 'service_agreement';
  static const acknowledgement = 'acknowledgement';

  /// Profile field keys owned by Care plan Funding/Consent (hide from Profile drafts).
  static const carePlanOwnedFundingKeys = <String>{
    planManagementType,
    planManagerName,
    planManagerPhone,
    planManagerEmail,
    planStartDate,
    planEndDate,
    budgetCore,
    budgetCb,
    budgetCapital,
    fundingNotToExceed,
    supportCoordinatorName,
    supportCoordinatorPhone,
    supportCoordinatorEmail,
    preferredClaimingMethod,
    preferredClaimingOtherDetail,
    infoShareConsent,
    specificSupportsConsent,
  };

  static const relEmergency = 'emergency';
  static const relCarer = 'carer';
  static const relChildRepresentative = 'child_representative';
  static const relNominee = 'nominee';
}
