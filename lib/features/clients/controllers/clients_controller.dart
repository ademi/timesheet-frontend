import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../../shared/utils/name_sort.dart';
import '../../documents/data/document_pipeline.dart';
import '../../jobs/controllers/jobs_controller.dart';
import '../../jobs/data/models/job_models.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../jobs/utils/unified_support_args.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../data/models/client_models.dart';
import '../data/models/client_profile_models.dart';
import '../data/models/support_plan_models.dart';
import '../data/repositories/clients_repository.dart';
import '../utils/client_quick_facts.dart';
import '../utils/client_visit_windows.dart';
import '../utils/site_geocode_apply.dart';
import '../utils/support_plan_keys.dart';
import '../widgets/contact_form_host.dart';
import '../widgets/site_form_host.dart';
import 'requirement_draft.dart';

class ClientsController extends GetxController
    implements SiteFormHost, ContactFormHost {
  ClientsController({
    required ClientsRepository repository,
    required SessionService session,
    DocumentPipeline? documentPipeline,
    VisitsRepository? visitsRepository,
    JobsRepository? jobsRepository,
  })  : _repository = repository,
        _session = session,
        _pipeline = documentPipeline,
        _visits = visitsRepository,
        _jobs = jobsRepository;

  final ClientsRepository _repository;
  final SessionService _session;
  final DocumentPipeline? _pipeline;
  final VisitsRepository? _visits;
  final JobsRepository? _jobs;

  final items = <ClientOut>[].obs;
  /// When false (default), hide clients still mid-wizard (D19).
  final showIncompleteOnboarding = false.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final profileSaveProgress = RxnString();

  // Create / edit form
  final clientFormKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final status = 'active'.obs;
  ClientOut? editing;
  final isCreateFlow = false.obs;
  final createStepIndex = 0.obs;
  final createdClient = Rxn<ClientOut>();

  // Profile photo (create / edit form)
  final formPhoto = Rxn<ProfilePhotoOut>();
  final formLocalPhotoBytes = Rxn<List<int>>();
  final formPendingPhoto = Rxn<PickedProfilePhoto>();
  final isFormPhotoLoading = false.obs;
  final formPhotoCleared = false.obs;

  // Profile photo (detail page, read-only)
  final detailPhoto = Rxn<ProfilePhotoOut>();
  final isDetailPhotoLoading = false.obs;
  final photosByClient = <String, ProfilePhotoOut>{}.obs;

  // Client types / dynamic requirements
  final clientTypes = <ClientTypeOut>[].obs;
  final selectedClientTypeId = RxnString();
  final isLoadingTypes = false.obs;
  final isLoadingRequirements = false.obs;
  final requirementDrafts = <RequirementDraft>[].obs;

  // Detail
  final selected = Rxn<ClientOut>();
  final sites = <ClientSiteOut>[].obs;
  final contacts = <ClientContactOut>[].obs;
  final lastInvite = Rxn<ClientInviteCreateResponse>();
  final invites = <ClientInviteOut>[].obs;
  final tabIndex = 0.obs;
  final upcomingVisits = <VisitOut>[].obs;
  final pastVisits = <VisitOut>[].obs;
  final isLoadingVisits = false.obs;
  final visitsError = RxnString();
  final visitsTruncated = false.obs;
  final profileFacts = <ClientProfileFactOut>[].obs;
  final standingJob = Rxn<JobOut>();
  final isLoadingStandingJob = false.obs;
  final supportPlan = Rxn<SupportPlanDto>();
  final isLoadingSupportPlan = false.obs;

  String? get ndisNumber =>
      ndisFromFacts(profileFacts) ?? ndisFromDrafts(requirementDrafts);

  bool get isPatientType {
    final typeId = selectedClientTypeId.value ?? selected.value?.clientTypeId;
    for (final type in clientTypes) {
      if (type.id == typeId) {
        return isPatientClientType(typeName: type.name, typeCode: type.code);
      }
    }
    return isPatientClientType(typeName: quickFacts?.clientTypeName);
  }

  bool get showNdisCapturePrompt =>
      isPatientType && (ndisNumber == null || ndisNumber!.trim().isEmpty);

  ClientQuickFacts? get quickFacts {
    final c = selected.value;
    if (c == null) return null;
    final typeName = clientTypes
        .where((t) => t.id == (selectedClientTypeId.value ?? c.clientTypeId))
        .map((t) => t.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    return buildQuickFacts(
      client: c,
      ndisNumber: ndisNumber,
      clientTypeName: typeName,
    );
  }

  // Site form
  final siteNameCtrl = TextEditingController();
  final siteAddressCtrl = TextEditingController();
  final siteCityCtrl = TextEditingController();
  final siteStateCtrl = TextEditingController();
  final siteCountryCtrl = TextEditingController();
  final sitePostalCtrl = TextEditingController();
  final siteAccessNotesCtrl = TextEditingController();
  /// Held after geocode / edit hydrate; not shown on the site form.
  final siteLatCtrl = TextEditingController();
  final siteLngCtrl = TextEditingController();
  final siteIsPrimary = false.obs;
  final isGeocoding = false.obs;
  final geocodeHint = RxnString();
  /// Formatted address from last successful lookup (pending or confirmed).
  final geocodeFormattedAddress = RxnString();
  /// True after user confirms the geocode result (or edit hydrate with coords).
  final addressConfirmed = false.obs;
  /// Observable country/state for dropdowns (defaults AU / NSW).
  final siteCountry = 'AU'.obs;
  final siteState = 'NSW'.obs;
  ClientSiteOut? editingSite;

  // Contact form
  final contactNameCtrl = TextEditingController();
  final contactEmailCtrl = TextEditingController();
  final contactPhoneCtrl = TextEditingController();
  final contactRelationshipOtherCtrl = TextEditingController();
  /// Preset key (`emergency`/`carer`/…) or `_other` for free-text.
  final contactRelationshipPreset = RxnString();
  final contactIsPrimary = false.obs;
  /// Kept for API; UI toggle removed (D15). Defaults false on create.
  final contactNotify = false.obs;
  ClientContactOut? editingContact;

  /// Clients for the list UI — incomplete onboarding excluded unless toggled.
  List<ClientOut> get visibleItems {
    final list = items.toList();
    if (showIncompleteOnboarding.value) return list;
    return list.where((c) => !isOnboardingIncomplete(c)).toList();
  }

  static bool isOnboardingIncomplete(ClientOut client) =>
      client.metadata['onboarding_incomplete'] == true;

  bool get canManage =>
      _session.hasPermission(AppPermissions.clientsManage);
  bool get canRead => _session.hasPermission(AppPermissions.clientsRead);
  bool get canReadTypes =>
      _session.hasPermission(AppPermissions.clientsTypesRead) || canManage;
  bool get canManageProfile =>
      _session.hasPermission(AppPermissions.clientsProfileManage) || canManage;
  bool get canUploadDocs =>
      _session.hasPermission(AppPermissions.documentsUpload) ||
      _session.hasPermission(AppPermissions.clientsDocsManage);
  bool get canViewVisits =>
      _session.hasPermission(AppPermissions.visitsRead) ||
      _session.hasPermission(AppPermissions.visitsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);
  bool get canManageSupport =>
      _session.hasPermission(AppPermissions.jobsManage);
  bool get hasOngoing => standingJob.value != null;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _disposeRequirementDrafts();
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    notesCtrl.dispose();
    siteNameCtrl.dispose();
    siteAddressCtrl.dispose();
    siteCityCtrl.dispose();
    siteStateCtrl.dispose();
    siteCountryCtrl.dispose();
    sitePostalCtrl.dispose();
    siteAccessNotesCtrl.dispose();
    siteLatCtrl.dispose();
    siteLngCtrl.dispose();
    contactNameCtrl.dispose();
    contactEmailCtrl.dispose();
    contactPhoneCtrl.dispose();
    contactRelationshipOtherCtrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing clients.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      items.assignAll(await _repository.listClients());
      photosByClient.clear();
      _ensureListPhotosLoaded();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openCreate() async {
    isCreateFlow.value = false;
    createStepIndex.value = 0;
    createdClient.value = null;
    selected.value = null;
    editing = null;
    nameCtrl.clear();
    emailCtrl.clear();
    phoneCtrl.clear();
    notesCtrl.clear();
    status.value = 'active';
    errorMessage.value = null;
    profileSaveProgress.value = null;
    _resetFormPhoto();
    Get.toNamed(AppRoutes.staffClientOnboarding);
  }

  Future<void> openEdit(ClientOut client) async {
    isCreateFlow.value = false;
    createStepIndex.value = 0;
    createdClient.value = null;
    editing = client;
    nameCtrl.text = client.fullName;
    emailCtrl.text = client.email ?? '';
    phoneCtrl.text = client.phone ?? '';
    notesCtrl.text = client.serviceAgreementNotes ?? '';
    status.value = client.status;
    errorMessage.value = null;
    profileSaveProgress.value = null;
    _resetFormPhoto();
    Get.toNamed(AppRoutes.staffClientForm, arguments: client);
    await loadFormProfilePhoto(client.id);
  }

  void _resetFormPhoto() {
    formPhoto.value = null;
    formLocalPhotoBytes.value = null;
    formPendingPhoto.value = null;
    formPhotoCleared.value = false;
    isFormPhotoLoading.value = false;
  }

  Future<void> loadFormProfilePhoto(String clientId) async {
    isFormPhotoLoading.value = true;
    try {
      final photo = await _repository.getClientProfilePhoto(clientId);
      formPhoto.value = photo;
      formLocalPhotoBytes.value = null;
      formPendingPhoto.value = null;
      formPhotoCleared.value = false;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
    } finally {
      isFormPhotoLoading.value = false;
    }
  }

  Future<void> _ensureListPhotosLoaded() async {
    if (!canRead) return;
    final ids = items.map((c) => c.id).where((id) => id.isNotEmpty).toSet();
    final pending = ids.where((id) => !photosByClient.containsKey(id)).toList();
    if (pending.isEmpty) return;
    final results = await Future.wait(
      pending.map((id) async {
        try {
          return MapEntry(id, await _repository.getClientProfilePhoto(id));
        } on AppFailure {
          return MapEntry(id, null);
        } catch (_) {
          return MapEntry(id, null);
        }
      }),
    );
    for (final entry in results) {
      final photo = entry.value;
      if (photo != null) {
        photosByClient[entry.key] = photo;
      }
    }
  }

  Future<void> openExistingRequirementDocument(RequirementDraft draft) async {
    final id = draft.existingDocumentId.value;
    if (id == null || _pipeline == null) return;
    try {
      await _pipeline!.openDocument(id);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  void onFormPhotoPicked(PickedProfilePhoto picked) {
    formPendingPhoto.value = picked;
    formLocalPhotoBytes.value = picked.bytes;
    formPhotoCleared.value = false;
  }

  void clearFormPhoto() {
    formPendingPhoto.value = null;
    formLocalPhotoBytes.value = null;
    formPhotoCleared.value = true;
    if (editing == null) {
      formPhoto.value = null;
    }
  }

  Future<void> _persistFormPhoto(String clientId) async {
    final pending = formPendingPhoto.value;
    if (pending != null) {
      profileSaveProgress.value = 'Uploading profile photo…';
      final docId = await _uploadClientFiles(
        clientId: clientId,
        category: 'client_photo',
        files: [
          PickedClientFile(
            name: pending.name,
            contentType: pending.contentType,
            bytes: pending.bytes,
          ),
        ],
      );
      if (docId == null) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Profile photo upload failed.',
          presentation: AppFailurePresentation.inline,
        );
      }
      formPhoto.value = await _repository.setClientProfilePhoto(clientId, docId);
      formPendingPhoto.value = null;
      formPhotoCleared.value = false;
      return;
    }

    if (formPhotoCleared.value && editing != null) {
      formPhoto.value = await _repository.clearClientProfilePhoto(clientId);
      formPhotoCleared.value = false;
    }
  }

  Future<void> loadClientTypes() async {
    if (!canReadTypes) return;
    isLoadingTypes.value = true;
    try {
      final types = await _repository.listClientTypes();
      clientTypes.assignAll(
        sortedByName(types.where((t) => t.isActive), (t) => t.name),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoadingTypes.value = false;
    }
  }

  Future<void> onClientTypeChanged(String? typeId) async {
    if (typeId == null || typeId.isEmpty) {
      selectedClientTypeId.value = null;
      _disposeRequirementDrafts();
      requirementDrafts.clear();
      return;
    }
    if (selectedClientTypeId.value == typeId && requirementDrafts.isNotEmpty) {
      return;
    }
    selectedClientTypeId.value = typeId;
    await _loadRequirementsForType(typeId);
  }

  Future<void> _loadRequirementsForType(String typeId) async {
    isLoadingRequirements.value = true;
    errorMessage.value = null;
    try {
      final reqs = await _repository.listTypeRequirements(typeId);
      _disposeRequirementDrafts();
      final drafts = reqs.map(RequirementDraft.new).toList();
      requirementDrafts.assignAll(drafts);
      for (final draft in drafts) {
        if (draft.requirement.isLegal &&
            draft.requirement.legalDocKey != null) {
          _loadLegalDoc(draft);
        }
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      _disposeRequirementDrafts();
      requirementDrafts.clear();
    } catch (e) {
      errorMessage.value = e.toString();
      _disposeRequirementDrafts();
      requirementDrafts.clear();
    } finally {
      isLoadingRequirements.value = false;
    }
  }

  Future<void> _prefillFromProfile(String clientId) async {
    if (!canManageProfile && !canRead) return;
    try {
      final bundle = await _repository.getClientProfile(clientId);
      profileFacts.assignAll(bundle.facts);
      if (bundle.requirements.isNotEmpty && requirementDrafts.isEmpty) {
        _disposeRequirementDrafts();
        requirementDrafts.assignAll(
          bundle.requirements.map(RequirementDraft.new).toList(),
        );
      }
      if (bundle.clientType != null) {
        selectedClientTypeId.value = bundle.clientType!.id;
      }
      final factByKey = {
        for (final f in bundle.facts) f.requirementKey: f,
      };
      final formByKey = {
        for (final f in bundle.formSubmissions) f.requirementKey: f,
      };
      final legalByKey = {
        for (final f in bundle.legalAcceptances) f.requirementKey: f,
      };
      for (final draft in requirementDrafts) {
        final key = draft.requirement.requirementKey;
        final fact = factByKey[key];
        if (fact != null) draft.applyFact(fact);
        final form = formByKey[key];
        if (form != null) draft.applyForm(form);
        final legal = legalByKey[key];
        if (legal != null) draft.applyLegal(legal);
        if (draft.requirement.isLegal &&
            draft.requirement.legalDocKey != null &&
            draft.legalDoc.value == null) {
          _loadLegalDoc(draft);
        }
      }
      // Prefill DOB from core client if requirement empty.
      for (final draft in requirementDrafts) {
        if (draft.requirement.requirementKey != 'dob') continue;
        final coreDob = selected.value?.dob ?? editing?.dob;
        if (draft.dateValue.value == null && coreDob != null) {
          draft.dateValue.value = DateTime.tryParse(coreDob);
        }
        break;
      }
    } on AppFailure catch (e) {
      // Soft: edit still works with core fields.
      errorMessage.value ??= e.message;
    } catch (_) {}
  }

  Future<void> _loadLegalDoc(RequirementDraft draft) async {
    final key = draft.requirement.legalDocKey;
    if (key == null || key.isEmpty) return;
    draft.legalLoading.value = true;
    try {
      draft.legalDoc.value = await _repository.getLegalDocumentCurrent(key);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      draft.legalLoading.value = false;
    }
  }

  Future<void> pickFilesForRequirement(RequirementDraft draft) async {
    final accept = draft.requirement.acceptMimeTypes;
    final extensions = _extensionsFromAccept(accept);
    final allowMultiple = draft.requirement.maxFiles > 1;
    final remaining =
        draft.requirement.maxFiles - draft.localFiles.length;
    if (remaining <= 0) {
      errorMessage.value =
          'Maximum ${draft.requirement.maxFiles} file(s) for this field.';
      return;
    }

    final picked = <PickedClientFile>[];
    if (_acceptIsImagesOnly(accept, extensions)) {
      final galleryFiles = await _pickImagesFromGallery(
        allowMultiple: allowMultiple && remaining > 1,
        maxCount: remaining,
      );
      picked.addAll(galleryFiles);
    } else {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: allowMultiple && remaining > 1,
        type: extensions.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: extensions.isEmpty ? null : extensions,
      );
      if (result == null || result.files.isEmpty) return;

      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        picked.add(
          PickedClientFile(
            name: file.name,
            contentType: _guessContentType(file.extension, file.name),
            bytes: bytes,
          ),
        );
        if (draft.localFiles.length + picked.length >=
            draft.requirement.maxFiles) {
          break;
        }
      }
    }
    if (picked.isEmpty) {
      errorMessage.value = 'Could not read file bytes.';
      return;
    }
    draft.localFiles.addAll(picked);
  }

  static bool _acceptIsImagesOnly(
    List<String> accept,
    List<String> extensions,
  ) {
    const imageExts = {'png', 'jpg', 'jpeg', 'webp', 'heic', 'heif', 'gif'};
    if (accept.isNotEmpty) {
      final lower = accept.map((e) => e.toLowerCase()).toList();
      final hasNonImage = lower.any(
        (m) =>
            m.contains('pdf') ||
            m.contains('msword') ||
            m.contains('officedocument') ||
            m.contains('application/'),
      );
      if (hasNonImage) return false;
      return lower.every(
        (m) =>
            m.startsWith('image/') ||
            m == 'image/*' ||
            imageExts.any((e) => m.contains(e)),
      );
    }
    return extensions.isNotEmpty &&
        extensions.every((e) => imageExts.contains(e.toLowerCase()));
  }

  Future<List<PickedClientFile>> _pickImagesFromGallery({
    required bool allowMultiple,
    required int maxCount,
  }) async {
    final picker = ImagePicker();
    final out = <PickedClientFile>[];
    if (allowMultiple && maxCount > 1) {
      final files = await picker.pickMultiImage(
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 88,
      );
      for (final file in files.take(maxCount)) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        final name = file.name.trim().isEmpty ? 'image.jpg' : file.name;
        out.add(
          PickedClientFile(
            name: name,
            contentType: _guessContentType(null, name),
            bytes: bytes,
          ),
        );
      }
      return out;
    }
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 88,
    );
    if (file == null) return out;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return out;
    final name = file.name.trim().isEmpty ? 'image.jpg' : file.name;
    out.add(
      PickedClientFile(
        name: name,
        contentType: _guessContentType(null, name),
        bytes: bytes,
      ),
    );
    return out;
  }

  void removePickedFile(RequirementDraft draft, int index) {
    if (index < 0 || index >= draft.localFiles.length) return;
    draft.localFiles.removeAt(index);
  }

  Future<void> pickDateForRequirement(RequirementDraft draft) async {
    final now = DateTime.now();
    final initial = draft.dateValue.value ?? DateTime(now.year - 30);
    final picked = await showDatePicker(
      context: Get.context!,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      draft.dateValue.value = picked;
    }
  }

  Future<void> saveClient() async {
    final form = clientFormKey.currentState;
    if (form == null || !form.validate()) {
      errorMessage.value =
          'Please complete the required client details before saving.';
      return;
    }

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (name.isEmpty) {
      errorMessage.value = 'Full name is required.';
      return;
    }
    if (email.isEmpty && phone.isEmpty) {
      errorMessage.value = 'Provide an email and/or phone number.';
      return;
    }

    isSaving.value = true;
    errorMessage.value = null;
    profileSaveProgress.value = null;
    try {
      if (editing == null) {
        final patientTypeId = await _resolveDefaultPatientTypeId();
        final created = await _repository.createClient(
          ClientCreateRequest(
            fullName: name,
            status: status.value,
            email: email.isEmpty ? null : email,
            phone: phone.isEmpty ? null : phone,
            clientTypeId: patientTypeId,
          ),
        );
        if (formPendingPhoto.value != null) {
          try {
            await _persistFormPhoto(created.id);
          } on AppFailure catch (e) {
            Get.back();
            await load();
            openDetail(created, initialTab: ClientsController.tabOverview);
            Get.snackbar(
              'Client saved',
              'Profile photo failed: ${e.message}',
              snackPosition: SnackPosition.BOTTOM,
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 6),
            );
            return;
          }
        }
        if (isCreateFlow.value) {
          createdClient.value = created;
          editing = created;
          selected.value = created;
          await openDetailById(created.id);
          return;
        }
        Get.back();
        await load();
        openDetail(created, initialTab: ClientsController.tabDetails);
      } else {
        await _repository.patchClient(
          editing!.id,
          ClientUpdateRequest(
            fullName: name,
            status: status.value,
            email: email,
            phone: phone,
            serviceAgreementNotes: notesCtrl.text.trim(),
          ),
        );
        if (formPendingPhoto.value != null || formPhotoCleared.value) {
          await _persistFormPhoto(editing!.id);
        }
        if (isCreateFlow.value) {
          await openDetailById(editing!.id);
          return;
        }
        Get.back();
        await load();
        if (selected.value?.id == editing!.id) {
          await openDetailById(editing!.id);
        }
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
      profileSaveProgress.value = null;
    }
  }

  Future<String?> _resolveDefaultPatientTypeId() async {
    if (!canReadTypes) return null;
    if (clientTypes.isEmpty) {
      await loadClientTypes();
    }
    for (final type in clientTypes) {
      final code = type.code.trim().toLowerCase();
      final name = type.name.trim().toLowerCase();
      if (code == 'patient' || name == 'patient') {
        selectedClientTypeId.value = type.id;
        return type.id;
      }
    }
    return null;
  }

  Future<void> continueCreateFlow() async {
    errorMessage.value = null;
    if (createStepIndex.value == 0) {
      final hadClient = createdClient.value != null;
      await saveClient();
      if (createdClient.value != null || hadClient) {
        createStepIndex.value = 1;
      }
      return;
    }
    if (createStepIndex.value < 3) {
      createStepIndex.value++;
    }
  }

  void backCreateFlow() {
    if (createStepIndex.value > 0) {
      createStepIndex.value--;
    }
  }

  Future<void> finishCreateFlow() async {
    final client = createdClient.value ?? selected.value;
    if (client == null) {
      await continueCreateFlow();
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    profileSaveProgress.value = null;
    try {
      final typeId =
          selectedClientTypeId.value ?? await _resolveDefaultPatientTypeId();
      final dob = _resolveDobForCore();
      await _repository.patchClient(
        client.id,
        ClientUpdateRequest(
          clientTypeId: typeId,
          dob: dob,
        ),
      );
      if (typeId != null && typeId.isNotEmpty && requirementDrafts.isNotEmpty) {
        for (final draft in requirementDrafts) {
          if (!draft.requirement.isRequired) continue;
          if (draft.hasAnyContent) continue;
          errorMessage.value = '${draft.requirement.label} is required.';
          return;
        }
        final profileErrors = await _saveDynamicAnswers(client.id);
        if (profileErrors.isNotEmpty) {
          Get.snackbar(
            'Saved with warnings',
            profileErrors.take(3).join('\n'),
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 6),
          );
        }
      }
      isCreateFlow.value = false;
      Get.back();
      await load();
      await openDetail(client, initialTab: ClientsController.tabDetails);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
      profileSaveProgress.value = null;
    }
  }

  /// Saves client type + profile requirements from the Types tab.
  Future<void> saveClientTypeProfile() async {
    final client = selected.value;
    if (client == null) return;

    for (final draft in requirementDrafts) {
      if (!draft.requirement.isRequired) continue;
      if (draft.hasAnyContent) continue;
      errorMessage.value = '${draft.requirement.label} is required.';
      return;
    }

    isSaving.value = true;
    errorMessage.value = null;
    profileSaveProgress.value = null;
    try {
      final typeId = selectedClientTypeId.value;
      final dob = _resolveDobForCore();
      await _repository.patchClient(
        client.id,
        ClientUpdateRequest(
          clientTypeId: typeId,
          dob: dob,
        ),
      );
      final profileErrors = typeId == null || typeId.isEmpty
          ? <String>[]
          : await _saveDynamicAnswers(client.id);
      await openDetailById(client.id);
      tabIndex.value = tabDetails;
      if (profileErrors.isNotEmpty) {
        Get.snackbar(
          'Saved with warnings',
          profileErrors.take(3).join('\n'),
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 6),
        );
      } else {
        Get.snackbar(
          'Saved',
          'Client type and profile updated. Create an invite next.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
      profileSaveProgress.value = null;
    }
  }

  String? _resolveDobForCore() {
    for (final draft in requirementDrafts) {
      if (draft.requirement.requirementKey != 'dob') continue;
      final d = draft.dateValue.value;
      if (d == null) return selected.value?.dob ?? editing?.dob;
      return RequirementDraft.formatDate(d);
    }
    return selected.value?.dob ?? editing?.dob;
  }

  Future<List<String>> _saveDynamicAnswers(String clientId) async {
    final errors = <String>[];
    final total = requirementDrafts.where((d) => d.hasAnyContent).length;
    var done = 0;

    for (final draft in requirementDrafts) {
      if (!draft.hasAnyContent) continue;

      done++;
      profileSaveProgress.value =
          'Saving profile ($done/$total): ${draft.requirement.label}';

      try {
        await _saveOneRequirement(clientId, draft);
      } on AppFailure catch (e) {
        errors.add('${draft.requirement.label}: ${e.message}');
      } catch (e) {
        errors.add('${draft.requirement.label}: $e');
      }
    }
    return errors;
  }

  Future<void> _saveOneRequirement(
    String clientId,
    RequirementDraft draft,
  ) async {
    final req = draft.requirement;

    if (req.isForm) {
      final payload = draft.formPayload;
      if (payload == null) return;
      await _repository.submitClientForm(
        clientId,
        req.requirementKey,
        ClientFormSubmitRequest(status: 'submitted', payloadJson: payload),
      );
      return;
    }

    if (req.isLegal) {
      if (!draft.legalAccepted.value) return;
      final name = draft.participantNameCtrl.text.trim();
      if (name.isEmpty) {
        throw const AppFailure(
          code: 'attestation_required',
          message: 'Consent requires participant name and method.',
          presentation: AppFailurePresentation.inline,
        );
      }
      final doc = draft.legalDoc.value;
      if (doc == null || doc.id.isEmpty) {
        throw const AppFailure(
          code: 'legal_version_unavailable',
          message: 'Legal document text is unavailable.',
          presentation: AppFailurePresentation.inline,
        );
      }
      final method = draft.method.value;
      var note = draft.noteCtrl.text.trim();
      if (method == 'uploaded_scan') {
        if (draft.localFiles.isEmpty) {
          throw const AppFailure(
            code: 'scan_required',
            message: 'Upload a scanned consent document for this method.',
            presentation: AppFailurePresentation.inline,
          );
        }
        final scanDocId = await _uploadClientFiles(
          clientId: clientId,
          category: req.documentCategory ?? 'consent_scan',
          files: draft.localFiles,
        );
        if (scanDocId == null || scanDocId.isEmpty) {
          throw const AppFailure(
            code: 'scan_upload_failed',
            message: 'Could not upload the consent scan.',
            presentation: AppFailurePresentation.inline,
          );
        }
        final scanNote = 'Uploaded scan document_id=$scanDocId';
        note = note.isEmpty ? scanNote : '$note\n$scanNote';
      }
      await _repository.acceptClientLegal(
        clientId,
        req.requirementKey,
        ClientLegalAcceptRequest(
          eventType: 'consented',
          legalDocumentVersionId: doc.id,
          participantOrRepName: name,
          relationship: draft.relationshipCtrl.text.trim().nullIfEmpty,
          method: method,
          note: note.nullIfEmpty,
        ),
      );
      return;
    }

    String? uploadedDocId;
    if (draft.capturesDocument && draft.localFiles.isNotEmpty) {
      uploadedDocId = await _uploadClientFiles(
        clientId: clientId,
        category: req.documentCategory ?? req.requirementKey,
        files: draft.localFiles,
      );
    }

    if (draft.capturesField || req.isSharingFlag) {
      final value = draft.fieldValueJson;
      final shouldPutValue = draft.hasFieldContent && value != null;
      final shouldLinkDoc =
          uploadedDocId != null && draft.capturesField;
      if (shouldPutValue || shouldLinkDoc) {
        await _repository.upsertProfileFact(
          clientId,
          req.requirementKey,
          ProfileFactUpsert(
            valueJson: shouldPutValue ? value : null,
            documentId: shouldLinkDoc ? uploadedDocId : null,
          ),
        );
      }
    } else if (uploadedDocId != null && draft.capturesDocument) {
      // Document-only: upload with category is enough; link for UX.
      await _repository.upsertProfileFact(
        clientId,
        req.requirementKey,
        ProfileFactUpsert(documentId: uploadedDocId),
      );
    }
  }

  Future<String?> _uploadClientFiles({
    required String clientId,
    required String category,
    required List<PickedClientFile> files,
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

    String? lastId;
    for (final file in files) {
      final doc = await pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'client',
          ownerId: clientId,
          filename: file.name,
          contentType: file.contentType,
          sizeBytes: file.bytes.length,
          category: category,
        ),
        bytes: file.bytes,
      );
      lastId = doc.id;
    }
    return lastId;
  }

  void _disposeRequirementDrafts() {
    for (final d in requirementDrafts) {
      d.dispose();
    }
  }

  Future<void> deleteClient(ClientOut client) async {
    final ok = await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Delete client?'),
            content: Text('Delete ${client.fullName}? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    isSaving.value = true;
    try {
      await _repository.deleteClient(client.id);
      await load();
      if (Get.currentRoute.startsWith(AppRoutes.staffClientDetail)) {
        Get.back();
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  /// Tab indices on client detail.
  static const tabOverview = 0;
  static const tabSupport = 1;
  static const tabLocations = 2;
  static const tabSites = 2;
  static const tabContacts = 3;
  static const tabDetails = 4;

  Future<void> openDetail(
    ClientOut client, {
    int initialTab = tabOverview,
  }) async {
    selected.value = client;
    lastInvite.value = null;
    invites.clear();
    tabIndex.value = initialTab;
    selectedClientTypeId.value = client.clientTypeId;
    detailPhoto.value = null;
    upcomingVisits.clear();
    pastVisits.clear();
    visitsError.value = null;
    visitsTruncated.value = false;
    profileFacts.clear();
    standingJob.value = null;
    supportPlan.value = null;
    _disposeRequirementDrafts();
    requirementDrafts.clear();
    Get.toNamed(AppRoutes.staffClientDetail, arguments: client);
    await openDetailById(client.id);
  }

  Future<void> openDetailById(String id) async {
    isLoading.value = true;
    try {
      final client = await _repository.getClient(id);
      selected.value = client;
      await Future.wait([
        refreshDetailExtras(),
        loadTypeTabForSelected(),
        loadDetailProfilePhoto(id),
      ]);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadDetailProfilePhoto(String clientId) async {
    isDetailPhotoLoading.value = true;
    try {
      detailPhoto.value = await _repository.getClientProfilePhoto(clientId);
    } on AppFailure {
      detailPhoto.value = null;
    } catch (_) {
      detailPhoto.value = null;
    } finally {
      isDetailPhotoLoading.value = false;
    }
  }

  /// Loads types list + requirements/profile for the Details tab.
  Future<void> loadTypeTabForSelected() async {
    final client = selected.value;
    if (client == null) return;
    await loadClientTypes();
    selectedClientTypeId.value = client.clientTypeId;
    _disposeRequirementDrafts();
    requirementDrafts.clear();
    var typeId = client.clientTypeId;
    if (typeId == null || typeId.isEmpty) {
      typeId = await _resolveDefaultPatientTypeId();
    }
    if (typeId != null && typeId.isNotEmpty) {
      selectedClientTypeId.value = typeId;
      await _loadRequirementsForType(typeId);
    }
    await _prefillFromProfile(client.id);
  }

  Future<void> refreshDetailExtras() async {
    final id = selected.value?.id;
    if (id == null) return;
    try {
      final results = await Future.wait([
        _repository.listSites(id),
        _repository.listContacts(id),
      ]);
      sites.assignAll(results[0] as List<ClientSiteOut>);
      contacts.assignAll(results[1] as List<ClientContactOut>);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
    await loadClientVisits();
    await loadStandingJob();
    await loadSupportPlanSummary();
  }

  Future<void> loadSupportPlanSummary() async {
    final id = selected.value?.id;
    if (id == null || !canRead) {
      supportPlan.value = null;
      return;
    }
    isLoadingSupportPlan.value = true;
    try {
      final plans = await _repository.listSupportPlans(id);
      SupportPlanDto? pick;
      for (final p in plans) {
        if (p.status == SupportPlanKeys.statusActive) {
          pick = p;
          break;
        }
      }
      pick ??= plans.isNotEmpty ? plans.first : null;
      supportPlan.value = pick;
    } on AppFailure {
      supportPlan.value = null;
    } catch (_) {
      supportPlan.value = null;
    } finally {
      isLoadingSupportPlan.value = false;
    }
  }

  Future<void> openSupportPlan() async {
    final client = selected.value;
    if (client == null || !canManage) return;
    await Get.toNamed(
      AppRoutes.staffClientSupportPlan,
      arguments: {
        'clientId': client.id,
        'planId': supportPlan.value?.id,
        'clientName': client.fullName,
        'ndisNumber': ndisNumber,
      },
    );
    await loadSupportPlanSummary();
  }

  Future<void> loadStandingJob() async {
    final client = selected.value;
    final jobsRepo = _jobs;
    if (client == null || jobsRepo == null) {
      standingJob.value = null;
      return;
    }
    if (!_session.hasPermission(AppPermissions.jobsRead) &&
        !_session.hasPermission(AppPermissions.jobsManage)) {
      standingJob.value = null;
      return;
    }
    isLoadingStandingJob.value = true;
    try {
      final list = await jobsRepo.listJobs();
      standingJob.value = list
          .where(
            (job) =>
                job.clientId == client.id && job.isStanding && job.isOpen,
          )
          .firstOrNull;
    } on AppFailure {
      standingJob.value = null;
    } catch (_) {
      standingJob.value = null;
    } finally {
      isLoadingStandingJob.value = false;
    }
  }

  void startOngoingSupport() {
    final client = selected.value;
    if (client == null) return;
    Get.toNamed(
      AppRoutes.staffUnifiedSupport,
      arguments: UnifiedSupportArgs.forClient(
        client,
        mode: UnifiedSupportMode.ongoing,
      ),
    );
  }

  /// Opens the client's ongoing support detail. Prefers the already-loaded
  /// standing job; otherwise resolves it fresh via `GET .../ongoing-support`.
  Future<void> openOngoingSupport() async {
    var job = standingJob.value;
    if (job == null) {
      final client = selected.value;
      final jobsRepo = _jobs;
      if (client == null || jobsRepo == null) return;
      try {
        job = await jobsRepo.getOngoingSupport(client.id);
        standingJob.value = job;
      } on AppFailure catch (e) {
        errorMessage.value = e.message;
        return;
      } catch (_) {
        return;
      }
    }
    if (Get.isRegistered<JobsController>()) {
      Get.find<JobsController>().openDetail(job);
      return;
    }
    Get.toNamed(
      AppRoutes.staffJobDetail,
      arguments: job,
      parameters: {'id': job.id},
    );
  }

  /// Client-first book-one: open the unified support composer in one-session mode.
  void bookOneSession() {
    final client = selected.value;
    if (client == null) return;
    Get.toNamed(
      AppRoutes.staffUnifiedSupport,
      arguments: UnifiedSupportArgs.forClient(
        client,
        mode: UnifiedSupportMode.oneSession,
      ),
    );
  }

  Future<void> loadClientVisits() async {
    final id = selected.value?.id;
    final visitsRepo = _visits;
    upcomingVisits.clear();
    pastVisits.clear();
    if (id == null || visitsRepo == null) {
      visitsTruncated.value = false;
      return;
    }
    if (!_session.hasPermission(AppPermissions.visitsRead) &&
        !_session.hasPermission(AppPermissions.visitsManage) &&
        !_session.hasPermission(AppPermissions.jobsManage)) {
      upcomingVisits.clear();
      pastVisits.clear();
      visitsError.value = null;
      visitsTruncated.value = false;
      return;
    }
    isLoadingVisits.value = true;
    visitsError.value = null;
    try {
      final now = DateTime.now().toUtc();
      final list = await visitsRepo.listVisits(
        clientId: id,
        from: now.subtract(clientVisitLookback),
        to: now.add(clientVisitLookahead),
        limit: clientVisitFetchLimit,
      );
      visitsTruncated.value = list.length >= clientVisitFetchLimit;
      final parts = partitionClientVisits(list, now: now);
      upcomingVisits.assignAll(parts.upcoming);
      pastVisits.assignAll(parts.past);
    } on AppFailure catch (e) {
      visitsError.value = e.message;
      upcomingVisits.clear();
      pastVisits.clear();
    } finally {
      isLoadingVisits.value = false;
    }
  }

  void openVisitDetail(VisitOut visit) {
    Get.toNamed(
      AppRoutes.staffVisitDetail,
      arguments: <String, dynamic>{
        'visit': visit,
        'skipBoardLoad': true,
      },
    );
  }

  void beginSiteForm({ClientSiteOut? site}) {
    editingSite = site;
    siteNameCtrl.text = site?.name ?? '';
    siteAddressCtrl.text = site?.addressLine1 ?? '';
    siteCityCtrl.text = site?.city ?? '';
    final state = (site?.state?.trim().isNotEmpty == true)
        ? site!.state!.trim().toUpperCase()
        : 'NSW';
    siteStateCtrl.text = state;
    siteCountryCtrl.text = 'AU';
    siteState.value = state;
    siteCountry.value = 'AU';
    sitePostalCtrl.text = site?.postalCode ?? '';
    siteAccessNotesCtrl.text = site?.accessNotes ?? '';
    siteLatCtrl.text = site?.latitude?.toString() ?? '';
    siteLngCtrl.text = site?.longitude?.toString() ?? '';
    siteIsPrimary.value = site?.isPrimary ?? false;
    errorMessage.value = null;
    geocodeHint.value = null;
    geocodeFormattedAddress.value = null;
    // Existing sites with coords are treated as already confirmed.
    addressConfirmed.value = site?.hasCoordinates ?? false;
    Get.toNamed(AppRoutes.staffClientSiteForm);
  }

  /// Clears pending/confirmed geocode so the user can re-edit and look up again.
  void invalidateSiteAddressConfirm() {
    if (!addressConfirmed.value && geocodeFormattedAddress.value == null) {
      return;
    }
    addressConfirmed.value = false;
    geocodeFormattedAddress.value = null;
    siteLatCtrl.clear();
    siteLngCtrl.clear();
    geocodeHint.value = null;
  }

  /// Explicit look-up for the confirm UX (does not mark confirmed).
  Future<void> lookupSiteAddress() async {
    addressConfirmed.value = false;
    final coords = await geocodeFromAddress(showSuccessHint: false);
    if (coords == null) {
      geocodeFormattedAddress.value = null;
      return;
    }
    // formatted address already set inside geocodeFromAddress on success
  }

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

  void editSiteAddress() {
    addressConfirmed.value = false;
    geocodeFormattedAddress.value = null;
    siteLatCtrl.clear();
    siteLngCtrl.clear();
    geocodeHint.value = null;
    errorMessage.value = null;
  }

  /// Resolves lat/lng from address via `POST /v1/public/geocode`.
  Future<({double lat, double lng})?> geocodeFromAddress({
    bool showSuccessHint = true,
  }) async {
    final address = siteAddressCtrl.text.trim();
    final city = siteCityCtrl.text.trim();
    final state = siteState.value.trim().isNotEmpty
        ? siteState.value.trim()
        : siteStateCtrl.text.trim();
    const country = 'AU';
    siteCountryCtrl.text = country;
    siteCountry.value = country;

    if (address.isEmpty || city.isEmpty) {
      errorMessage.value =
          'Enter street address and city before looking up.';
      return null;
    }

    isGeocoding.value = true;
    errorMessage.value = null;
    geocodeHint.value = null;
    try {
      final result = await _repository.geocode(
        GeocodeRequest(
          addressLine1: address,
          city: city,
          state: state.nullIfEmpty,
          country: country,
        ),
      );
      final outcome = applyGeocodeResponse(
        result: result,
        latCtrl: siteLatCtrl,
        lngCtrl: siteLngCtrl,
        formattedAddress: geocodeFormattedAddress,
        addressConfirmed: addressConfirmed,
        addressFallback:
            '${siteAddressCtrl.text.trim()}, ${siteCityCtrl.text.trim()}',
      );
      if (!outcome.accepted) {
        errorMessage.value = outcome.errorMessage;
        return null;
      }
      if (showSuccessHint) {
        final parts = <String>[
          if (result.formattedAddress != null &&
              result.formattedAddress!.isNotEmpty)
            result.formattedAddress!,
          if (result.confidence != null) 'confidence: ${result.confidence}',
        ];
        geocodeHint.value = parts.isEmpty
            ? 'Coordinates found from address.'
            : parts.join(' · ');
      }
      return (lat: result.latitude, lng: result.longitude);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return null;
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    } finally {
      isGeocoding.value = false;
    }
  }

  Future<void> saveSite() async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    final name = siteNameCtrl.text.trim();
    if (name.isEmpty) {
      errorMessage.value = 'Site name is required.';
      return;
    }

    if (siteIsPrimary.value && sitePostalCtrl.text.trim().isEmpty) {
      errorMessage.value = 'Postal code is required for the primary site.';
      return;
    }

    final lat = double.tryParse(siteLatCtrl.text.trim());
    final lng = double.tryParse(siteLngCtrl.text.trim());

    // New sites (or edits missing coords) require look-up + confirm.
    if (editingSite == null || lat == null || lng == null) {
      if (!addressConfirmed.value || lat == null || lng == null) {
        errorMessage.value =
            'Look up and confirm the address before saving.';
        return;
      }
    }

    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      errorMessage.value = 'Latitude/longitude out of range.';
      return;
    }
    final radius = editingSite?.geofenceRadiusM ?? 100;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final body = ClientSiteWriteRequest(
        name: name,
        addressLine1: siteAddressCtrl.text.trim().nullIfEmpty,
        city: siteCityCtrl.text.trim().nullIfEmpty,
        state: siteState.value.trim().nullIfEmpty ??
            siteStateCtrl.text.trim().nullIfEmpty,
        country: 'AU',
        postalCode: sitePostalCtrl.text.trim().nullIfEmpty,
        latitude: lat,
        longitude: lng,
        geofenceRadiusM: radius.clamp(10, 5000),
        isPrimary: siteIsPrimary.value,
        accessNotes: siteAccessNotesCtrl.text.trim().nullIfEmpty,
      );
      if (editingSite == null) {
        await _repository.createSite(clientId, body);
      } else {
        await _repository.patchSite(clientId, editingSite!.id, body);
      }
      Get.back();
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteSite(ClientSiteOut site) async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    isSaving.value = true;
    try {
      await _repository.deleteSite(clientId, site.id);
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  static const relationshipOtherKey = ContactFormHost.relationshipOtherKey;

  static const relationshipPresets = ContactFormHost.relationshipPresets;

  @override
  String? get resolvedContactRelationship {
    final preset = contactRelationshipPreset.value;
    if (preset == null || preset.isEmpty) return null;
    if (preset == relationshipOtherKey) {
      return contactRelationshipOtherCtrl.text.trim().nullIfEmpty;
    }
    return preset;
  }

  void beginContactForm({ClientContactOut? contact}) {
    editingContact = contact;
    contactNameCtrl.text = contact?.name ?? '';
    contactEmailCtrl.text = contact?.email ?? '';
    contactPhoneCtrl.text = contact?.phone ?? '';
    contactIsPrimary.value = contact?.isPrimary ?? false;
    contactNotify.value = contact?.notifyVisitComplete ?? false;
    final rel = contact?.relationship?.trim();
    if (rel == null || rel.isEmpty) {
      contactRelationshipPreset.value = null;
      contactRelationshipOtherCtrl.clear();
    } else if (relationshipPresets.containsKey(rel)) {
      contactRelationshipPreset.value = rel;
      contactRelationshipOtherCtrl.clear();
    } else {
      contactRelationshipPreset.value = relationshipOtherKey;
      contactRelationshipOtherCtrl.text = rel;
    }
    errorMessage.value = null;
    Get.toNamed(AppRoutes.staffClientContactForm);
  }

  Future<void> saveContact() async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    final email = contactEmailCtrl.text.trim();
    final phone = contactPhoneCtrl.text.trim();
    final name = contactNameCtrl.text.trim();
    if (email.isEmpty && phone.isEmpty && name.isEmpty) {
      errorMessage.value = 'Provide at least a name, email, or phone.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final body = ClientContactWriteRequest(
        name: name.nullIfEmpty,
        email: email.nullIfEmpty,
        phone: phone.nullIfEmpty,
        relationship: resolvedContactRelationship,
        isPrimary: contactIsPrimary.value,
        notifyVisitComplete: contactNotify.value,
      );
      if (editingContact == null) {
        await _repository.createContact(clientId, body);
      } else {
        await _repository.patchContact(clientId, editingContact!.id, body);
      }
      Get.back();
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteContact(ClientContactOut contact) async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    isSaving.value = true;
    try {
      await _repository.deleteContact(clientId, contact.id);
      await refreshDetailExtras();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> createInvite() async {
    final clientId = selected.value?.id;
    if (clientId == null) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final invite = await _repository.createInvite(clientId);
      lastInvite.value = invite;
      invites.assignAll(await _repository.listInvites(clientId));
      Get.snackbar(
        'Invite created',
        'Copy the link below. Expires ${invite.expiresAt.toLocal()}.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.primary,
        colorText: AppColors.onPrimary,
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  String invitePath(String token) => '/invites/client/$token';

  Future<void> copyInviteLink(String token) async {
    final path = invitePath(token);
    await Clipboard.setData(ClipboardData(text: path));
    Get.snackbar(
      'Copied',
      path,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );
  }

  static List<String> _extensionsFromAccept(List<String> accept) {
    if (accept.isEmpty) {
      return const ['pdf', 'png', 'jpg', 'jpeg', 'webp'];
    }
    final exts = <String>{};
    for (final mime in accept) {
      final m = mime.toLowerCase();
      if (m.contains('pdf')) exts.add('pdf');
      if (m.contains('png')) exts.add('png');
      if (m.contains('jpeg') || m.contains('jpg')) {
        exts.addAll(['jpg', 'jpeg']);
      }
      if (m.contains('webp')) exts.add('webp');
      if (m.contains('image/*')) {
        exts.addAll(['png', 'jpg', 'jpeg', 'webp']);
      }
      if (m.startsWith('.')) exts.add(m.substring(1));
    }
    return exts.isEmpty
        ? const ['pdf', 'png', 'jpg', 'jpeg', 'webp']
        : exts.toList();
  }

  static String _guessContentType(String? ext, String name) {
    final e = (ext ?? name.split('.').last).toLowerCase();
    return switch (e) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' || 'gif' || 'heic' || 'heif' || 'bmp' => 'image/jpeg',
      'webp' => 'image/webp',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      // Never send octet-stream — backend rejects it with 400.
      _ => 'image/jpeg',
    };
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
