/// Canonical requirement_key / relationship constants for client onboarding.
class OnboardingKeys {
  static const ndis = 'ndis';
  static const medicareCard = 'medicare_card';
  static const companionCard = 'companion_card';
  static const disabilityCard = 'disability_card';
  static const pensionCard = 'pension_card';
  static const photoId = 'photo_id';
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
  static const supportPlanOther = 'support_plan_other';
  static const planManagerName = 'plan_manager_name';
  static const planManagerCompany = 'plan_manager_company';
  static const planManagerAbnAcn = 'plan_manager_abn_acn';
  static const planManagerOrgId = 'plan_manager_org_id';
  static const planManagerPhone = 'plan_manager_phone';
  static const planManagerEmail = 'plan_manager_email';
  static const planManagerAddress = 'plan_manager_address';
  static const planStartDate = 'plan_start_date';
  static const planEndDate = 'plan_end_date';
  static const budgetCore = 'budget_core';
  static const budgetCb = 'budget_cb';
  static const budgetCapital = 'budget_capital';
  static const fundingNotToExceed = 'funding_not_to_exceed';
  static const supportCoordinatorName = 'support_coordinator_name';
  static const supportCoordinatorCompany = 'support_coordinator_company';
  static const supportCoordinatorAbnAcn = 'support_coordinator_abn_acn';
  static const supportCoordinatorOrgId = 'support_coordinator_org_id';
  static const supportCoordinatorPhone = 'support_coordinator_phone';
  static const supportCoordinatorEmail = 'support_coordinator_email';
  static const supportCoordinatorAddress = 'support_coordinator_address';
  static const behaviouralTherapistName = 'behavioural_therapist_name';
  static const behaviouralTherapistCompany = 'behavioural_therapist_company';
  static const behaviouralTherapistAbnAcn = 'behavioural_therapist_abn_acn';
  static const behaviouralTherapistOrgId = 'behavioural_therapist_org_id';
  static const behaviouralTherapistPhone = 'behavioural_therapist_phone';
  static const behaviouralTherapistEmail = 'behavioural_therapist_email';
  static const behaviouralTherapistAddress = 'behavioural_therapist_address';
  static const speechTherapistName = 'speech_therapist_name';
  static const speechTherapistCompany = 'speech_therapist_company';
  static const speechTherapistAbnAcn = 'speech_therapist_abn_acn';
  static const speechTherapistOrgId = 'speech_therapist_org_id';
  static const speechTherapistPhone = 'speech_therapist_phone';
  static const speechTherapistEmail = 'speech_therapist_email';
  static const speechTherapistAddress = 'speech_therapist_address';
  static const occupationalTherapistName = 'occupational_therapist_name';
  static const occupationalTherapistCompany = 'occupational_therapist_company';
  static const occupationalTherapistAbnAcn = 'occupational_therapist_abn_acn';
  static const occupationalTherapistOrgId = 'occupational_therapist_org_id';
  static const occupationalTherapistPhone = 'occupational_therapist_phone';
  static const occupationalTherapistEmail = 'occupational_therapist_email';
  static const occupationalTherapistAddress = 'occupational_therapist_address';
  static const physiotherapistName = 'physiotherapist_name';
  static const physiotherapistCompany = 'physiotherapist_company';
  static const physiotherapistAbnAcn = 'physiotherapist_abn_acn';
  static const physiotherapistOrgId = 'physiotherapist_org_id';
  static const physiotherapistPhone = 'physiotherapist_phone';
  static const physiotherapistEmail = 'physiotherapist_email';
  static const physiotherapistAddress = 'physiotherapist_address';
  static const preferredClaimingMethod = 'preferred_claiming_method';
  static const preferredClaimingOtherDetail = 'preferred_claiming_other_detail';
  static const infoShareConsent = 'info_share_consent';
  static const specificSupportsConsent = 'specific_supports_consent';
  static const consentAgreement = 'consent_agreement';
  static const consentAgreementDocKey = 'patient.consent_agreement';
  static const serviceAgreement = 'service_agreement';
  static const acknowledgement = 'acknowledgement';

  /// Profile field keys owned by Care plan Funding/Consent (hide from Profile drafts).
  static const carePlanOwnedFundingKeys = <String>{
    ndis,
    supportPlanOther,
    planManagementType,
    planManagerName,
    planManagerCompany,
    planManagerAbnAcn,
    planManagerOrgId,
    planManagerPhone,
    planManagerEmail,
    planManagerAddress,
    planStartDate,
    planEndDate,
    budgetCore,
    budgetCb,
    budgetCapital,
    fundingNotToExceed,
    supportCoordinatorName,
    supportCoordinatorCompany,
    supportCoordinatorAbnAcn,
    supportCoordinatorOrgId,
    supportCoordinatorPhone,
    supportCoordinatorEmail,
    supportCoordinatorAddress,
    behaviouralTherapistName,
    behaviouralTherapistCompany,
    behaviouralTherapistAbnAcn,
    behaviouralTherapistOrgId,
    behaviouralTherapistPhone,
    behaviouralTherapistEmail,
    behaviouralTherapistAddress,
    speechTherapistName,
    speechTherapistCompany,
    speechTherapistAbnAcn,
    speechTherapistOrgId,
    speechTherapistPhone,
    speechTherapistEmail,
    speechTherapistAddress,
    occupationalTherapistName,
    occupationalTherapistCompany,
    occupationalTherapistAbnAcn,
    occupationalTherapistOrgId,
    occupationalTherapistPhone,
    occupationalTherapistEmail,
    occupationalTherapistAddress,
    physiotherapistName,
    physiotherapistCompany,
    physiotherapistAbnAcn,
    physiotherapistOrgId,
    physiotherapistPhone,
    physiotherapistEmail,
    physiotherapistAddress,
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
