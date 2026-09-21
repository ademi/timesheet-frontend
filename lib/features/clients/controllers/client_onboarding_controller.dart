import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/constants/australian_states.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/models/client_models.dart';
import '../data/models/client_profile_models.dart';
import '../models/identity_card_attachment.dart';
import '../models/legal_other_document.dart';
import '../models/support_plan_specialist_entry.dart';
import '../models/support_plan_specialist_types.dart';
import '../data/repositories/clients_repository.dart';
import '../services/client_legal_upload_helper.dart';
import '../utils/onboarding_age.dart';
import '../utils/ndis_plan_budgets_codec.dart';
import '../utils/support_plan_specialists_codec.dart';
import '../utils/onboarding_keys.dart';
import '../utils/onboarding_test_defaults.dart';
import '../utils/site_geocode_apply.dart';
import '../widgets/contact_form_host.dart';
import '../widgets/onboarding/onboarding_identity_step.dart';
import '../widgets/site_form_host.dart';
import 'clients_controller.dart';
import 'support_plan_clinical_store.dart';

/// Modular client onboarding wizard (Identity → … → Legal).
class ClientOnboardingController extends GetxController
    implements SiteFormHost, ContactFormHost {
  ClientOnboardingController({
    required ClientsRepository repository,
    required SessionService session,
    DocumentPipeline? documentPipeline,
    Future<({String name, List<int> bytes})?> Function()? pickPdfBytes,
    Future<PendingIdentityCardFile?> Function()? pickCardFile,
    this.softGateConfirm,
    this.onFinished,
  }) : _repository = repository,
       _session = session,
       _pipeline = documentPipeline,
       _pickPdfBytesOverride = pickPdfBytes,
       _pickCardFileOverride = pickCardFile;

  final ClientsRepository _repository;
  final SessionService _session;
  final DocumentPipeline? _pipeline;
  final Future<({String name, List<int> bytes})?> Function()?
  _pickPdfBytesOverride;
  final Future<PendingIdentityCardFile?> Function()? _pickCardFileOverride;

  /// Requirement keys loaded from the server (D10: skip empty clears).
  final _presentKeys = <String>{};
  final _factUpdatedAt = <String, DateTime>{};

  /// Injectable soft-gate dialog for tests.
  Future<bool> Function(List<String> missing)? softGateConfirm;

  /// Called after finish instead of navigation when set (tests).
  void Function(String clientId)? onFinished;

  static const maxStep = 8;
  static const stepLabels = [
    'Identity',
    'Address',
    'Preferences',
    'Contacts',
    'NDIS',
    'Care plan',
    'Support Coordinator',
    'Support Specialists',
    'Legal',
  ];

  final step = 0.obs;
  final client = Rxn<ClientOut>();
  final errorMessage = RxnString();
  final isSaving = false.obs;
  final ndisFieldError = RxnString();
  final budgetFieldError = RxnString();
  final consentUploading = false.obs;
  final serviceAgreementUploading = false.obs;
  final acknowledgementUploading = false.obs;
  /// Row ids currently uploading a legal-other PDF.
  final legalOtherUploading = <String>{}.obs;

  // ── Identity ──────────────────────────────────────────────────────────
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final ndisCtrl = TextEditingController();
  final medicareCtrl = TextEditingController();
  final medicareCardAttachment = IdentityCardAttachment();
  final companionCardAttachment = IdentityCardAttachment();
  final disabilityCardAttachment = IdentityCardAttachment();
  final pensionCardAttachment = IdentityCardAttachment();
  final companionCardNumberCtrl = TextEditingController();
  final disabilityCardNumberCtrl = TextEditingController();
  final pensionCardNumberCtrl = TextEditingController();
  final photoIdAttachment = IdentityCardAttachment();
  final photoIdNumberCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
  final referralOtherCtrl = TextEditingController();
  final sexGenderOtherCtrl = TextEditingController();
  final dob = Rxn<DateTime>();
  final sexGender = RxnString();
  final atsiStatus = RxnString();
  final referralSource = RxnString();
  final pendingPhoto = Rxn<PickedProfilePhoto>();
  final localPhotoBytes = Rxn<List<int>>();

  // ── Site (SiteFormHost) ───────────────────────────────────────────────
  @override
  final siteNameCtrl = TextEditingController();
  @override
  final siteAddressCtrl = TextEditingController();
  @override
  final siteCityCtrl = TextEditingController();
  @override
  final siteStateCtrl = TextEditingController(text: kDefaultAustralianState);
  @override
  final sitePostalCtrl = TextEditingController();
  @override
  final siteAccessNotesCtrl = TextEditingController();
  @override
  final siteLatCtrl = TextEditingController();
  @override
  final siteLngCtrl = TextEditingController();
  @override
  final siteIsPrimary = true.obs;
  @override
  final isGeocoding = false.obs;
  @override
  final geocodeFormattedAddress = RxnString();
  @override
  final addressConfirmed = false.obs;
  @override
  final siteCountry = 'AU'.obs;
  @override
  final siteState = kDefaultAustralianState.obs;
  final primarySiteSaved = false.obs;

  // ── Preferences ───────────────────────────────────────────────────────
  final preferredLanguageCtrl = TextEditingController();
  final culturalPreferencesCtrl = TextEditingController();
  final interpreterLanguageCtrl = TextEditingController();
  final homeVisitConsent = false.obs;
  final swGenderPreference = RxnString();
  final interpreterRequired = false.obs;
  final preferredContactMethod = RxnString();

  // ── Contacts (ContactFormHost) ────────────────────────────────────────
  @override
  final contactNameCtrl = TextEditingController();
  @override
  final contactEmailCtrl = TextEditingController();
  @override
  final contactPhoneCtrl = TextEditingController();
  @override
  final contactRelationshipOtherCtrl = TextEditingController();
  @override
  final contactRelationshipPreset = RxnString();
  @override
  final contactIsPrimary = false.obs;
  @override
  final contactIsEmergency = true.obs;
  final emergencySaved = false.obs;
  final reuseEmergencyContactId = RxnString();
  final carerSaved = false.obs;
  final contactsCreated = <ClientContactOut>[].obs;
  final contactDraftMode = 'emergency'.obs; // emergency | carer | more

  @override
  String? get resolvedContactRelationship {
    final preset = contactRelationshipPreset.value;
    if (preset == null || preset.isEmpty) return null;
    if (preset == ContactFormHost.relationshipOtherKey) {
      final other = contactRelationshipOtherCtrl.text.trim();
      return other.isEmpty ? null : other;
    }
    return preset;
  }

  String? get resolvedReferralSource {
    final preset = referralSource.value;
    if (preset == null || preset.isEmpty) return null;
    if (preset == OnboardingIdentityStep.otherPresetKey) {
      final other = referralOtherCtrl.text.trim();
      return other.isEmpty ? null : other;
    }
    return preset;
  }

  String? get resolvedSexGender {
    final preset = sexGender.value;
    if (preset == null || preset.isEmpty) return null;
    if (preset == OnboardingIdentityStep.otherPresetKey) {
      final other = sexGenderOtherCtrl.text.trim();
      return other.isEmpty ? null : other;
    }
    return preset;
  }

  // ── Representative ────────────────────────────────────────────────────
  final representativeSaved = false.obs;
  final nomineeSkipped = false.obs;
  final representativeEditing = false.obs;
  final savedRepresentativeContact = Rxn<ClientContactOut>();

  // ── Support Plan ──────────────────────────────────────────────────────
  final ndisPdfAttachment = IdentityCardAttachment();
  final planManagementType = RxnString();
  final planManagerNameCtrl = TextEditingController();
  final planManagerCompanyCtrl = TextEditingController();
  final planManagerAbnAcnCtrl = TextEditingController();
  final planManagerOrgIdCtrl = TextEditingController();
  final planManagerPhoneCtrl = TextEditingController();
  final planManagerEmailCtrl = TextEditingController();
  final planManagerAddressCtrl = TextEditingController();
  final planStartDate = Rxn<DateTime>();
  final planEndDate = Rxn<DateTime>();
  final budgetCoreCtrl = TextEditingController();
  final budgetCbCtrl = TextEditingController();
  final budgetCapitalCtrl = TextEditingController();
  final budgetOtherLabelCtrl = TextEditingController();
  final budgetOtherCtrl = TextEditingController();
  final supportPlanOtherCtrl = TextEditingController();
  final supportSpecialists = <SupportPlanSpecialistEntry>[].obs;
  final supportCoordinatorEntry = SupportPlanSpecialistEntry.create(
    SupportPlanSpecialistTypes.supportCoordinator,
  );
  final primaryDisabilityCtrl = TextEditingController();
  final infoShareConsent = false.obs;
  final specificSupportsConsent = false.obs;
  late final SupportPlanClinicalStore clinical = SupportPlanClinicalStore(
    repository: _repository,
    documentPipeline: _pipeline,
    pickPdfBytes: _pickPdfBytesOverride,
    canUploadDocs: () => canUploadDocs,
  );

  // ── Legal pack ────────────────────────────────────────────────────────
  final consentComplete = false.obs;
  final serviceAgreementComplete = false.obs;
  final acknowledgementComplete = false.obs;
  final includeAcknowledgement = false.obs;
  final consentSignerNameCtrl = TextEditingController();
  final legalOtherDocs = <LegalOtherDocumentDraft>[].obs;
  final formTemplates = <FormTemplateSummary>[].obs;
  final isLoadingTemplates = false.obs;
  FormTemplateSummary? get acknowledgementTemplate {
    for (final t in formTemplates) {
      if (t.isAcknowledgementPack) return t;
    }
    return null;
  }

  String? get clientId => client.value?.id;

  bool get canUploadDocs =>
      _session.hasPermission(AppPermissions.documentsUpload) ||
      _session.hasPermission(AppPermissions.clientsDocsManage);

  bool get requiresChildRepresentative =>
      dob.value != null && isUnder18(dob.value!);

  bool get nomineeOptional => !requiresChildRepresentative;

  String get representativeStepTitle =>
      requiresChildRepresentative
          ? 'Representative'
          : 'Representative (optional)';

  String get representativeRoleChipLabel =>
      requiresChildRepresentative ? 'Representative' : 'Nominee';

  bool get showSkipCarer =>
      step.value == 3 &&
      emergencySaved.value &&
      !carerSaved.value &&
      contactDraftMode.value == 'carer';

  bool get showSkipNominee => false;

  ClientContactOut? get selectedExistingEmergencyContact {
    final id = reuseEmergencyContactId.value;
    if (id == null) return null;
    for (final c in contactsCreated) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool get showNewRepresentativeContactForm =>
      reuseEmergencyContactId.value == null;

  @override
  void onInit() {
    super.onInit();
    contactRelationshipPreset.value = null;
    contactIsEmergency.value = true;
    contactDraftMode.value = 'emergency';
    loadFormTemplates();
    final args = Get.arguments;
    // Resume hydrate is owned by [ClientOnboardingBinding] so put + binding
    // do not both fire unawaited [hydrateFromClient].
    if (args is! ClientOut) {
      // TEMP: delete import + this call (and onboarding_test_defaults.dart) when done.
      applyOnboardingTestDefaults(this);
    }
  }

  /// Clears non-Identity step state from a prior wizard session so resume
  /// hydrate does not carry stale flags, contacts, or funding fields.
  void resetForResume() {
    errorMessage.value = null;
    ndisFieldError.value = null;
    isSaving.value = false;

    medicareCtrl.clear();
    medicareCardAttachment.reset();
    companionCardAttachment.reset();
    companionCardNumberCtrl.clear();
    disabilityCardAttachment.reset();
    disabilityCardNumberCtrl.clear();
    pensionCardAttachment.reset();
    pensionCardNumberCtrl.clear();
    photoIdAttachment.reset();
    photoIdNumberCtrl.clear();
    allergiesCtrl.clear();
    referralOtherCtrl.clear();
    sexGenderOtherCtrl.clear();
    sexGender.value = null;
    atsiStatus.value = null;
    referralSource.value = null;
    pendingPhoto.value = null;
    localPhotoBytes.value = null;

    siteNameCtrl.clear();
    siteAddressCtrl.clear();
    siteCityCtrl.clear();
    siteStateCtrl.text = kDefaultAustralianState;
    sitePostalCtrl.clear();
    siteAccessNotesCtrl.clear();
    siteLatCtrl.clear();
    siteLngCtrl.clear();
    siteIsPrimary.value = true;
    isGeocoding.value = false;
    geocodeFormattedAddress.value = null;
    addressConfirmed.value = false;
    siteCountry.value = 'AU';
    siteState.value = kDefaultAustralianState;
    primarySiteSaved.value = false;

    preferredLanguageCtrl.clear();
    culturalPreferencesCtrl.clear();
    homeVisitConsent.value = false;
    swGenderPreference.value = null;
    interpreterRequired.value = false;
    preferredContactMethod.value = null;

    emergencySaved.value = false;
    carerSaved.value = false;
    contactsCreated.clear();
    contactDraftMode.value = 'emergency';
    contactRelationshipPreset.value = null;
    reuseEmergencyContactId.value = null;
    _resetContactDraft();

    representativeSaved.value = false;
    nomineeSkipped.value = false;
    representativeEditing.value = false;
    savedRepresentativeContact.value = null;

    ndisCtrl.clear();
    ndisPdfAttachment.reset();
    planManagementType.value = null;
    planManagerNameCtrl.clear();
    planManagerCompanyCtrl.clear();
    planManagerAbnAcnCtrl.clear();
    planManagerOrgIdCtrl.clear();
    planManagerPhoneCtrl.clear();
    planManagerEmailCtrl.clear();
    planManagerAddressCtrl.clear();
    planStartDate.value = null;
    planEndDate.value = null;
    budgetCoreCtrl.clear();
    budgetCbCtrl.clear();
    budgetCapitalCtrl.clear();
    budgetOtherLabelCtrl.clear();
    budgetOtherCtrl.clear();
    supportPlanOtherCtrl.clear();
    primaryDisabilityCtrl.clear();
    infoShareConsent.value = false;
    specificSupportsConsent.value = false;
    supportCoordinatorEntry.fields.clear();
    supportCoordinatorEntry.customLabelCtrl.clear();
    clearSupportSpecialists();

    consentComplete.value = false;
    serviceAgreementComplete.value = false;
    acknowledgementComplete.value = false;
    includeAcknowledgement.value = false;
    consentSignerNameCtrl.clear();
    legalOtherDocs.clear();
    legalOtherUploading.clear();
    _presentKeys.clear();
    _factUpdatedAt.clear();
  }

  /// CR3 resume: set client/id, prefill Identity from [ClientOut], step 0,
  /// then load profile facts (identity cards, support plan, legal other docs).
  Future<void> hydrateFromClient(ClientOut existing) async {
    resetForResume();
    client.value = existing;
    fullName.text = existing.fullName;
    email.text = existing.email ?? '';
    phone.text = existing.phone ?? '';
    final rawDob = existing.dob?.trim();
    dob.value =
        (rawDob == null || rawDob.isEmpty) ? null : DateTime.tryParse(rawDob);
    step.value = 0;
    await _loadAndHydrateProfileFacts(existing.id);
  }

  /// Fetches the profile bundle and applies resume hydrates (soft on failure).
  Future<void> _loadAndHydrateProfileFacts(String clientId) async {
    if (clientId.isEmpty) return;
    try {
      final bundle = await _repository.getClientProfile(clientId);
      applyProfileFacts(bundle.facts);
    } on AppFailure catch (e) {
      errorMessage.value ??= e.message;
    } catch (_) {}
  }

  /// Applies stored profile facts to wizard fields (identity, support, legal).
  void applyProfileFacts(Iterable<ClientProfileFactOut> facts) {
    hydrateIdentityFromFacts(facts);
    hydrateSupportPlanFromFacts(facts);
    hydrateLegalOtherFromFacts(facts);
  }

  /// Applies stored profile facts to Identity fields (CR5 Other hydration).
  void hydrateIdentityFromFacts(Iterable<ClientProfileFactOut> facts) {
    _recordPresentFacts(facts);
    for (final fact in facts) {
      final stored = fact.valueJson?.toString();
      switch (fact.requirementKey) {
        case OnboardingKeys.referralSource:
          _applyHydratedReferral(stored);
        case OnboardingKeys.sexGender:
          _applyHydratedSexGender(stored);
        case OnboardingKeys.medicareCard:
          medicareCtrl.text = stored?.trim() ?? '';
          _hydrateCardAttachment(medicareCardAttachment, fact);
        case OnboardingKeys.companionCard:
          companionCardNumberCtrl.text = stored?.trim() ?? '';
          _hydrateCardAttachment(companionCardAttachment, fact);
        case OnboardingKeys.disabilityCard:
          disabilityCardNumberCtrl.text = stored?.trim() ?? '';
          _hydrateCardAttachment(disabilityCardAttachment, fact);
        case OnboardingKeys.pensionCard:
          pensionCardNumberCtrl.text = stored?.trim() ?? '';
          _hydrateCardAttachment(pensionCardAttachment, fact);
        case OnboardingKeys.photoId:
          _hydratePhotoId(stored, fact);
        case OnboardingKeys.allergies:
          allergiesCtrl.text = stored?.trim() ?? '';
        case OnboardingKeys.atsiStatus:
          atsiStatus.value = stored?.trim();
      }
    }
  }

  void _hydratePhotoId(String? stored, ClientProfileFactOut fact) {
    _hydrateCardAttachment(photoIdAttachment, fact);
    if (stored == null || stored.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(stored);
      if (decoded is Map) {
        photoIdNumberCtrl.text =
            decoded['number']?.toString() ?? decoded['id']?.toString() ?? '';
        return;
      }
    } catch (_) {
      // Plain string fallback.
    }
    photoIdNumberCtrl.text = stored.trim();
  }

  void _applyHydratedReferral(String? stored) {
    final hydrated = OnboardingIdentityStep.hydrateReferral(stored);
    referralSource.value = hydrated.preset;
    referralOtherCtrl.text = hydrated.otherText;
  }

  void _applyHydratedSexGender(String? stored) {
    final hydrated = OnboardingIdentityStep.hydrateSexGender(stored);
    sexGender.value = hydrated.preset;
    sexGenderOtherCtrl.text = hydrated.otherText;
  }

  void _hydrateCardAttachment(
    IdentityCardAttachment attachment,
    ClientProfileFactOut fact,
  ) {
    final docId = fact.documentId?.trim();
    if (docId == null || docId.isEmpty) return;
    attachment.existingDocumentId.value = docId;
    attachment.existingDocumentLabel.value = 'Document on file';
  }

  /// Applies stored profile facts to Support Plan fields (legacy Other fallback).
  void hydrateSupportPlanFromFacts(Iterable<ClientProfileFactOut> facts) {
    _recordPresentFacts(facts);
    final factsList =
        facts is List<ClientProfileFactOut> ? facts : facts.toList();
    String? otherText;
    String? legacyOther;
    for (final fact in facts) {
      final stored = fact.valueJson?.toString().trim();
      switch (fact.requirementKey) {
        case OnboardingKeys.ndis:
          ndisCtrl.text = stored ?? '';
          _hydrateCardAttachment(ndisPdfAttachment, fact);
        case OnboardingKeys.supportPlanOther:
          otherText = stored;
        case OnboardingKeys.fundingNotToExceed:
          legacyOther = stored;
        case OnboardingKeys.planManagementType:
          planManagementType.value = stored;
        case OnboardingKeys.planManagerName:
          planManagerNameCtrl.text = stored ?? '';
        case OnboardingKeys.planManagerCompany:
          planManagerCompanyCtrl.text = stored ?? '';
        case OnboardingKeys.planManagerAbnAcn:
          planManagerAbnAcnCtrl.text = stored ?? '';
        case OnboardingKeys.planManagerOrgId:
          planManagerOrgIdCtrl.text = stored ?? '';
        case OnboardingKeys.planManagerPhone:
          planManagerPhoneCtrl.text = stored ?? '';
        case OnboardingKeys.planManagerEmail:
          planManagerEmailCtrl.text = stored ?? '';
        case OnboardingKeys.planManagerAddress:
          planManagerAddressCtrl.text = stored ?? '';
        case OnboardingKeys.planStartDate:
          planStartDate.value = _parseHydratedDate(stored);
        case OnboardingKeys.planEndDate:
          planEndDate.value = _parseHydratedDate(stored);
        case OnboardingKeys.infoShareConsent:
          infoShareConsent.value = _parseHydratedBool(fact.valueJson);
        case OnboardingKeys.specificSupportsConsent:
          specificSupportsConsent.value = _parseHydratedBool(fact.valueJson);
      }
    }
    NdisPlanBudgetsCodec.applyToControllers(
      entries: NdisPlanBudgetsCodec.resolveFromFacts(factsList),
      core: budgetCoreCtrl,
      capacityBuilding: budgetCbCtrl,
      capital: budgetCapitalCtrl,
      otherLabel: budgetOtherLabelCtrl,
      otherAmount: budgetOtherCtrl,
    );
    replaceSupportSpecialists(_partitionSpecialistsFromFacts(factsList));
    final resolvedOther =
        (otherText != null && otherText.isNotEmpty) ? otherText : legacyOther;
    if (resolvedOther != null && resolvedOther.isNotEmpty) {
      supportPlanOtherCtrl.text = resolvedOther;
    }
  }

  /// Partitions specialists JSON: first SC → coordinator form; rest → list.
  List<SupportPlanSpecialistEntry> _partitionSpecialistsFromFacts(
    List<ClientProfileFactOut> factsList,
  ) {
    final entries = SupportPlanSpecialistsCodec.resolveFromFacts(factsList);
    SupportPlanSpecialistEntry? firstSc;
    final nonSc = <SupportPlanSpecialistEntry>[];
    for (final entry in entries) {
      if (entry.type == SupportPlanSpecialistTypes.supportCoordinator) {
        if (firstSc == null) {
          firstSc = entry;
        } else {
          // Legacy multi-SC: keep first only (YAGNI no merge UI).
          entry.dispose();
        }
      } else {
        nonSc.add(entry);
      }
    }
    if (firstSc != null) {
      _copySpecialistFields(from: firstSc, to: supportCoordinatorEntry);
      firstSc.dispose();
    } else {
      supportCoordinatorEntry.fields.clear();
      supportCoordinatorEntry.customLabelCtrl.clear();
    }
    return nonSc;
  }

  void _copySpecialistFields({
    required SupportPlanSpecialistEntry from,
    required SupportPlanSpecialistEntry to,
  }) {
    to.customLabelCtrl.text = from.customLabelCtrl.text;
    to.fields.nameCtrl.text = from.fields.nameCtrl.text;
    to.fields.companyCtrl.text = from.fields.companyCtrl.text;
    to.fields.abnAcnCtrl.text = from.fields.abnAcnCtrl.text;
    to.fields.orgIdCtrl.text = from.fields.orgIdCtrl.text;
    to.fields.phoneCtrl.text = from.fields.phoneCtrl.text;
    to.fields.emailCtrl.text = from.fields.emailCtrl.text;
    to.fields.addressCtrl.text = from.fields.addressCtrl.text;
    to.revision.value++;
  }

  /// Persist merge: `[scEntry?] + nonScEntries` (at most one SC).
  List<SupportPlanSpecialistEntry> _mergedSpecialistsForPersist() {
    final nonSc =
        supportSpecialists
            .where((e) => e.type != SupportPlanSpecialistTypes.supportCoordinator)
            .toList();
    if (!supportCoordinatorEntry.hasAnyFieldFilled) {
      return nonSc;
    }
    return [supportCoordinatorEntry, ...nonSc];
  }

  static DateTime? _parseHydratedDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static bool _parseHydratedBool(Object? raw) {
    if (raw is bool) return raw;
    final s = raw?.toString().trim().toLowerCase();
    return s == 'true' || s == '1';
  }

  Future<void> pickIdentityCard(IdentityCardAttachment attachment) async {
    final override = _pickCardFileOverride;
    final picked = override != null ? await override() : await _pickCardFile();
    if (picked != null) {
      attachment.pending.value = picked;
    }
  }

  void clearIdentityCardPending(IdentityCardAttachment attachment) {
    attachment.pending.value = null;
  }

  Future<void> pickNdisPlanPdf() async {
    final override = _pickPdfBytesOverride;
    final picked = override != null ? await override() : await _pickPdfBytes();
    if (picked != null) {
      ndisPdfAttachment.pending.value = PendingIdentityCardFile(
        name: picked.name,
        bytes: picked.bytes,
        contentType: 'application/pdf',
      );
    }
  }

  void clearNdisPlanPdfPending() {
    ndisPdfAttachment.pending.value = null;
  }

  void onPlanStartPicked(DateTime start) {
    planStartDate.value = start;
    planEndDate.value ??= DateTime(start.year + 1, start.month, start.day);
  }

  @override
  void onClose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    ndisCtrl.dispose();
    medicareCtrl.dispose();
    companionCardNumberCtrl.dispose();
    disabilityCardNumberCtrl.dispose();
    pensionCardNumberCtrl.dispose();
    photoIdNumberCtrl.dispose();
    allergiesCtrl.dispose();
    referralOtherCtrl.dispose();
    sexGenderOtherCtrl.dispose();
    siteNameCtrl.dispose();
    siteAddressCtrl.dispose();
    siteCityCtrl.dispose();
    siteStateCtrl.dispose();
    sitePostalCtrl.dispose();
    siteAccessNotesCtrl.dispose();
    siteLatCtrl.dispose();
    siteLngCtrl.dispose();
    preferredLanguageCtrl.dispose();
    culturalPreferencesCtrl.dispose();
    interpreterLanguageCtrl.dispose();
    contactNameCtrl.dispose();
    contactEmailCtrl.dispose();
    contactPhoneCtrl.dispose();
    contactRelationshipOtherCtrl.dispose();
    planManagerNameCtrl.dispose();
    planManagerCompanyCtrl.dispose();
    planManagerAbnAcnCtrl.dispose();
    planManagerOrgIdCtrl.dispose();
    planManagerPhoneCtrl.dispose();
    planManagerEmailCtrl.dispose();
    planManagerAddressCtrl.dispose();
    budgetCoreCtrl.dispose();
    budgetCbCtrl.dispose();
    budgetCapitalCtrl.dispose();
    budgetOtherLabelCtrl.dispose();
    budgetOtherCtrl.dispose();
    supportPlanOtherCtrl.dispose();
    primaryDisabilityCtrl.dispose();
    supportCoordinatorEntry.dispose();
    clearSupportSpecialists();
    consentSignerNameCtrl.dispose();
    super.onClose();
  }

  void previousStep() {
    if (step.value > 0) {
      errorMessage.value = null;
      step.value--;
    }
  }

  Future<void> nextStep() async {
    final ok = switch (step.value) {
      0 => await submitIdentity(),
      1 => await submitAddress(),
      2 => await submitPreferences(),
      3 => await submitContactsStep(),
      4 => await submitNdisStep(soft: true),
      5 => await submitCarePlanStep(soft: true),
      6 => await submitSupportCoordinatorStep(soft: true),
      7 => await submitSupportSpecialistsStep(soft: true),
      _ => await finishOnboarding(),
    };
    if (!ok) return;
  }

  // ── Identity ──────────────────────────────────────────────────────────

  void onPhotoPicked(PickedProfilePhoto picked) {
    pendingPhoto.value = picked;
    localPhotoBytes.value = picked.bytes;
  }

  void clearPhoto() {
    pendingPhoto.value = null;
    localPhotoBytes.value = null;
  }

  Future<bool> submitIdentity() async {
    errorMessage.value = null;

    final name = fullName.text.trim();
    final em = email.text.trim();
    final ph = phone.text.trim();

    if (name.isEmpty) {
      errorMessage.value = 'Participant full name is required.';
      return false;
    }
    if (em.isEmpty) {
      errorMessage.value = 'Participant email is required.';
      return false;
    }
    if (ph.isEmpty) {
      errorMessage.value = 'Participant phone number is required.';
      return false;
    }
    if (dob.value == null) {
      errorMessage.value = 'Participant date of birth is required.';
      return false;
    }
    if (referralSource.value == OnboardingIdentityStep.otherPresetKey &&
        (resolvedReferralSource == null || resolvedReferralSource!.isEmpty)) {
      errorMessage.value = 'Specify the referral source.';
      return false;
    }
    if (sexGender.value == OnboardingIdentityStep.otherPresetKey &&
        (resolvedSexGender == null || resolvedSexGender!.isEmpty)) {
      errorMessage.value = 'Specify sex / gender.';
      return false;
    }

    isSaving.value = true;
    try {
      final patientTypeId = await _resolvePatientTypeId();
      final dobStr = _formatDate(dob.value!);

      if (client.value == null) {
        final created = await _repository.createClient(
          ClientCreateRequest(
            fullName: name,
            email: em,
            phone: ph,
            clientTypeId: patientTypeId,
            dob: dobStr,
            metadata: const {'onboarding_incomplete': true},
          ),
        );
        client.value = created;
      } else {
        final updated = await _repository.patchClient(
          client.value!.id,
          ClientUpdateRequest(
            fullName: name,
            email: em,
            phone: ph,
            dob: dobStr,
          ),
        );
        client.value = updated;
      }

      final id = client.value!.id;

      if (pendingPhoto.value != null) {
        await _persistPhoto(id);
      }

      await _persistIdentityCards(id);

      await _putOptionalFact(id, OnboardingKeys.sexGender, resolvedSexGender);
      await _putOptionalFact(id, OnboardingKeys.atsiStatus, atsiStatus.value);
      await _putOptionalFact(
        id,
        OnboardingKeys.referralSource,
        resolvedReferralSource,
      );

      if (step.value == 0) step.value = 1;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ── Address ───────────────────────────────────────────────────────────

  @override
  void invalidateSiteAddressConfirm() {
    if (!addressConfirmed.value && geocodeFormattedAddress.value == null) {
      return;
    }
    addressConfirmed.value = false;
    geocodeFormattedAddress.value = null;
    siteLatCtrl.clear();
    siteLngCtrl.clear();
  }

  @override
  Future<void> lookupSiteAddress() async {
    addressConfirmed.value = false;
    final address = siteAddressCtrl.text.trim();
    final city = siteCityCtrl.text.trim();
    if (address.isEmpty || city.isEmpty) {
      errorMessage.value = 'Enter street address and city before looking up.';
      return;
    }
    isGeocoding.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.geocode(
        GeocodeRequest(
          addressLine1: address,
          city: city,
          country: 'AU',
          state: siteState.value.trim().isEmpty ? null : siteState.value.trim(),
        ),
      );
      final outcome = applyGeocodeResponse(
        result: result,
        latCtrl: siteLatCtrl,
        lngCtrl: siteLngCtrl,
        formattedAddress: geocodeFormattedAddress,
        addressConfirmed: addressConfirmed,
        addressFallback: '$address, $city',
      );
      if (!outcome.accepted) {
        errorMessage.value = outcome.errorMessage;
        return;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      geocodeFormattedAddress.value = null;
    } catch (e) {
      _setUnexpectedError(e);
      geocodeFormattedAddress.value = null;
    } finally {
      isGeocoding.value = false;
    }
  }

  @override
  void confirmSiteAddress() {
    final lat = double.tryParse(siteLatCtrl.text.trim());
    final lng = double.tryParse(siteLngCtrl.text.trim());
    if (lat == null || lng == null) {
      errorMessage.value = 'Look up an address before confirming.';
      return;
    }
    addressConfirmed.value = true;
    errorMessage.value = null;
  }

  @override
  void editSiteAddress() {
    addressConfirmed.value = false;
    geocodeFormattedAddress.value = null;
    siteLatCtrl.clear();
    siteLngCtrl.clear();
    errorMessage.value = null;
  }

  Future<bool> submitAddress() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }

    if (primarySiteSaved.value) {
      if (step.value == 1) step.value = 2;
      return true;
    }

    final name = siteNameCtrl.text.trim();
    final postal = sitePostalCtrl.text.trim();
    final lat = double.tryParse(siteLatCtrl.text.trim());
    final lng = double.tryParse(siteLngCtrl.text.trim());

    if (name.isEmpty) {
      errorMessage.value = 'Site name is required.';
      return false;
    }
    if (postal.isEmpty) {
      errorMessage.value = 'Postal code is required for the primary site.';
      return false;
    }
    if (!addressConfirmed.value || lat == null || lng == null) {
      errorMessage.value = 'Confirm the looked-up address before continuing.';
      return false;
    }

    isSaving.value = true;
    try {
      await _repository.createSite(
        id,
        ClientSiteWriteRequest(
          name: name,
          addressLine1: _nullIfEmpty(siteAddressCtrl.text),
          city: _nullIfEmpty(siteCityCtrl.text),
          state: _nullIfEmpty(siteState.value),
          country: 'AU',
          postalCode: postal,
          latitude: lat,
          longitude: lng,
          isPrimary: true,
          accessNotes: _nullIfEmpty(siteAccessNotesCtrl.text),
        ),
      );
      primarySiteSaved.value = true;
      if (step.value == 1) step.value = 2;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  void openAddLocation() {
    final c = client.value;
    if (c == null) return;
    if (!Get.isRegistered<ClientsController>()) return;
    final cc = Get.find<ClientsController>();
    cc.selected.value = c;
    cc.beginSiteForm();
  }

  // ── Preferences ───────────────────────────────────────────────────────

  Future<bool> submitPreferences() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }
    if (interpreterRequired.value &&
        interpreterLanguageCtrl.text.trim().isEmpty) {
      errorMessage.value =
          'Enter the interpreter language when an interpreter is required.';
      return false;
    }

    isSaving.value = true;
    try {
      await _putOptionalFact(
        id,
        OnboardingKeys.preferredLanguage,
        _nullIfEmpty(preferredLanguageCtrl.text),
      );
      await _putOptionalFact(
        id,
        OnboardingKeys.culturalPreferences,
        _nullIfEmpty(culturalPreferencesCtrl.text),
      );
      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.homeVisitConsent,
        ProfileFactUpsert(valueJson: homeVisitConsent.value),
      );
      await _putOptionalFact(
        id,
        OnboardingKeys.swGenderPreference,
        swGenderPreference.value,
      );
      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.interpreterRequired,
        ProfileFactUpsert(valueJson: interpreterRequired.value),
      );
      if (interpreterRequired.value) {
        await _putOptionalFact(
          id,
          OnboardingKeys.interpreterLanguage,
          _nullIfEmpty(interpreterLanguageCtrl.text),
        );
      }
      await _putOptionalFact(
        id,
        OnboardingKeys.preferredContactMethod,
        preferredContactMethod.value,
      );
      if (step.value == 2) {
        step.value = 3;
        _prepRepresentativeStep();
      }
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ── Contacts ──────────────────────────────────────────────────────────

  void beginEmergencyDraft() {
    _resetContactDraft();
    contactDraftMode.value = 'emergency';
    contactRelationshipPreset.value = null;
    contactIsEmergency.value = true;
    contactIsPrimary.value = true;
  }

  void beginCarerDraft() {
    _resetContactDraft();
    contactDraftMode.value = 'carer';
    contactRelationshipPreset.value = OnboardingKeys.relCarer;
  }

  void beginMoreContactDraft() {
    _resetContactDraft();
    contactDraftMode.value = 'more';
    contactRelationshipPreset.value = null;
  }

  /// Cancel emergency/more draft and return to representative/nominee mode.
  void cancelContactDraftToRepresentative() {
    _prepRepresentativeStep();
  }

  void _resetContactDraft() {
    contactNameCtrl.clear();
    contactEmailCtrl.clear();
    contactPhoneCtrl.clear();
    contactRelationshipOtherCtrl.clear();
    contactIsPrimary.value = false;
    contactIsEmergency.value = !emergencySaved.value;
    errorMessage.value = null;
  }

  Future<bool> saveContactDraft() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }

    final name = contactNameCtrl.text.trim();
    final em = contactEmailCtrl.text.trim();
    final ph = contactPhoneCtrl.text.trim();
    if (name.isEmpty && em.isEmpty && ph.isEmpty) {
      errorMessage.value = 'Provide at least a name, email, or phone.';
      return false;
    }
    if (em.isEmpty && ph.isEmpty) {
      errorMessage.value = 'Provide a phone or email for the contact.';
      return false;
    }

    final relationship = resolvedContactRelationship;
    if (contactRelationshipPreset.value ==
            ContactFormHost.relationshipOtherKey &&
        (relationship == null || relationship.isEmpty)) {
      errorMessage.value = 'Specify the relationship.';
      return false;
    }
    if (relationship == null || relationship.isEmpty) {
      errorMessage.value = 'Select a relationship.';
      return false;
    }

    isSaving.value = true;
    try {
      final body = ClientContactWriteRequest(
        name: _nullIfEmpty(name),
        email: _nullIfEmpty(em),
        phone: _nullIfEmpty(ph),
        relationship: relationship,
        legalRole: _representativeLegalRole,
        isPrimary: contactIsPrimary.value,
        notifyVisitComplete: false,
        isEmergency: contactIsEmergency.value,
      );

      final ClientContactOut saved;
      final editingId =
          representativeEditing.value
              ? savedRepresentativeContact.value?.id
              : null;
      if (editingId != null && editingId.isNotEmpty) {
        saved = await _repository.patchContact(id, editingId, body);
        final idx = contactsCreated.indexWhere((c) => c.id == editingId);
        if (idx >= 0) {
          contactsCreated[idx] = saved;
        } else {
          contactsCreated.add(saved);
        }
        contactsCreated.refresh();
      } else {
        saved = await _repository.createContact(id, body);
        contactsCreated.add(saved);
      }

      if (saved.isEmergency || contactIsEmergency.value) {
        emergencySaved.value = true;
      }
      if (relationship == OnboardingKeys.relCarer) {
        carerSaved.value = true;
      }
      final legalRole = _representativeLegalRole;
      if (legalRole != null && saved.legalRole == legalRole) {
        representativeSaved.value = true;
        representativeEditing.value = false;
        savedRepresentativeContact.value = saved;
        nomineeSkipped.value = false;
      }
      _resetContactDraft();
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  bool get hasEmergencyContact =>
      emergencySaved.value || contactsCreated.any((c) => c.isEmergency);

  bool get _contactDraftHasChannel =>
      contactNameCtrl.text.trim().isNotEmpty ||
      contactPhoneCtrl.text.trim().isNotEmpty ||
      contactEmailCtrl.text.trim().isNotEmpty;

  Future<bool> submitContacts({bool allowEmpty = true}) async {
    errorMessage.value = null;
    final mode = contactDraftMode.value;
    final editingRep = mode == 'representative' || mode == 'nominee';
    if (!editingRep && _contactDraftHasChannel) {
      final ok = await saveContactDraft();
      if (!ok) return false;
    } else if (!hasEmergencyContact &&
        contactIsEmergency.value &&
        _contactDraftHasChannel) {
      final ok = await saveContactDraft();
      if (!ok) return false;
    }
    if (!allowEmpty && contactsCreated.isEmpty && !hasEmergencyContact) {
      errorMessage.value = 'Add at least one contact to continue.';
      return false;
    }
    return true;
  }

  /// Combined Contacts step: representative/nominee gate + optional contacts.
  Future<bool> submitContactsStep() async {
    errorMessage.value = null;
    final mode = contactDraftMode.value;
    final editingRep = mode == 'representative' || mode == 'nominee';

    if (!editingRep) {
      final ok = await submitContacts(allowEmpty: true);
      if (!ok) return false;
    }

    if (editingRep || requiresChildRepresentative) {
      final ok = await submitRepresentative();
      if (!ok) return false;
    } else if (!representativeSaved.value) {
      nomineeSkipped.value = true;
    }

    if (step.value == 3) step.value = 4;
    return true;
  }

  void _prepRepresentativeStep() {
    _resetContactDraft();
    if (requiresChildRepresentative) {
      contactDraftMode.value = 'representative';
    } else {
      contactDraftMode.value = 'nominee';
    }
    contactRelationshipPreset.value = null;
  }

  String? get _representativeLegalRole {
    // Only tag contacts created/edited as rep/nominee — never emergency/carer/more
    // drafts on the combined Contacts step (step index 3).
    final mode = contactDraftMode.value;
    if (mode != 'representative' && mode != 'nominee') {
      return null;
    }
    if (requiresChildRepresentative) {
      return OnboardingKeys.relChildRepresentative;
    }
    if (nomineeSkipped.value) return null;
    return OnboardingKeys.relNominee;
  }

  // ── Representative ────────────────────────────────────────────────────

  Future<bool> useExistingAsEmergency(String contactId) async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }
    isSaving.value = true;
    try {
      final patched = await _repository.patchContact(
        id,
        contactId,
        const ClientContactWriteRequest(isEmergency: true),
      );
      final idx = contactsCreated.indexWhere((c) => c.id == contactId);
      if (idx >= 0) {
        contactsCreated[idx] = patched;
      } else {
        contactsCreated.add(patched);
      }
      contactsCreated.refresh();
      reuseEmergencyContactId.value = contactId;
      emergencySaved.value = true;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> saveExistingContactAsRepresentative() async {
    errorMessage.value = null;
    final id = clientId;
    final contactId = reuseEmergencyContactId.value;
    final legalRole = _representativeLegalRole;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }
    if (contactId == null || contactId.isEmpty) {
      errorMessage.value = 'Select an existing contact first.';
      return false;
    }
    if (legalRole == null) {
      errorMessage.value = 'Representative role is not available on this step.';
      return false;
    }

    isSaving.value = true;
    try {
      final patched = await _repository.patchContact(
        id,
        contactId,
        ClientContactWriteRequest(legalRole: legalRole),
      );
      final idx = contactsCreated.indexWhere((c) => c.id == contactId);
      if (idx >= 0) {
        contactsCreated[idx] = patched;
      } else {
        contactsCreated.add(patched);
      }
      contactsCreated.refresh();
      representativeSaved.value = true;
      representativeEditing.value = false;
      savedRepresentativeContact.value = patched;
      nomineeSkipped.value = false;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> submitRepresentative() async {
    errorMessage.value = null;

    // Persist in-progress edit of a saved representative before Next.
    if (representativeEditing.value && _contactDraftHasChannel) {
      if (requiresChildRepresentative &&
          contactDraftMode.value != 'representative') {
        contactDraftMode.value = 'representative';
      } else if (!requiresChildRepresentative &&
          contactDraftMode.value != 'nominee') {
        contactDraftMode.value = 'nominee';
      }
      final ok = await saveContactDraft();
      if (!ok) return false;
    }

    if (requiresChildRepresentative) {
      if (!representativeSaved.value) {
        final hasDraft =
            contactNameCtrl.text.trim().isNotEmpty ||
            contactPhoneCtrl.text.trim().isNotEmpty ||
            contactEmailCtrl.text.trim().isNotEmpty;
        if (hasDraft) {
          // Ensure legal role applies when saving from Contacts step.
          if (contactDraftMode.value != 'representative') {
            contactDraftMode.value = 'representative';
          }
          final ok = await saveContactDraft();
          if (!ok) return false;
        }
      }
      if (!representativeSaved.value) {
        errorMessage.value =
            'A representative is required for participants under 18.';
        return false;
      }
    } else if (!representativeSaved.value && !nomineeSkipped.value) {
      final hasDraft =
          contactNameCtrl.text.trim().isNotEmpty ||
          contactPhoneCtrl.text.trim().isNotEmpty ||
          contactEmailCtrl.text.trim().isNotEmpty;
      if (hasDraft) {
        if (contactDraftMode.value != 'nominee') {
          contactDraftMode.value = 'nominee';
        }
        final ok = await saveContactDraft();
        if (!ok) return false;
      } else {
        nomineeSkipped.value = true;
      }
    }

    return true;
  }

  void skipCarer() {
    beginMoreContactDraft();
  }

  void skipNominee() {
    nomineeSkipped.value = true;
    errorMessage.value = null;
  }

  void beginEditRepresentative() {
    representativeEditing.value = true;
    contactDraftMode.value =
        requiresChildRepresentative ? 'representative' : 'nominee';
    final saved = savedRepresentativeContact.value;
    if (saved == null) return;
    contactNameCtrl.text = saved.name ?? '';
    contactEmailCtrl.text = saved.email ?? '';
    contactPhoneCtrl.text = saved.phone ?? '';
    final hydrated = ContactFormHost.hydrateRelationship(saved.relationship);
    contactRelationshipPreset.value = hydrated.preset;
    contactRelationshipOtherCtrl.text = hydrated.otherText;
    contactIsEmergency.value = saved.isEmergency;
    contactIsPrimary.value = saved.isPrimary;
  }

  void cancelEditRepresentative() {
    representativeEditing.value = false;
    _resetContactDraft();
  }

  // ── NDIS / Care plan / Coordinator / Specialists ──────────────────────

  /// Soft-skip when empty; if NDIS or plan type is present, hard-validate.
  Future<bool> submitNdisStep({bool soft = true}) async {
    errorMessage.value = null;
    ndisFieldError.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }

    final ndis = ndisCtrl.text.trim();
    final planType = planManagementType.value;
    final hasHardContent =
        ndis.isNotEmpty || (planType != null && planType.isNotEmpty);

    if (!soft || hasHardContent) {
      if (ndis.isEmpty) {
        ndisFieldError.value = 'NDIS number is required.';
        return false;
      }
      if (planType == null || planType.isEmpty) {
        errorMessage.value = 'Plan management type is required.';
        return false;
      }
      if (planType == 'plan_managed') {
        final pmName = planManagerNameCtrl.text.trim();
        final pmPhone = planManagerPhoneCtrl.text.trim();
        final pmEmail = planManagerEmailCtrl.text.trim();
        if (pmName.isEmpty) {
          errorMessage.value =
              'Plan manager name is required for plan-managed.';
          return false;
        }
        if (pmPhone.isEmpty && pmEmail.isEmpty) {
          errorMessage.value =
              'Plan manager phone or email is required for plan-managed.';
          return false;
        }
      }
    }

    budgetFieldError.value = NdisPlanBudgetsCodec.validateAll(
      core: budgetCoreCtrl.text,
      capacityBuilding: budgetCbCtrl.text,
      capital: budgetCapitalCtrl.text,
      otherAmount: budgetOtherCtrl.text,
    );
    if (budgetFieldError.value != null) {
      return false;
    }

    final hasOptionalPersist =
        ndisPdfAttachment.pending.value != null ||
        ndisPdfAttachment.hasAttachment ||
        planStartDate.value != null ||
        planEndDate.value != null ||
        budgetCoreCtrl.text.trim().isNotEmpty ||
        budgetCbCtrl.text.trim().isNotEmpty ||
        budgetCapitalCtrl.text.trim().isNotEmpty ||
        budgetOtherCtrl.text.trim().isNotEmpty ||
        budgetOtherLabelCtrl.text.trim().isNotEmpty;

    if (soft && !hasHardContent && !hasOptionalPersist) {
      if (step.value == 4) step.value = 5;
      return true;
    }

    isSaving.value = true;
    try {
      var ndisDocId = ndisPdfAttachment.existingDocumentId.value;
      final ndisPending = ndisPdfAttachment.pending.value;
      if (ndisPending != null) {
        ndisDocId = await _uploadClientFile(
          clientId: id,
          category: OnboardingKeys.ndis,
          name: ndisPending.name,
          contentType: ndisPending.contentType,
          fileBytes: ndisPending.bytes,
        );
        ndisPdfAttachment.existingDocumentId.value = ndisDocId;
        ndisPdfAttachment.existingDocumentLabel.value = ndisPending.name;
        ndisPdfAttachment.pending.value = null;
      }

      if (ndis.isNotEmpty) {
        try {
          await _repository.upsertProfileFact(
            id,
            OnboardingKeys.ndis,
            ProfileFactUpsert(valueJson: ndis, documentId: ndisDocId),
          );
        } on AppFailure catch (e) {
          if (e.code == 'ndis_number_in_use') {
            ndisFieldError.value = e.message;
            return false;
          }
          rethrow;
        }
      } else if (ndisDocId != null && ndisDocId.isNotEmpty) {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.ndis,
          ProfileFactUpsert(documentId: ndisDocId),
        );
      }

      if (planType != null && planType.isNotEmpty) {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.planManagementType,
          ProfileFactUpsert(valueJson: planType),
        );
      }
      if (planType == 'plan_managed') {
        await _putOptionalFact(
          id,
          OnboardingKeys.planManagerName,
          planManagerNameCtrl.text.trim(),
        );
        await _putOptionalFact(
          id,
          OnboardingKeys.planManagerCompany,
          planManagerCompanyCtrl.text.trim(),
        );
        await _putOptionalFact(
          id,
          OnboardingKeys.planManagerAbnAcn,
          planManagerAbnAcnCtrl.text.trim(),
        );
        await _putOptionalFact(
          id,
          OnboardingKeys.planManagerOrgId,
          planManagerOrgIdCtrl.text.trim(),
        );
        await _putOptionalFact(
          id,
          OnboardingKeys.planManagerPhone,
          planManagerPhoneCtrl.text.trim(),
        );
        await _putOptionalFact(
          id,
          OnboardingKeys.planManagerEmail,
          planManagerEmailCtrl.text.trim(),
        );
        await _putOptionalFact(
          id,
          OnboardingKeys.planManagerAddress,
          planManagerAddressCtrl.text.trim(),
        );
      }
      if (planStartDate.value != null) {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.planStartDate,
          ProfileFactUpsert(valueJson: _formatDate(planStartDate.value!)),
        );
      }
      if (planEndDate.value != null) {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.planEndDate,
          ProfileFactUpsert(valueJson: _formatDate(planEndDate.value!)),
        );
      }
      final budgetEntries = NdisPlanBudgetsCodec.readFromControllers(
        core: budgetCoreCtrl,
        capacityBuilding: budgetCbCtrl,
        capital: budgetCapitalCtrl,
        otherLabel: budgetOtherLabelCtrl,
        otherAmount: budgetOtherCtrl,
      );
      final budgetJson = NdisPlanBudgetsCodec.toFactValue(budgetEntries);
      if (budgetJson == null) {
        await _clearFactIfPresent(id, OnboardingKeys.ndisPlanBudgets);
      } else {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.ndisPlanBudgets,
          ProfileFactUpsert(valueJson: budgetJson),
        );
        _presentKeys.add(OnboardingKeys.ndisPlanBudgets);
        await _clearLegacyBudgetFacts(id);
      }

      if (step.value == 4) step.value = 5;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Soft-skip when empty; persists allergies, clinical flags, consent, notes.
  /// Always rewrites so clearing fields/flags removes previously saved facts.
  Future<bool> submitCarePlanStep({bool soft = true}) async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }

    // soft retained for API parity; empty form still clears prior facts.
    final _ = soft;

    final allergies = allergiesCtrl.text.trim();
    final notes = supportPlanOtherCtrl.text.trim();
    final disability = primaryDisabilityCtrl.text.trim();

    isSaving.value = true;
    try {
      if (allergies.isNotEmpty) {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.allergies,
          ProfileFactUpsert(valueJson: allergies),
        );
        _presentKeys.add(OnboardingKeys.allergies);
      } else {
        await _clearFactIfPresent(id, OnboardingKeys.allergies);
      }
      // Primary disability is day-one capture only; full goals/living/risk
      // body_json stays on the Care plan tab / support-plan wizard.
      final careNotes = [
        if (disability.isNotEmpty) 'Primary disability: $disability',
        if (notes.isNotEmpty) notes,
      ].join('\n');
      if (careNotes.isEmpty) {
        await _clearFactIfPresent(id, OnboardingKeys.supportPlanOther);
      } else {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.supportPlanOther,
          ProfileFactUpsert(valueJson: careNotes),
        );
        _presentKeys.add(OnboardingKeys.supportPlanOther);
      }

      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.infoShareConsent,
        ProfileFactUpsert(valueJson: infoShareConsent.value),
      );
      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.specificSupportsConsent,
        ProfileFactUpsert(valueJson: specificSupportsConsent.value),
      );

      // Only rewrite clinical on-file flags when the store was loaded from the
      // profile or the user explicitly toggled a flag on. Forcing hasHydrated
      // and persisting defaults would clobber Care-tab / prior-pass trues.
      final shouldPersistClinical =
          clinical.hasHydrated ||
          clinical.bspOnFile.value ||
          clinical.nutritionChecklistOnFile.value ||
          clinical.hazardChecklistOnFile.value;
      if (shouldPersistClinical) {
        clinical.hasHydrated = true;
        final clinicalFailed = await clinical.persistFacts(clientId: id);
        if (clinicalFailed.isNotEmpty) {
          errorMessage.value =
              'Could not save clinical documents: ${clinicalFailed.join(', ')}';
          return false;
        }
      }

      if (step.value == 5) step.value = 6;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> submitSupportCoordinatorStep({bool soft = true}) async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }

    // Always rewrite merged specialists JSON so clearing the coordinator form
    // (soft skip with empty fields) removes a previously saved SC row.
    isSaving.value = true;
    try {
      await _persistMergedSpecialists(id);
      if (step.value == 6) step.value = 7;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> submitSupportSpecialistsStep({bool soft = true}) async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }

    // Always rewrite merged specialists so cleared specialist rows do not
    // leave stale support_plan_specialists JSON behind.
    isSaving.value = true;
    try {
      await _persistMergedSpecialists(id);
      if (step.value == 7) step.value = 8;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _persistMergedSpecialists(String id) async {
    final specialistJson = SupportPlanSpecialistsCodec.toFactValue(
      _mergedSpecialistsForPersist(),
    );
    if (specialistJson.isEmpty) {
      await _clearFactIfPresent(id, OnboardingKeys.supportPlanSpecialists);
    } else {
      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.supportPlanSpecialists,
        ProfileFactUpsert(valueJson: specialistJson),
      );
      _presentKeys.add(OnboardingKeys.supportPlanSpecialists);
      await _clearLegacySpecialistFacts(id);
    }
  }

  /// Backward-compatible alias used by older tests — NDIS hard path.
  Future<bool> submitSupportPlan() => submitNdisStep(soft: false);

  // ── Legal pack ────────────────────────────────────────────────────────

  Future<void> loadFormTemplates() async {
    isLoadingTemplates.value = true;
    try {
      final list = await _repository.listFormTemplates(tenantLevel: true);
      formTemplates.assignAll(
        list.where((t) => t.isActive && t.isClientOnboarding),
      );
    } on AppFailure {
      // Non-fatal — acknowledgement opt-in still works via requirement key.
    } catch (_) {
    } finally {
      isLoadingTemplates.value = false;
    }
  }

  ClientLegalUploadHelper get _legalUploadHelper => ClientLegalUploadHelper(
    repository: _repository,
    pipeline: _pipeline,
    pickPdfBytes: _pickPdfBytes,
    canUploadDocs: () => canUploadDocs,
  );

  Future<bool> markConsentComplete() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) return false;

    consentUploading.value = true;
    try {
      await _legalUploadHelper.completeConsent(
        clientId: id,
        participantOrRepName: consentSignerNameCtrl.text,
      );
      consentComplete.value = true;
      return true;
    } on AppFailure catch (e) {
      if (ClientLegalUploadHelper.isConsentLegalUnavailable(e)) {
        errorMessage.value =
            ClientLegalUploadHelper.consentLegalUnavailableMessage;
        return false;
      }
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      consentUploading.value = false;
    }
  }

  Future<bool> markServiceAgreementComplete() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) return false;

    serviceAgreementUploading.value = true;
    try {
      await _legalUploadHelper.completeServiceAgreement(clientId: id);
      serviceAgreementComplete.value = true;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      serviceAgreementUploading.value = false;
    }
  }

  Future<bool> markAcknowledgementComplete() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) return false;

    acknowledgementUploading.value = true;
    try {
      await _legalUploadHelper.completeAcknowledgement(clientId: id);
      acknowledgementComplete.value = true;
      includeAcknowledgement.value = true;
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      acknowledgementUploading.value = false;
    }
  }

  Future<bool> finishOnboarding() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'No client created yet.';
      return false;
    }

    final missing = <String>[];
    if (!consentComplete.value) missing.add('Consent');
    if (!serviceAgreementComplete.value) missing.add('Service Agreement');

    if (missing.isNotEmpty) {
      final confirm = softGateConfirm ?? _defaultSoftGate;
      final proceed = await confirm(missing);
      if (!proceed) return false;
    }

    isSaving.value = true;
    try {
      await _persistLegalOtherDocuments(id);

      final fresh = await _repository.getClient(id);
      client.value = fresh;
      final existing = Map<String, dynamic>.from(fresh.metadata);
      existing['onboarding_incomplete'] = false;
      final updated = await _repository.patchClient(
        id,
        ClientUpdateRequest(metadata: existing),
      );
      client.value = updated;

      if (onFinished != null) {
        onFinished!(id);
      } else if (Get.isRegistered<ClientsController>()) {
        final clients = Get.find<ClientsController>();
        await clients.load();
        await clients.openDetailReplacing(updated);
      } else {
        // Let ClientsBinding construct ClientsController; Task 3 hydrate
        // (ensureDetailHydratedFromRoute) loads by id/args on detail entry.
        Get.offNamed(
          AppRoutes.staffClientDetail,
          arguments: updated,
          parameters: {'id': id},
        );
      }
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> _defaultSoftGate(List<String> missing) async {
    final proceed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Legal pack incomplete'),
        content: Text(
          'The following items are not marked complete:\n\n'
          '${missing.map((m) => '• $m').join('\n')}\n\n'
          'You can finish onboarding anyway and complete them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Go back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('Finish anyway'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  static const _unexpectedErrorMessage =
      'Something went wrong. Please try again.';

  void _setUnexpectedError(Object error) {
    // Keep AppFailure handling in dedicated `on AppFailure` clauses.
    // Unexpected errors must not surface raw exception text to staff UI.
    errorMessage.value = _unexpectedErrorMessage;
  }

  Future<String?> _resolvePatientTypeId() async {
    final types = await _repository.listClientTypes();
    for (final type in types) {
      final code = type.code.trim().toLowerCase();
      final name = type.name.trim().toLowerCase();
      if (code == 'patient' || name == 'patient') return type.id;
    }
    return null;
  }

  Future<void> _putOptionalFact(
    String clientId,
    String key,
    Object? value,
  ) async {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    await _repository.upsertProfileFact(
      clientId,
      key,
      ProfileFactUpsert(valueJson: value is String ? value.trim() : value),
    );
  }

  void _recordPresentFacts(Iterable<ClientProfileFactOut> facts) {
    for (final fact in facts) {
      _presentKeys.add(fact.requirementKey);
      final updatedAt = fact.updatedAt;
      if (updatedAt != null) {
        _factUpdatedAt[fact.requirementKey] = updatedAt;
      }
    }
  }

  Future<void> _clearFactIfPresent(String clientId, String key) async {
    if (!_presentKeys.contains(key)) return;
    await _repository.upsertProfileFact(
      clientId,
      key,
      ProfileFactUpsert(
        clearValue: true,
        expectedUpdatedAt: _factUpdatedAt[key],
      ),
    );
    _presentKeys.remove(key);
    _factUpdatedAt.remove(key);
  }

  Future<void> _clearLegacyBudgetFacts(String clientId) async {
    for (final key in NdisPlanBudgetsCodec.legacyFactKeys) {
      await _clearFactIfPresent(clientId, key);
    }
  }

  Future<void> _clearLegacySpecialistFacts(String clientId) async {
    for (final key in SupportPlanSpecialistsCodec.legacyFactKeys) {
      await _clearFactIfPresent(clientId, key);
    }
  }

  Future<void> _putOptionalNumber(
    String clientId,
    String key,
    TextEditingController ctrl,
  ) async {
    final raw = ctrl.text.trim();
    if (raw.isEmpty) return;
    final n = num.tryParse(raw);
    if (n == null) return;
    await _repository.upsertProfileFact(
      clientId,
      key,
      ProfileFactUpsert(valueJson: n),
    );
  }

  void clearSupportSpecialists() {
    for (final entry in supportSpecialists) {
      entry.dispose();
    }
    supportSpecialists.clear();
  }

  void addSupportSpecialist(String type) {
    if (type == SupportPlanSpecialistTypes.supportCoordinator) return;
    supportSpecialists.add(
      SupportPlanSpecialistEntry.create(type, expanded: true),
    );
  }

  void removeSupportSpecialist(String id) {
    final index = supportSpecialists.indexWhere((e) => e.id == id);
    if (index < 0) return;
    supportSpecialists[index].dispose();
    supportSpecialists.removeAt(index);
  }

  void addLegalOtherDoc() {
    legalOtherDocs.add(
      LegalOtherDocumentDraft(
        id: LegalOtherDocumentDraft.nextId(),
        typeKey: 'other',
      ),
    );
  }

  Future<void> removeLegalOtherDoc(String id) async {
    legalOtherDocs.removeWhere((e) => e.id == id);
    legalOtherUploading.remove(id);
    final clientId = this.clientId;
    if (clientId == null) return;
    try {
      await _persistLegalOtherDocuments(clientId);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      _setUnexpectedError(e);
    }
  }

  /// Pick a PDF then [uploadLegalOther] — same chrome pattern as Consent / SA.
  Future<bool> markLegalOtherComplete(String rowId) async {
    errorMessage.value = null;
    final picked = await _pickPdfBytes();
    if (picked == null) return false;
    return uploadLegalOther(rowId, picked.bytes, picked.name);
  }

  /// Resume hydrate for optional legal other docs from profile facts.
  void hydrateLegalOtherFromFacts(Iterable<ClientProfileFactOut> facts) {
    _recordPresentFacts(facts);
    for (final fact in facts) {
      if (fact.requirementKey != OnboardingKeys.legalOtherDocuments) continue;
      legalOtherDocs.assignAll(legalOtherDocsFromFactValue(fact.valueJson));
    }
  }

  /// Upload a PDF for [rowId], mark complete, store document id.
  ///
  /// Persists [OnboardingKeys.legalOtherDocuments] immediately so resume
  /// hydrate does not drop uploads made before [finishOnboarding].
  ///
  /// Rejects null [LegalOtherDocumentDraft.displayLabel] and Other labels over
  /// [legalOtherMaxCustomLabelLength] (after trim). PDF-only via helper.
  Future<bool> uploadLegalOther(
    String rowId,
    List<int> fileBytes,
    String fileName,
  ) async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'No client created yet.';
      return false;
    }

    final index = legalOtherDocs.indexWhere((e) => e.id == rowId);
    if (index < 0) {
      errorMessage.value = 'Document row not found.';
      return false;
    }
    final row = legalOtherDocs[index];
    final label = row.displayLabel;
    if (label == null) {
      errorMessage.value =
          row.typeKey == 'other'
              ? 'Enter a name for this Other document before uploading.'
              : 'Select a document type before uploading.';
      return false;
    }
    if (row.typeKey == 'other' &&
        label.length > legalOtherMaxCustomLabelLength) {
      errorMessage.value =
          'Other document name must be $legalOtherMaxCustomLabelLength '
          'characters or fewer.';
      return false;
    }

    legalOtherUploading.add(rowId);
    try {
      final docId = await _legalUploadHelper.uploadLegalOtherPdf(
        clientId: id,
        filename: fileName,
        fileBytes: fileBytes,
      );
      row.documentId = docId;
      row.fileName = fileName;
      row.complete = true;
      legalOtherDocs.refresh();
      await _persistLegalOtherDocuments(id);
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      _setUnexpectedError(e);
      return false;
    } finally {
      legalOtherUploading.remove(rowId);
    }
  }

  Future<void> _persistLegalOtherDocuments(String clientId) async {
    final payload =
        legalOtherDocs
            .where((e) => e.complete && e.documentId != null && e.canUpload)
            .map((e) => e.toFactEntry())
            .toList();
    if (payload.isEmpty) {
      await _clearFactIfPresent(clientId, OnboardingKeys.legalOtherDocuments);
      return;
    }
    await _repository.upsertProfileFact(
      clientId,
      OnboardingKeys.legalOtherDocuments,
      ProfileFactUpsert(valueJson: payload),
    );
    _presentKeys.add(OnboardingKeys.legalOtherDocuments);
  }

  void replaceSupportSpecialists(Iterable<SupportPlanSpecialistEntry> entries) {
    clearSupportSpecialists();
    supportSpecialists.assignAll(entries);
  }

  Future<void> _persistIdentityCards(String clientId) async {
    final medicare = medicareCtrl.text.trim();
    await _persistIdentityCard(
      clientId: clientId,
      requirementKey: OnboardingKeys.medicareCard,
      category: OnboardingKeys.medicareCard,
      attachment: medicareCardAttachment,
      valueJson: medicare.isEmpty ? null : medicare,
    );
    await _persistIdentityCard(
      clientId: clientId,
      requirementKey: OnboardingKeys.companionCard,
      category: OnboardingKeys.companionCard,
      attachment: companionCardAttachment,
      valueJson: _nullIfEmpty(companionCardNumberCtrl.text.trim()),
    );
    await _persistIdentityCard(
      clientId: clientId,
      requirementKey: OnboardingKeys.disabilityCard,
      category: OnboardingKeys.disabilityCard,
      attachment: disabilityCardAttachment,
      valueJson: _nullIfEmpty(disabilityCardNumberCtrl.text.trim()),
    );
    await _persistIdentityCard(
      clientId: clientId,
      requirementKey: OnboardingKeys.pensionCard,
      category: OnboardingKeys.pensionCard,
      attachment: pensionCardAttachment,
      valueJson: _nullIfEmpty(pensionCardNumberCtrl.text.trim()),
    );
    await _persistPhotoId(clientId);
  }

  Future<void> _persistPhotoId(String clientId) async {
    await _persistIdentityCard(
      clientId: clientId,
      requirementKey: OnboardingKeys.photoId,
      category: OnboardingKeys.photoId,
      attachment: photoIdAttachment,
      valueJson: _nullIfEmpty(photoIdNumberCtrl.text.trim()),
    );
  }

  Future<void> _persistIdentityCard({
    required String clientId,
    required String requirementKey,
    required String category,
    required IdentityCardAttachment attachment,
    String? valueJson,
  }) async {
    var docId = attachment.existingDocumentId.value;
    final pending = attachment.pending.value;
    if (pending != null) {
      docId = await _uploadClientFile(
        clientId: clientId,
        category: category,
        name: pending.name,
        contentType: pending.contentType,
        fileBytes: pending.bytes,
      );
      attachment.existingDocumentId.value = docId;
      attachment.existingDocumentLabel.value = pending.name;
      attachment.pending.value = null;
    }

    final hasValue = valueJson != null && valueJson.trim().isNotEmpty;
    if (!hasValue && (docId == null || docId.isEmpty)) return;

    await _repository.upsertProfileFact(
      clientId,
      requirementKey,
      ProfileFactUpsert(
        valueJson: hasValue ? valueJson.trim() : null,
        documentId: docId,
      ),
    );
  }

  Future<PendingIdentityCardFile?> _pickCardFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return PendingIdentityCardFile(
      name: file.name,
      bytes: bytes,
      contentType: _contentTypeForFilename(file.name),
    );
  }

  static String _contentTypeForFilename(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _persistPhoto(String clientId) async {
    final pending = pendingPhoto.value;
    if (pending == null) return;
    final docId = await _uploadClientFile(
      clientId: clientId,
      category: 'client_photo',
      name: pending.name,
      contentType: pending.contentType,
      fileBytes: pending.bytes,
    );
    await _repository.setClientProfilePhoto(clientId, docId);
    pendingPhoto.value = null;
    // Defense in depth: keep local metadata aligned with server after photo set.
    client.value = await _repository.getClient(clientId);
  }

  Future<String> _uploadClientFile({
    required String clientId,
    required String category,
    required String name,
    required String contentType,
    required List<int> fileBytes,
  }) async {
    final pipeline = _pipeline;
    if (pipeline == null) {
      throw const AppFailure(
        code: 'unknown',
        message: 'Document upload is not configured.',
        presentation: AppFailurePresentation.inline,
      );
    }
    if (!canUploadDocs) {
      throw const AppFailure(
        code: 'forbidden',
        message: 'Missing documents.upload / clients.docs.manage permission.',
        presentation: AppFailurePresentation.inline,
      );
    }
    final doc = await pipeline.uploadEvidence(
      request: UploadUrlRequest(
        ownerType: 'client',
        ownerId: clientId,
        filename: name,
        contentType: contentType,
        sizeBytes: fileBytes.length,
        category: category,
      ),
      bytes: fileBytes,
    );
    return doc.id;
  }

  Future<({String name, List<int> bytes})?> _pickPdfBytes() async {
    final override = _pickPdfBytesOverride;
    if (override != null) return override();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return (name: file.name, bytes: bytes);
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String? _nullIfEmpty(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t;
  }
}
