/// Canonical JSON keys / enum values for participant support plans.
abstract final class SupportPlanKeys {
  SupportPlanKeys._();

  // Top-level body sections
  static const disabilityHealth = 'disability_health';
  static const living = 'living';
  static const goals = 'goals';
  static const serviceCategories = 'service_categories';
  static const preferences = 'preferences';
  static const risk = 'risk';
  static const schedule = 'schedule';

  // Status
  static const statusDraft = 'draft';
  static const statusActive = 'active';
  static const statusArchived = 'archived';

  // Support intensity
  static const intensityStandard = 'standard';
  static const intensityComplex = 'complex';
  static const intensityIntense = 'intense';

  // Residence
  static const residencePrivateHome = 'private_home';
  static const residenceUnit = 'unit';
  static const residenceSharedLiving = 'shared_living';
  static const residenceSupportedAccommodation = 'supported_accommodation';
  static const residenceAgedCare = 'aged_care';
  static const residenceCaravanPark = 'caravan_park';
  static const residenceOther = 'other';

  // Functional limitations
  static const limitationHearing = 'hearing';
  static const limitationSpeech = 'speech';
  static const limitationVision = 'vision';
  static const limitationMobility = 'mobility';
  static const limitationSwallowing = 'swallowing';
  static const limitationBreathing = 'breathing';
  static const limitationCognition = 'cognition';
  static const limitationAdls = 'adls';
  static const limitationOther = 'other';
  static const limitationOtherDetail = 'limitation_other_detail';

  // Communication methods
  static const commVerbal = 'verbal';
  static const commWritten = 'written';
  static const commAuslan = 'auslan';
  static const commSignLanguage = 'sign_language';
  static const commPicture = 'picture_communication';
  static const commGesture = 'gesture';
  static const commAssistiveTech = 'assistive_technology';
  static const commOther = 'other';
  static const commOtherDetail = 'comm_other_detail';

  // Service categories
  static const catHomemaking = 'homemaking';
  static const catPersonalCare = 'personal_care';
  static const catCompanion = 'companion';
  static const catCommunityAccess = 'community_access';
  static const catTransport = 'transport';
  static const catOther = 'other';
  static const catOtherDetail = 'cat_other_detail';

  // Other detail (living)
  static const residenceOtherDetail = 'residence_other_detail';
}
