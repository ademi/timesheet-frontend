import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../contractor_onboarding/data/models/compliance_models.dart'
    as compliance;
import '../../contractor_onboarding/data/repositories/compliance_repository.dart';
import '../../documents/data/evidence_document_opener.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/evidence_documents.dart';
import '../data/models/credential_models.dart';
import '../data/repositories/credentials_repository.dart';

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

  /// credential_type → presented legal-event id
  final presentedEventIds = <String, String>{}.obs;

  CredentialOut? selected;

  bool get canManage =>
      _session.hasPermission(AppPermissions.credentialsManage);

  bool get canRead => _session.hasPermission(AppPermissions.credentialsRead);

  String? get contractorId =>
      _session.contractorId.value ?? _session.claims?.contractorId;

  bool get hasSelectedEvidence => selectedEvidence.isNotEmpty;

  List<DocumentOut> evidenceFor(CredentialOut credential) {
    return evidenceByCredentialId[credential.id] ?? const [];
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    issuerCtrl.dispose();
    identifierCtrl.dispose();
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
    if (!canManage) {
      errorMessage.value = 'Missing credentials.manage permission.';
      return null;
    }
    final type = selectedType.value;
    if (!credentialTypesAllowlist.contains(type)) {
      errorMessage.value = 'Invalid credential type.';
      return null;
    }
    if (isGovernmentIdCredentialType(type) && !governmentIdAcknowledged.value) {
      errorMessage.value =
          'Acknowledge government-ID handling before continuing.';
      return null;
    }
    if (!hasSelectedEvidence) {
      errorMessage.value = 'Evidence is required to save.';
      _toast(errorMessage.value!);
      return null;
    }

    isSaving.value = true;
    errorMessage.value = null;
    try {
      await ensureSensitiveConsent(type);
      final noticeEventId = await ensurePresentedEvent(type);
      final created = await _repository.create(
        CredentialCreateRequest(
          credentialType: type,
          noticeEventId: noticeEventId,
          evidenceDocumentIds: selectedEvidence.map((doc) => doc.id).toList(),
          jurisdiction: 'AU',
          issuer:
              issuerCtrl.text.trim().isEmpty ? null : issuerCtrl.text.trim(),
          identifier:
              identifierCtrl.text.trim().isEmpty
                  ? null
                  : identifierCtrl.text.trim(),
        ),
      );
      await load();
      selectedEvidence.clear();
      return created;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (e.code == 'evidence_required') _toast(e.message);
      return null;
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> uploadEvidenceForCreate() async {
    final ownerId = contractorId;
    if (ownerId == null || ownerId.isEmpty) {
      errorMessage.value = 'Contractor id missing from session.';
      return;
    }
    if (!_session.hasPermission(AppPermissions.documentsUpload)) {
      errorMessage.value = 'Missing documents.upload permission.';
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

    isSaving.value = true;
    errorMessage.value = null;
    lastScanStatus.value = 'pending';
    try {
      final doc = await _pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'contractor',
          ownerId: ownerId,
          filename: file.name,
          contentType: _guessContentType(file.extension, file.name),
          sizeBytes: bytes.length,
          category: selectedType.value,
        ),
        bytes: bytes,
        onSendProgress: (sent, total) {
          if (total > 0) uploadProgress.value = sent / total;
        },
      );
      final polled = await _pipeline.pollScanStatus(
        documentId: doc.id,
        ownerType: 'contractor',
        ownerId: ownerId,
      );
      lastScanStatus.value = polled.scanStatus;
      if (polled.isScanBlocked) {
        errorMessage.value =
            'File failed security scan. Re-upload a clean file.';
        return;
      }
      if (!polled.isScanClean) {
        errorMessage.value =
            'Security scan still pending. Wait for scan to finish, then retry.';
        _toast(errorMessage.value!);
        return;
      }
      selectedEvidence.add(polled);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      uploadProgress.value = null;
      isSaving.value = false;
    }
  }

  Future<void> attachEvidence(CredentialOut credential) async {
    final ownerId = contractorId;
    if (ownerId == null || ownerId.isEmpty) {
      errorMessage.value = 'Contractor id missing from session.';
      return;
    }
    if (!_session.hasPermission(AppPermissions.documentsUpload)) {
      errorMessage.value = 'Missing documents.upload permission.';
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
    isSaving.value = true;
    errorMessage.value = null;
    lastScanStatus.value = 'pending';
    try {
      final doc = await _pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'contractor',
          ownerId: ownerId,
          filename: file.name,
          contentType: contentType,
          sizeBytes: bytes.length,
          category: credential.credentialType,
        ),
        bytes: bytes,
        credentialId: credential.id,
        onSendProgress: (sent, total) {
          if (total > 0) uploadProgress.value = sent / total;
        },
      );
      lastScanStatus.value = doc.scanStatus;
      final polled = await _pipeline.pollScanStatus(
        documentId: doc.id,
        ownerType: 'contractor',
        ownerId: ownerId,
      );
      lastScanStatus.value = polled.scanStatus;
      if (polled.isScanBlocked) {
        errorMessage.value =
            'File failed security scan. Re-upload a clean file.';
      }
      await load();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      uploadProgress.value = null;
      isSaving.value = false;
    }
  }

  Future<void> supersede(CredentialOut old) async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final noticeEventId = await ensurePresentedEvent(old.credentialType);
      await _repository.supersede(
        old.id,
        CredentialSupersedeRequest(noticeEventId: noticeEventId),
      );
      await load();
      Get.snackbar(
        'Superseded',
        'A new credential row replaced the previous one.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
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
    try {
      await _evidenceDocumentOpener.open(document, download: download);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value =
          'Could not download this file. Check your connection and retry.';
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
    Get.snackbar(
      'Credentials',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.error,
      colorText: AppColors.textLight,
    );
  }

  void showErrorToast() {
    final m = errorMessage.value;
    if (m != null) _toast(m);
  }
}
