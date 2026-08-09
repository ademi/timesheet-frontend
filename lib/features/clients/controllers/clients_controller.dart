import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/models/client_models.dart';
import '../data/models/client_profile_models.dart';
import '../data/repositories/clients_repository.dart';
import 'requirement_draft.dart';

class ClientsController extends GetxController {
  ClientsController({
    required ClientsRepository repository,
    required SessionService session,
    DocumentPipeline? documentPipeline,
  })  : _repository = repository,
        _session = session,
        _pipeline = documentPipeline;

  final ClientsRepository _repository;
  final SessionService _session;
  final DocumentPipeline? _pipeline;

  final items = <ClientOut>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final profileSaveProgress = RxnString();

  // Create / edit form
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final status = 'active'.obs;
  ClientOut? editing;

  // Profile photo (create / edit form)
  final formPhoto = Rxn<ProfilePhotoOut>();
  final formLocalPhotoBytes = Rxn<List<int>>();
  final formPendingPhoto = Rxn<PickedProfilePhoto>();
  final isFormPhotoLoading = false.obs;
  final formPhotoCleared = false.obs;

  // Profile photo (detail page, read-only)
  final detailPhoto = Rxn<ProfilePhotoOut>();
  final isDetailPhotoLoading = false.obs;

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

  // Site form
  final siteNameCtrl = TextEditingController();
  final siteAddressCtrl = TextEditingController();
  final siteCityCtrl = TextEditingController();
  final siteStateCtrl = TextEditingController();
  final siteCountryCtrl = TextEditingController();
  final sitePostalCtrl = TextEditingController();
  /// Held after geocode / edit hydrate; not shown on the site form.
  final siteLatCtrl = TextEditingController();
  final siteLngCtrl = TextEditingController();
  final siteIsPrimary = false.obs;
  final isGeocoding = false.obs;
  final geocodeHint = RxnString();
  ClientSiteOut? editingSite;

  // Contact form
  final contactNameCtrl = TextEditingController();
  final contactEmailCtrl = TextEditingController();
  final contactPhoneCtrl = TextEditingController();
  final contactIsPrimary = false.obs;
  final contactNotify = true.obs;
  ClientContactOut? editingContact;

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
    siteLatCtrl.dispose();
    siteLngCtrl.dispose();
    contactNameCtrl.dispose();
    contactEmailCtrl.dispose();
    contactPhoneCtrl.dispose();
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
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> openCreate() async {
    editing = null;
    nameCtrl.clear();
    emailCtrl.clear();
    phoneCtrl.clear();
    notesCtrl.clear();
    status.value = 'active';
    errorMessage.value = null;
    profileSaveProgress.value = null;
    _resetFormPhoto();
    Get.toNamed(AppRoutes.staffClientForm);
  }

  Future<void> openEdit(ClientOut client) async {
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
        types.where((t) => t.isActive).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
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

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: allowMultiple && remaining > 1,
      type: extensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: extensions.isEmpty ? null : extensions,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = <PickedClientFile>[];
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
      if (draft.localFiles.length + picked.length >= draft.requirement.maxFiles) {
        break;
      }
    }
    if (picked.isEmpty) {
      errorMessage.value = 'Could not read file bytes.';
      return;
    }
    draft.localFiles.addAll(picked);
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
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      errorMessage.value = 'Full name is required.';
      return;
    }

    isSaving.value = true;
    errorMessage.value = null;
    profileSaveProgress.value = null;
    try {
      if (editing == null) {
        final created = await _repository.createClient(
          ClientCreateRequest(
            fullName: name,
            status: status.value,
            email: emailCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            serviceAgreementNotes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          ),
        );
        if (formPendingPhoto.value != null) {
          try {
            await _persistFormPhoto(created.id);
          } on AppFailure catch (e) {
            Get.back();
            await load();
            openDetail(created);
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
        Get.back();
        await load();
        openDetail(created);
      } else {
        await _repository.patchClient(
          editing!.id,
          ClientUpdateRequest(
            fullName: name,
            status: status.value,
            email: emailCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            serviceAgreementNotes: notesCtrl.text.trim(),
          ),
        );
        if (formPendingPhoto.value != null || formPhotoCleared.value) {
          await _persistFormPhoto(editing!.id);
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
          'Client type and profile updated.',
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
      await _repository.acceptClientLegal(
        clientId,
        req.requirementKey,
        ClientLegalAcceptRequest(
          eventType: 'consented',
          legalDocumentVersionId: doc.id,
          participantOrRepName: name,
          relationship: draft.relationshipCtrl.text.trim().nullIfEmpty,
          method: draft.method.value,
          note: draft.noteCtrl.text.trim().nullIfEmpty,
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

  Future<void> openDetail(ClientOut client) async {
    selected.value = client;
    lastInvite.value = null;
    invites.clear();
    tabIndex.value = 0;
    selectedClientTypeId.value = client.clientTypeId;
    detailPhoto.value = null;
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

  /// Loads types list + requirements/profile for the Types tab.
  Future<void> loadTypeTabForSelected() async {
    final client = selected.value;
    if (client == null) return;
    await loadClientTypes();
    selectedClientTypeId.value = client.clientTypeId;
    _disposeRequirementDrafts();
    requirementDrafts.clear();
    final typeId = client.clientTypeId;
    if (typeId != null && typeId.isNotEmpty) {
      await _loadRequirementsForType(typeId);
      await _prefillFromProfile(client.id);
    }
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
    try {
      invites.assignAll(await _repository.listInvites(id));
    } on AppFailure catch (e) {
      invites.clear();
      errorMessage.value ??= e.message;
    }
  }

  void beginSiteForm({ClientSiteOut? site}) {
    editingSite = site;
    siteNameCtrl.text = site?.name ?? '';
    siteAddressCtrl.text = site?.addressLine1 ?? '';
    siteCityCtrl.text = site?.city ?? '';
    siteStateCtrl.text = site?.state ?? '';
    siteCountryCtrl.text = site?.country ?? '';
    sitePostalCtrl.text = site?.postalCode ?? '';
    siteLatCtrl.text = site?.latitude?.toString() ?? '';
    siteLngCtrl.text = site?.longitude?.toString() ?? '';
    siteIsPrimary.value = site?.isPrimary ?? false;
    errorMessage.value = null;
    geocodeHint.value = null;
    Get.toNamed(AppRoutes.staffClientSiteForm);
  }

  /// Resolves lat/lng from address via `POST /v1/public/geocode`.
  Future<({double lat, double lng})?> geocodeFromAddress({
    bool showSuccessHint = true,
  }) async {
    final address = siteAddressCtrl.text.trim();
    final city = siteCityCtrl.text.trim();
    final state = siteStateCtrl.text.trim();
    final country = siteCountryCtrl.text.trim().toUpperCase();

    if (address.isEmpty || city.isEmpty || country.isEmpty) {
      errorMessage.value =
          'Address line 1, city, and country (ISO code, e.g. AU) are '
          'required to look up coordinates.';
      return null;
    }
    if (country.length != 2) {
      errorMessage.value =
          'Country must be a 2-letter ISO code (e.g. AU, US, GB).';
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
      siteLatCtrl.text = result.latitude.toString();
      siteLngCtrl.text = result.longitude.toString();
      siteCountryCtrl.text = country;
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

    var lat = double.tryParse(siteLatCtrl.text.trim());
    var lng = double.tryParse(siteLngCtrl.text.trim());

    if (lat == null || lng == null) {
      final coords = await geocodeFromAddress(showSuccessHint: true);
      if (coords == null) return;
      lat = coords.lat;
      lng = coords.lng;
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
        state: siteStateCtrl.text.trim().nullIfEmpty,
        country: siteCountryCtrl.text.trim().nullIfEmpty,
        postalCode: sitePostalCtrl.text.trim().nullIfEmpty,
        latitude: lat,
        longitude: lng,
        geofenceRadiusM: radius.clamp(10, 5000),
        isPrimary: siteIsPrimary.value,
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

  void beginContactForm({ClientContactOut? contact}) {
    editingContact = contact;
    contactNameCtrl.text = contact?.name ?? '';
    contactEmailCtrl.text = contact?.email ?? '';
    contactPhoneCtrl.text = contact?.phone ?? '';
    contactIsPrimary.value = contact?.isPrimary ?? false;
    contactNotify.value = contact?.notifyVisitComplete ?? true;
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
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }
}

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
