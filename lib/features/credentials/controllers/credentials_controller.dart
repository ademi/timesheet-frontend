import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../app/routes/app_navigator.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/name_sort.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../contractor_onboarding/data/models/compliance_models.dart'
    as compliance;
import '../../contractor_onboarding/data/repositories/compliance_repository.dart';
import '../../documents/data/evidence_document_opener.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/evidence_documents.dart';
import '../data/models/credential_models.dart';
import '../data/repositories/credentials_repository.dart';
import 'credential_create_draft.dart';

/// Contractor credentials list / create / evidence upload (S3).
class CredentialsController extends GetxController {
  CredentialsController({
    required CredentialsRepository repository,
    required DocumentPipeline documentPipeline,
    required ComplianceRepository complianceRepository,
    required SessionService session,
    EvidenceDocumentOpener? evidenceDocumentOpener,
  }) : _repository = repository,
       _pipeline = documentPipeline,
       _compliance = complianceRepository,
       _session = session,
       _evidenceDocumentOpener =
           evidenceDocumentOpener ??
           EvidenceDocumentOpener(documentPipeline: documentPipeline);

  final CredentialsRepository _repository;
  final DocumentPipeline _pipeline;
  final ComplianceRepository _compliance;
  final SessionService _session;
  final EvidenceDocumentOpener _evidenceDocumentOpener;

  final items = <CredentialOut>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  /// True while an evidence file is transferring (not during scan poll).
  final isUploadingEvidence = false.obs;
  final errorMessage = RxnString();
  final lastScanStatus = RxnString();
  final lastOpenedViaProxy = false.obs;
  final uploadProgress = RxnDouble();
  final selectedEvidence = <DocumentOut>[].obs;
  final evidenceByCredentialId = <String, List<DocumentOut>>{}.obs;

  // Create form
  final selectedType = 'wwcc'.obs;
  final issuerCtrl = TextEditingController();
  final identifierCtrl = TextEditingController();
  final sensitiveConsentConfirmed = false.obs;
  final governmentIdAcknowledged = false.obs;

  /// Missing-credentials multi-section create (one draft per category).
  final missingCreateTypes = <String>[].obs;
  final missingDrafts = <String, CredentialCreateDraft>{}.obs;

  /// Survives controller re-enter / Get.parameters wipe during GoRouter push.
  static List<String>? pendingMissingCreateTypes;

  /// credential_type → presented legal-event id
  final presentedEventIds = <String, String>{}.obs;

  CredentialOut? get selected => selectedRx.value;
  set selected(CredentialOut? value) => selectedRx.value = value;
  final selectedRx = Rxn<CredentialOut>();

  /// Bumped after credential catalog fetch so create UI can show help links.
  final catalogRevision = 0.obs;

  bool get canManage =>
      _session.hasPermission(AppPermissions.credentialsManage);

  bool get canRead => _session.hasPermission(AppPermissions.credentialsRead);

  /// Alphabetically sorted types with wire code `other` forced last.
  List<String> get credentialTypeChoices {
    final rest = credentialTypesAllowlist.where((t) => t != 'other');
    final sorted = sortedByName(rest, credentialTypeLabel);
    if (credentialTypesAllowlist.contains('other')) {
      return [...sorted, 'other'];
    }
    return sorted;
  }

  String? get contractorId =>
      _session.contractorId.value ?? _session.claims?.contractorId;

  bool get hasSelectedEvidence => selectedEvidence.isNotEmpty;

  /// Create requires every attached evidence file to finish a clean scan.
  bool get hasCleanEvidenceReady =>
      selectedEvidence.isNotEmpty &&
      selectedEvidence.every((doc) => doc.isScanClean);

  bool get hasPendingEvidenceScan =>
      selectedEvidence.any((doc) => doc.isScanPending);

  List<DocumentOut> evidenceFor(CredentialOut credential) {
    return evidenceByCredentialId[credential.id] ?? const [];
  }

  @override
  void onInit() {
    super.onInit();
    if (_routeImpliesDetail()) {
      isLoading.value = true;
    }
    Future.microtask(() async {
      await load();
      await ensureDetailHydratedFromRoute();
      ensureMissingCreateFromRoute();
    });
    _loadCredentialCategories();
  }

  /// Tier-2 shell re-enter: soft list refresh; clear abandoned *single* create
  /// form only on the credentials list tab (create/detail share this controller).
  ///
  /// Missing-create drafts are intentionally not cleared here — GoRouter can
  /// rebuild the shell credentials tab while pushing create-missing, and wiping
  /// drafts in that window left the create-missing screen empty.
  void onScreenReenter() {
    errorMessage.value = null;
    final path = locationPath(AppNavigator.currentLocation);
    final onMissingCreate =
        path == AppRoutes.contractorCredentialCreateMissing;
    final onList = path == AppRoutes.contractorCredentials;

    if (onList) {
      issuerCtrl.clear();
      identifierCtrl.clear();
      sensitiveConsentConfirmed.value = false;
      governmentIdAcknowledged.value = false;
      selectedEvidence.clear();
      uploadProgress.value = null;
      lastScanStatus.value = null;
    }
    // ignore: discarded_futures
    load();
    // ignore: discarded_futures
    ensureDetailHydratedFromRoute();
    if (onMissingCreate ||
        (pendingMissingCreateTypes != null &&
            pendingMissingCreateTypes!.isNotEmpty)) {
      ensureMissingCreateFromRoute();
    }
  }

  /// Starts (or replaces) the multi-section missing-credentials create flow.
  void beginMissingCreate(List<String> categories) {
    final unique = <String>[];
    for (final code in categories) {
      final trimmed = code.trim();
      if (trimmed.isEmpty || unique.contains(trimmed)) continue;
      unique.add(trimmed);
    }
    pendingMissingCreateTypes = List<String>.from(unique);
    _disposeMissingDrafts();
    missingCreateTypes.assignAll(unique);
    for (final code in unique) {
      missingDrafts[code] = CredentialCreateDraft(code);
    }
    missingDrafts.refresh();
  }

  void clearMissingCreate() {
    _disposeMissingDrafts();
    missingCreateTypes.clear();
    pendingMissingCreateTypes = null;
  }

  void _disposeMissingDrafts() {
    for (final draft in missingDrafts.values) {
      draft.dispose();
    }
    missingDrafts.clear();
  }

  /// Hydrate missing-create sections from pending / route args / `?types=a,b`.
  void ensureMissingCreateFromRoute() {
    if (missingCreateTypes.isNotEmpty) return;

    List<String>? types;
    final pending = pendingMissingCreateTypes;
    if (pending != null && pending.isNotEmpty) {
      types = List<String>.from(pending);
    }

    if (types == null || types.isEmpty) {
      final args = AppNavigator.arguments ?? Get.arguments;
      if (args is List) {
        types = [
          for (final item in args)
            if (item != null && item.toString().trim().isNotEmpty)
              item.toString().trim(),
        ];
      }
    }

    if (types == null || types.isEmpty) {
      final location = AppNavigator.currentLocation;
      final uri = Uri.tryParse(
        location.startsWith('/') ? location : '/$location',
      );
      final fromQuery =
          uri?.queryParameters['types'] ??
          AppNavigator.queryParameters['types'] ??
          Get.parameters['types'];
      if (fromQuery != null && fromQuery.isNotEmpty) {
        types = [
          for (final part in fromQuery.split(','))
            if (part.trim().isNotEmpty) part.trim(),
        ];
      }
    }

    if (types == null || types.isEmpty) return;
    beginMissingCreate(types);
  }

  bool _routeImpliesDetail() {
    if (selected != null) return false;
    if (Get.arguments is CredentialOut) return true;
    final id = Get.parameters['id'];
    return id != null && id.isNotEmpty;
  }

  /// Hydrate credential detail after browser refresh / deep link.
  Future<void> ensureDetailHydratedFromRoute() async {
    if (selected != null) return;

    CredentialOut? found;
    final fromArgs = Get.arguments;
    if (fromArgs is CredentialOut) {
      found = fromArgs;
    } else {
      final id = Get.parameters['id'];
      if (id != null && id.isNotEmpty) {
        if (items.isEmpty) await load();
        for (final c in items) {
          if (c.id == id) {
            found = c;
            break;
          }
        }
      }
    }
    if (found == null) return;
    selected = found;
  }

  void openDetail(CredentialOut credential) {
    selected = credential;
    AppNavigator.push(
      AppNavigator.location(
        AppRoutes.contractorCredentialDetail,
        query: {'id': credential.id},
      ),
      extra: credential,
    );
  }

  Future<void> _loadCredentialCategories() async {
    try {
      await _repository.listCredentialCategories();
      catalogRevision.value++;
    } catch (_) {
      // Fallback labels remain available via credentialTypeLabel.
    }
  }

  @override
  void onClose() {
    issuerCtrl.dispose();
    identifierCtrl.dispose();
    clearMissingCreate();
    super.onClose();
  }

  Future<void> load() async {
    if (!canRead) {
      errorMessage.value = 'Missing credentials.read permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repository.listMine();
      items.assignAll(list);
      final id = contractorId;
      if (id != null && id.isNotEmpty) {
        final documents = await _pipeline.listEvidenceForContractor(id);
        evidenceByCredentialId.value = {
          for (final credential in list)
            credential.id: documentsForCredential(
              documents: documents,
              credentialId: credential.id,
              credentialType: credential.credentialType,
            ),
        };
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<String> ensurePresentedEvent(String credentialType) async {
    final existing = presentedEventIds[credentialType];
    if (existing != null && existing.isNotEmpty) return existing;

    final notices = await _compliance.listCollectionNotices(
      credentialType: credentialType,
      jurisdiction: 'AU',
    );
    if (notices.isEmpty) {
      throw const AppFailure(
        code: 'notice_not_presented',
        message: 'No collection notice available for this credential type yet.',
        presentation: AppFailurePresentation.inline,
      );
    }
    final notice = notices.first;
    final event = await _compliance.createLegalEvent(
      compliance.LegalEventCreate(
        eventType: 'presented',
        noticeKey: notice.noticeKey,
        noticeVersion: notice.version,
        credentialType: credentialType,
        presentationSource: 'contractor_credentials',
      ),
    );
    presentedEventIds[credentialType] = event.id;
    return event.id;
  }

  Future<void> ensureSensitiveConsent(String credentialType) async {
    if (!isSensitiveCredentialType(credentialType)) return;
    if (!sensitiveConsentConfirmed.value) {
      throw const AppFailure(
        code: 'consent_required',
        message: 'Confirm sensitive-credential consent before creating.',
        presentation: AppFailurePresentation.inline,
      );
    }
    final notices = await _compliance.listCollectionNotices(
      credentialType: credentialType,
      jurisdiction: 'AU',
    );
    final notice = notices.isEmpty ? null : notices.first;
    await _compliance.createLegalEvent(
      compliance.LegalEventCreate(
        eventType: 'consented',
        noticeKey: notice?.noticeKey,
        noticeVersion: notice?.version,
        credentialType: credentialType,
        dataClass: 'sensitive_credential',
        presentationSource: 'contractor_credentials',
      ),
    );
  }

  Future<CredentialOut?> createCredential() async {
    return _createCredential(
      type: selectedType.value,
      issuer: issuerCtrl.text,
      identifier: identifierCtrl.text,
      sensitiveConsentConfirmed: sensitiveConsentConfirmed.value,
      governmentIdAcknowledged: governmentIdAcknowledged.value,
      evidence: selectedEvidence.toList(),
      setSaving: (v) => isSaving.value = v,
      setError: (v) => errorMessage.value = v,
      onSuccessClearEvidence: () => selectedEvidence.clear(),
    );
  }

  /// Creates one missing credential from its section draft.
  ///
  /// Returns `null` on failure (inline error already set), `false` when this
  /// was the last section, or `true` when more sections remain.
  Future<bool?> createMissingCredential(String type) async {
    final draft = missingDrafts[type];
    if (draft == null) return null;

    final created = await _createCredential(
      type: draft.credentialType,
      issuer: draft.issuerCtrl.text,
      identifier: draft.identifierCtrl.text,
      sensitiveConsentConfirmed: draft.sensitiveConsentConfirmed.value,
      governmentIdAcknowledged: draft.governmentIdAcknowledged.value,
      evidence: draft.selectedEvidence.toList(),
      setSaving: (v) => draft.isSaving.value = v,
      setError: (v) => draft.errorMessage.value = v,
      onSuccessClearEvidence: () => draft.selectedEvidence.clear(),
    );
    if (created == null) return null;

    draft.dispose();
    missingDrafts.remove(type);
    missingCreateTypes.remove(type);
    missingDrafts.refresh();
    if (missingCreateTypes.isEmpty) {
      pendingMissingCreateTypes = null;
      return false;
    }
    pendingMissingCreateTypes = missingCreateTypes.toList();
    return true;
  }

  Future<CredentialOut?> _createCredential({
    required String type,
    required String issuer,
    required String identifier,
    required bool sensitiveConsentConfirmed,
    required bool governmentIdAcknowledged,
    required List<DocumentOut> evidence,
    required void Function(bool) setSaving,
    required void Function(String?) setError,
    required VoidCallback onSuccessClearEvidence,
  }) async {
    if (!canManage) {
      setError('Missing credentials.manage permission.');
      return null;
    }
    if (!credentialTypesAllowlist.contains(type)) {
      setError('Invalid credential type.');
      return null;
    }
    if (isGovernmentIdCredentialType(type) && !governmentIdAcknowledged) {
      setError('Acknowledge government-ID handling before continuing.');
      return null;
    }
    if (evidence.isEmpty) {
      setError('Evidence is required to save.');
      _toast('Evidence is required to save.');
      return null;
    }
    final pendingScan = evidence.any((doc) => doc.isScanPending);
    final cleanReady = evidence.every((doc) => doc.isScanClean);
    if (!cleanReady) {
      final message =
          pendingScan
              ? 'Wait for security scan to finish on all evidence files.'
              : 'Evidence must pass security scan before saving.';
      setError(message);
      _toast(message);
      return null;
    }

    setSaving(true);
    setError(null);
    try {
      // Temporarily mirror consent onto the shared flag used by
      // [ensureSensitiveConsent] for the single-create path.
      final previousConsent = this.sensitiveConsentConfirmed.value;
      this.sensitiveConsentConfirmed.value = sensitiveConsentConfirmed;
      try {
        await ensureSensitiveConsent(type);
      } finally {
        this.sensitiveConsentConfirmed.value = previousConsent;
      }
      final noticeEventId = await ensurePresentedEvent(type);
      final created = await _repository.create(
        CredentialCreateRequest(
          credentialType: type,
          noticeEventId: noticeEventId,
          evidenceDocumentIds: evidence.map((doc) => doc.id).toList(),
          jurisdiction: 'AU',
          issuer: issuer.trim().isEmpty ? null : issuer.trim(),
          identifier: identifier.trim().isEmpty ? null : identifier.trim(),
        ),
      );
      await load();
      onSuccessClearEvidence();
      return created;
    } on AppFailure catch (e) {
      setError(e.message);
      if (e.code == 'evidence_required') _toast(e.message);
      return null;
    } catch (e) {
      setError(e.toString());
      return null;
    } finally {
      setSaving(false);
    }
  }

  Future<void> uploadEvidenceForCreate() async {
    await _uploadEvidenceForCreate(
      category: selectedType.value,
      evidence: selectedEvidence,
      setUploading: (v) => isUploadingEvidence.value = v,
      setProgress: (v) => uploadProgress.value = v,
      setError: (v) => errorMessage.value = v,
      setLastScanStatus: (v) => lastScanStatus.value = v,
    );
  }

  Future<void> uploadEvidenceForMissing(String type) async {
    final draft = missingDrafts[type];
    if (draft == null) return;
    await _uploadEvidenceForCreate(
      category: draft.credentialType,
      evidence: draft.selectedEvidence,
      setUploading: (v) => draft.isUploadingEvidence.value = v,
      setProgress: (v) => draft.uploadProgress.value = v,
      setError: (v) => draft.errorMessage.value = v,
      setLastScanStatus: (v) => draft.lastScanStatus.value = v,
    );
  }

  Future<void> _uploadEvidenceForCreate({
    required String category,
    required RxList<DocumentOut> evidence,
    required void Function(bool) setUploading,
    required void Function(double?) setProgress,
    required void Function(String?) setError,
    required void Function(String?) setLastScanStatus,
  }) async {
    final ownerId = contractorId;
    if (ownerId == null || ownerId.isEmpty) {
      setError('Contractor id missing from session.');
      return;
    }
    if (!_session.hasPermission(AppPermissions.documentsUpload)) {
      setError('Missing documents.upload permission.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setError('Could not read file bytes.');
      return;
    }

    setUploading(true);
    setError(null);
    setLastScanStatus('pending');
    try {
      final doc = await _pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'contractor',
          ownerId: ownerId,
          filename: file.name,
          contentType: _guessContentType(file.extension, file.name),
          sizeBytes: bytes.length,
          category: category,
        ),
        bytes: bytes,
        onSendProgress: (sent, total) {
          if (total > 0) setProgress(sent / total);
        },
      );
      evidence.add(doc);
      setLastScanStatus(doc.scanStatus);
      // Unlock the form; scan continues in the background (B2).
      unawaited(
        _pollCreateEvidenceScan(
          doc: doc,
          ownerId: ownerId,
          evidence: evidence,
          setError: setError,
          setLastScanStatus: setLastScanStatus,
        ),
      );
    } on AppFailure catch (e) {
      setError(e.message);
    } catch (e) {
      setError(e.toString());
    } finally {
      setProgress(null);
      setUploading(false);
    }
  }

  Future<void> _pollCreateEvidenceScan({
    required DocumentOut doc,
    required String ownerId,
    required RxList<DocumentOut> evidence,
    required void Function(String?) setError,
    required void Function(String?) setLastScanStatus,
  }) async {
    try {
      final polled = await _pipeline.pollScanStatus(
        documentId: doc.id,
        ownerType: 'contractor',
        ownerId: ownerId,
      );
      setLastScanStatus(polled.scanStatus);
      final index = evidence.indexWhere((e) => e.id == doc.id);
      if (index < 0) return;
      if (polled.isScanBlocked) {
        evidence.removeAt(index);
        setError('File failed security scan. Re-upload a clean file.');
        _toast('File failed security scan. Re-upload a clean file.');
        return;
      }
      evidence[index] = polled;
      evidence.refresh();
      if (!polled.isScanClean) {
        setError(
          'Security scan still pending. Wait for scan to finish, then retry.',
        );
        _toast(
          'Security scan still pending. Wait for scan to finish, then retry.',
        );
      }
    } on AppFailure catch (e) {
      setError(e.message);
    } catch (e) {
      setError(e.toString());
    }
  }

  /// Whether updating evidence must start a new admin review cycle.
  bool requiresNewReviewCycle(CredentialOut credential) {
    final provenance = credential.provenanceState;
    if (provenance == 'reviewer_sighted' || provenance == 'verified') {
      return true;
    }
    final decision = credential.reviewDecision;
    if (decision == 'accepted' ||
        decision == 'rejected' ||
        decision == 're_review_required') {
      return true;
    }
    // Legacy FE shapes (status was never a review decision on BE).
    final status = credential.status;
    return status == 'accepted' || status == 'rejected';
  }

  /// Contractor "Update" from detail: upload new evidence, and supersede when
  /// the credential was already reviewed so staff can Accept/Reject again.
  Future<void> updateEvidence(CredentialOut credential) async {
    final ownerId = contractorId;
    if (ownerId == null || ownerId.isEmpty) {
      errorMessage.value = 'Contractor id missing from session.';
      return;
    }
    if (!_session.hasPermission(AppPermissions.documentsUpload)) {
      errorMessage.value = 'Missing documents.upload permission.';
      return;
    }
    if (!canManage) {
      errorMessage.value = 'Missing credentials.manage permission.';
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      errorMessage.value = 'Could not read file bytes.';
      return;
    }

    final contentType = _guessContentType(file.extension, file.name);
    isUploadingEvidence.value = true;
    isSaving.value = true;
    errorMessage.value = null;
    lastScanStatus.value = 'pending';
    try {
      var target = credential;
      final needsNewReview = requiresNewReviewCycle(credential);
      if (needsNewReview) {
        final noticeEventId = await ensurePresentedEvent(
          credential.credentialType,
        );
        target = await _repository.supersede(
          credential.id,
          CredentialSupersedeRequest(noticeEventId: noticeEventId),
        );
        selected = target;
      }

      final doc = await _pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'contractor',
          ownerId: ownerId,
          filename: file.name,
          contentType: contentType,
          sizeBytes: bytes.length,
          category: target.credentialType,
        ),
        bytes: bytes,
        credentialId: target.id,
        onSendProgress: (sent, total) {
          if (total > 0) uploadProgress.value = sent / total;
        },
      );
      lastScanStatus.value = doc.scanStatus;
      unawaited(
        _pollAttachedEvidenceScan(
          documentId: doc.id,
          ownerId: ownerId,
          selectCredentialId: target.id,
        ),
      );
      AppToast.info(
        'Updated',
        needsNewReview
            ? 'New evidence submitted. Waiting for admin review.'
            : 'Evidence uploaded. Waiting for security scan.',
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      uploadProgress.value = null;
      isUploadingEvidence.value = false;
      isSaving.value = false;
    }
  }

  Future<void> attachEvidence(CredentialOut credential) =>
      updateEvidence(credential);

  Future<void> _pollAttachedEvidenceScan({
    required String documentId,
    required String ownerId,
    String? selectCredentialId,
  }) async {
    try {
      final polled = await _pipeline.pollScanStatus(
        documentId: documentId,
        ownerType: 'contractor',
        ownerId: ownerId,
      );
      lastScanStatus.value = polled.scanStatus;
      if (polled.isScanBlocked) {
        errorMessage.value =
            'File failed security scan. Re-upload a clean file.';
        _toast(errorMessage.value!);
      }
      await load();
      if (selectCredentialId != null && selectCredentialId.isNotEmpty) {
        for (final item in items) {
          if (item.id == selectCredentialId) {
            selected = item;
            break;
          }
        }
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    }
  }

  Future<CredentialOut?> supersede(CredentialOut old) async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final noticeEventId = await ensurePresentedEvent(old.credentialType);
      final created = await _repository.supersede(
        old.id,
        CredentialSupersedeRequest(noticeEventId: noticeEventId),
      );
      await load();
      selected = created;
      AppToast.info(
        'Superseded',
        'A new credential row replaced the previous one.',
      );
      return created;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openEvidenceDocument(
    DocumentOut document, {
    bool download = false,
  }) async {
    errorMessage.value = null;
    lastOpenedViaProxy.value = false;
    isSaving.value = true;
    try {
      await _evidenceDocumentOpener.open(document, download: download);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value =
          'Could not download this file. Check your connection and retry.';
    } finally {
      isSaving.value = false;
    }
  }

  String _guessContentType(String? ext, String name) {
    final e = (ext ?? name.split('.').last).toLowerCase();
    return switch (e) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  void _toast(String message) {
    AppToast.error('Credentials', message);
  }

  void showErrorToast() {
    final m = errorMessage.value;
    if (m != null) _toast(m);
  }
}
