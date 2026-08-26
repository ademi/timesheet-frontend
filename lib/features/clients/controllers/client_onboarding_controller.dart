import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/models/document/document_models.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/models/client_models.dart';
import '../data/models/client_profile_models.dart';
import '../data/repositories/clients_repository.dart';
import '../utils/onboarding_age.dart';
import '../utils/onboarding_keys.dart';
import '../utils/site_geocode_apply.dart';
import '../widgets/contact_form_host.dart';
import '../widgets/site_form_host.dart';
import 'clients_controller.dart';

/// Modular client onboarding wizard (Identity → … → Legal).
class ClientOnboardingController extends GetxController
    implements SiteFormHost, ContactFormHost {
  ClientOnboardingController({
    required ClientsRepository repository,
    DocumentPipeline? documentPipeline,
    this.softGateConfirm,
    this.onFinished,
  })  : _repository = repository,
        _pipeline = documentPipeline;

  final ClientsRepository _repository;
  final DocumentPipeline? _pipeline;

  /// Injectable soft-gate dialog for tests.
  Future<bool> Function(List<String> missing)? softGateConfirm;

  /// Called after finish instead of navigation when set (tests).
  void Function(String clientId)? onFinished;

  static const maxStep = 6;
  static const stepLabels = [
    'Identity',
    'Address',
    'Preferences',
    'Contacts',
    'Representative',
    'Funding',
    'Legal',
  ];

  final step = 0.obs;
  final client = Rxn<ClientOut>();
  final errorMessage = RxnString();
  final isSaving = false.obs;
  final ndisFieldError = RxnString();

  // ── Identity ──────────────────────────────────────────────────────────
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final ndisCtrl = TextEditingController();
  final medicareCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
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
  final siteStateCtrl = TextEditingController(text: 'NSW');
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
  final siteState = 'NSW'.obs;
  final primarySiteSaved = false.obs;

  // ── Preferences ───────────────────────────────────────────────────────
  final preferredLanguageCtrl = TextEditingController();
  final culturalPreferencesCtrl = TextEditingController();
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
  final emergencySaved = false.obs;
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

  // ── Representative ────────────────────────────────────────────────────
  final representativeSaved = false.obs;
  final nomineeSkipped = false.obs;

  // ── Funding ───────────────────────────────────────────────────────────
  final planManagementType = RxnString();
  final planManagerNameCtrl = TextEditingController();
  final planManagerPhoneCtrl = TextEditingController();
  final planManagerEmailCtrl = TextEditingController();
  final planStartDate = Rxn<DateTime>();
  final planEndDate = Rxn<DateTime>();
  final budgetCoreCtrl = TextEditingController();
  final budgetCbCtrl = TextEditingController();
  final budgetCapitalCtrl = TextEditingController();
  final fundingNotToExceedCtrl = TextEditingController();
  final scNameCtrl = TextEditingController();
  final scPhoneCtrl = TextEditingController();
  final scEmailCtrl = TextEditingController();

  // ── Legal pack ────────────────────────────────────────────────────────
  final consentComplete = false.obs;
  final serviceAgreementComplete = false.obs;
  final acknowledgementComplete = false.obs;
  final includeAcknowledgement = false.obs;
  final consentSignerNameCtrl = TextEditingController();
  final formTemplates = <FormTemplateSummary>[].obs;
  final isLoadingTemplates = false.obs;
  FormTemplateSummary? get acknowledgementTemplate {
    for (final t in formTemplates) {
      if (t.isAcknowledgementPack) return t;
    }
    return null;
  }

  String? get clientId => client.value?.id;

  bool get requiresChildRepresentative =>
      dob.value != null && isUnder18(dob.value!);

  bool get nomineeOptional => !requiresChildRepresentative;

  String get representativeStepTitle => requiresChildRepresentative
      ? 'Child representative'
      : 'Nominee (optional)';

  @override
  void onInit() {
    super.onInit();
    siteNameCtrl.text = 'Home';
    contactRelationshipPreset.value = OnboardingKeys.relEmergency;
    contactDraftMode.value = 'emergency';
    loadFormTemplates();
  }

  @override
  void onClose() {
    fullName.dispose();
    email.dispose();
    phone.dispose();
    ndisCtrl.dispose();
    medicareCtrl.dispose();
    allergiesCtrl.dispose();
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
    contactNameCtrl.dispose();
    contactEmailCtrl.dispose();
    contactPhoneCtrl.dispose();
    contactRelationshipOtherCtrl.dispose();
    planManagerNameCtrl.dispose();
    planManagerPhoneCtrl.dispose();
    planManagerEmailCtrl.dispose();
    budgetCoreCtrl.dispose();
    budgetCbCtrl.dispose();
    budgetCapitalCtrl.dispose();
    fundingNotToExceedCtrl.dispose();
    scNameCtrl.dispose();
    scPhoneCtrl.dispose();
    scEmailCtrl.dispose();
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
      3 => await submitContacts(),
      4 => await submitRepresentative(),
      5 => await submitFunding(),
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
    ndisFieldError.value = null;

    final name = fullName.text.trim();
    final em = email.text.trim();
    final ph = phone.text.trim();
    final ndis = ndisCtrl.text.trim();

    if (name.isEmpty) {
      errorMessage.value = 'Full name is required.';
      return false;
    }
    if (em.isEmpty && ph.isEmpty) {
      errorMessage.value = 'Provide an email and/or phone number.';
      return false;
    }
    if (dob.value == null) {
      errorMessage.value = 'Date of birth (DOB) is required.';
      return false;
    }
    if (ndis.isEmpty) {
      errorMessage.value = 'NDIS number is required.';
      ndisFieldError.value = 'NDIS number is required.';
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
            email: em.isEmpty ? null : em,
            phone: ph.isEmpty ? null : ph,
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

      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.ndis,
        ProfileFactUpsert(valueJson: ndis),
      );

      final medicare = medicareCtrl.text.trim();
      if (medicare.isNotEmpty) {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.medicareCard,
          ProfileFactUpsert(valueJson: medicare),
        );
      }

      await _putOptionalFact(id, OnboardingKeys.sexGender, sexGender.value);
      await _putOptionalFact(id, OnboardingKeys.atsiStatus, atsiStatus.value);
      await _putOptionalFact(
        id,
        OnboardingKeys.referralSource,
        referralSource.value,
      );
      final allergies = allergiesCtrl.text.trim();
      if (allergies.isNotEmpty) {
        await _repository.upsertProfileFact(
          id,
          OnboardingKeys.allergies,
          ProfileFactUpsert(valueJson: allergies),
        );
      }

      if (step.value == 0) step.value = 1;
      return true;
    } on AppFailure catch (e) {
      if (e.code == 'ndis_number_in_use' || e.statusCode == 409) {
        ndisFieldError.value = e.message;
        errorMessage.value = e.message;
      } else {
        errorMessage.value = e.message;
      }
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
      await _putOptionalFact(
        id,
        OnboardingKeys.preferredContactMethod,
        preferredContactMethod.value,
      );
      if (step.value == 2) step.value = 3;
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
    contactRelationshipPreset.value = OnboardingKeys.relEmergency;
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

  void _resetContactDraft() {
    contactNameCtrl.clear();
    contactEmailCtrl.clear();
    contactPhoneCtrl.clear();
    contactRelationshipOtherCtrl.clear();
    contactIsPrimary.value = false;
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
    if (relationship == null || relationship.isEmpty) {
      errorMessage.value = 'Select a relationship.';
      return false;
    }

    isSaving.value = true;
    try {
      final created = await _repository.createContact(
        id,
        ClientContactWriteRequest(
          name: _nullIfEmpty(name),
          email: _nullIfEmpty(em),
          phone: _nullIfEmpty(ph),
          relationship: relationship,
          isPrimary: contactIsPrimary.value,
          notifyVisitComplete: false,
        ),
      );
      contactsCreated.add(created);
      if (relationship == OnboardingKeys.relEmergency) {
        emergencySaved.value = true;
      }
      if (relationship == OnboardingKeys.relCarer) {
        carerSaved.value = true;
      }
      if (relationship == OnboardingKeys.relChildRepresentative ||
          relationship == OnboardingKeys.relNominee) {
        representativeSaved.value = true;
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

  Future<bool> submitContacts() async {
    errorMessage.value = null;
    if (!emergencySaved.value) {
      // Try saving current draft if it looks like emergency.
      if (contactRelationshipPreset.value == OnboardingKeys.relEmergency &&
          (contactNameCtrl.text.trim().isNotEmpty ||
              contactPhoneCtrl.text.trim().isNotEmpty ||
              contactEmailCtrl.text.trim().isNotEmpty)) {
        final ok = await saveContactDraft();
        if (!ok) return false;
      }
    }
    if (!emergencySaved.value) {
      errorMessage.value = 'An emergency contact is required.';
      return false;
    }
    if (step.value == 3) step.value = 4;
    // Prep representative draft.
    _resetContactDraft();
    if (requiresChildRepresentative) {
      contactRelationshipPreset.value = OnboardingKeys.relChildRepresentative;
      contactDraftMode.value = 'representative';
    } else {
      contactRelationshipPreset.value = OnboardingKeys.relNominee;
      contactDraftMode.value = 'nominee';
    }
    return true;
  }

  // ── Representative ────────────────────────────────────────────────────

  Future<bool> submitRepresentative() async {
    errorMessage.value = null;

    if (requiresChildRepresentative) {
      if (!representativeSaved.value) {
        final hasDraft = contactNameCtrl.text.trim().isNotEmpty ||
            contactPhoneCtrl.text.trim().isNotEmpty ||
            contactEmailCtrl.text.trim().isNotEmpty;
        if (hasDraft) {
          contactRelationshipPreset.value =
              OnboardingKeys.relChildRepresentative;
          final ok = await saveContactDraft();
          if (!ok) return false;
        }
      }
      if (!representativeSaved.value) {
        errorMessage.value =
            'A child representative is required for participants under 18.';
        return false;
      }
    } else if (!representativeSaved.value && !nomineeSkipped.value) {
      final hasDraft = contactNameCtrl.text.trim().isNotEmpty ||
          contactPhoneCtrl.text.trim().isNotEmpty ||
          contactEmailCtrl.text.trim().isNotEmpty;
      if (hasDraft) {
        contactRelationshipPreset.value = OnboardingKeys.relNominee;
        final ok = await saveContactDraft();
        if (!ok) return false;
      } else {
        nomineeSkipped.value = true;
      }
    }

    if (step.value == 4) step.value = 5;
    return true;
  }

  void skipNominee() {
    nomineeSkipped.value = true;
    errorMessage.value = null;
  }

  // ── Funding ───────────────────────────────────────────────────────────

  Future<bool> submitFunding() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) {
      errorMessage.value = 'Create the client on the Identity step first.';
      return false;
    }

    final planType = planManagementType.value;
    if (planType == null || planType.isEmpty) {
      errorMessage.value = 'Plan management type is required.';
      return false;
    }

    if (planType == 'plan_managed') {
      final pmName = planManagerNameCtrl.text.trim();
      final pmPhone = planManagerPhoneCtrl.text.trim();
      final pmEmail = planManagerEmailCtrl.text.trim();
      if (pmName.isEmpty) {
        errorMessage.value = 'Plan manager name is required for plan-managed.';
        return false;
      }
      if (pmPhone.isEmpty && pmEmail.isEmpty) {
        errorMessage.value =
            'Plan manager phone or email is required for plan-managed.';
        return false;
      }
    }

    isSaving.value = true;
    try {
      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.planManagementType,
        ProfileFactUpsert(valueJson: planType),
      );
      if (planType == 'plan_managed') {
        await _putOptionalFact(
          id,
          OnboardingKeys.planManagerName,
          planManagerNameCtrl.text.trim(),
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
      await _putOptionalNumber(id, OnboardingKeys.budgetCore, budgetCoreCtrl);
      await _putOptionalNumber(id, OnboardingKeys.budgetCb, budgetCbCtrl);
      await _putOptionalNumber(
        id,
        OnboardingKeys.budgetCapital,
        budgetCapitalCtrl,
      );
      await _putOptionalNumber(
        id,
        OnboardingKeys.fundingNotToExceed,
        fundingNotToExceedCtrl,
      );
      await _putOptionalFact(
        id,
        OnboardingKeys.supportCoordinatorName,
        scNameCtrl.text.trim(),
      );
      await _putOptionalFact(
        id,
        OnboardingKeys.supportCoordinatorPhone,
        scPhoneCtrl.text.trim(),
      );
      await _putOptionalFact(
        id,
        OnboardingKeys.supportCoordinatorEmail,
        scEmailCtrl.text.trim(),
      );

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

  Future<bool> markConsentComplete() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) return false;
    final signer = consentSignerNameCtrl.text.trim();
    if (signer.isEmpty) {
      errorMessage.value = 'Enter the participant or representative name.';
      return false;
    }

    isSaving.value = true;
    try {
      final bytes = await _pickPdfBytes();
      if (bytes == null) {
        errorMessage.value = 'Select a Consent PDF to upload.';
        return false;
      }
      final docId = await _uploadClientFile(
        clientId: id,
        category: 'consent',
        name: bytes.name,
        contentType: 'application/pdf',
        fileBytes: bytes.bytes,
      );
      final legalDoc =
          await _repository.getLegalDocumentCurrent(OnboardingKeys.consentAgreement);
      await _repository.acceptClientLegal(
        id,
        OnboardingKeys.consentAgreement,
        ClientLegalAcceptRequest(
          eventType: 'consented',
          legalDocumentVersionId: legalDoc.id,
          participantOrRepName: signer,
          method: 'uploaded_scan',
          documentId: docId,
        ),
      );
      consentComplete.value = true;
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

  Future<bool> markServiceAgreementComplete() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) return false;

    isSaving.value = true;
    try {
      final bytes = await _pickPdfBytes();
      if (bytes == null) {
        errorMessage.value = 'Select a Service Agreement PDF to upload.';
        return false;
      }
      final docId = await _uploadClientFile(
        clientId: id,
        category: 'service_agreement',
        name: bytes.name,
        contentType: 'application/pdf',
        fileBytes: bytes.bytes,
      );
      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.serviceAgreement,
        ProfileFactUpsert(documentId: docId),
      );
      serviceAgreementComplete.value = true;
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

  Future<bool> markAcknowledgementComplete() async {
    errorMessage.value = null;
    final id = clientId;
    if (id == null) return false;

    isSaving.value = true;
    try {
      final bytes = await _pickPdfBytes();
      if (bytes == null) {
        errorMessage.value = 'Select an Acknowledgement PDF to upload.';
        return false;
      }
      final docId = await _uploadClientFile(
        clientId: id,
        category: 'acknowledgement',
        name: bytes.name,
        contentType: 'application/pdf',
        fileBytes: bytes.bytes,
      );
      await _repository.upsertProfileFact(
        id,
        OnboardingKeys.acknowledgement,
        ProfileFactUpsert(documentId: docId),
      );
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
      isSaving.value = false;
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
      } else {
        if (Get.isRegistered<ClientsController>()) {
          final cc = Get.find<ClientsController>();
          await cc.load();
          await cc.openDetail(updated);
        } else {
          Get.offNamed(AppRoutes.staffClientDetail, arguments: updated);
        }
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
