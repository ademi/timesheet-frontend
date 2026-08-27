import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/data/models/document/document_models.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../documents/data/document_pipeline.dart';
import '../../subscription/billing_gate.dart';
import '../data/models/compliance_ops_models.dart';
import '../data/repositories/compliance_ops_repository.dart';

class ContractorProfileController extends GetxController {
  ContractorProfileController({
    required ComplianceOpsRepository repository,
    required SessionService session,
    DocumentPipeline? documentPipeline,
  })  : _repository = repository,
        _session = session,
        _pipeline = documentPipeline;

  final ComplianceOpsRepository _repository;
  final SessionService _session;
  final DocumentPipeline? _pipeline;

  final isSaving = false.obs;
  final isLoading = false.obs;
  final isPhotoLoading = false.obs;
  final errorMessage = RxnString();
  final lastRights = Rxn<RightsRequestOut>();
  final lastExport = Rxn<PrivacyExportResult>();
  final events = <NotificationEventOut>[].obs;

  final photo = Rxn<ProfilePhotoOut>();
  final localPhotoBytes = Rxn<List<int>>();

  final rightsNotesCtrl = TextEditingController();
  final rightsType = 'access'.obs;
  final withdrawTypeCtrl = TextEditingController(text: 'police_check');

  bool get canConsent =>
      _session.hasPermission(AppPermissions.complianceConsentManage);

  bool get canUploadPhoto =>
      _session.hasPermission(AppPermissions.documentsUpload) &&
      _pipeline != null &&
      (_session.contractorId.value?.isNotEmpty ?? false);

  @override
  void onInit() {
    super.onInit();
    _loadEvents();
    loadProfilePhoto();
  }

  @override
  void onClose() {
    rightsNotesCtrl.dispose();
    withdrawTypeCtrl.dispose();
    super.onClose();
  }

  Future<void> _loadEvents() async {
    isLoading.value = true;
    try {
      events.assignAll(await _repository.listNotificationEvents());
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProfilePhoto() async {
    isPhotoLoading.value = true;
    try {
      final result = await _repository.getContractorProfilePhoto();
      photo.value = result;
      if (result.hasDisplayableUrl) {
        localPhotoBytes.value = null;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      // Non-blocking for privacy ops screen.
    } finally {
      isPhotoLoading.value = false;
    }
  }

  Future<void> onPhotoPicked(PickedProfilePhoto picked) async {
    final contractorId = _session.contractorId.value;
    final pipeline = _pipeline;
    if (contractorId == null || contractorId.isEmpty || pipeline == null) {
      errorMessage.value = 'Cannot upload photo: missing contractor session.';
      return;
    }
    if (!canUploadPhoto) {
      errorMessage.value = 'Missing documents.upload permission.';
      return;
    }

    isPhotoLoading.value = true;
    errorMessage.value = null;
    localPhotoBytes.value = picked.bytes;
    try {
      final doc = await pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'contractor',
          ownerId: contractorId,
          filename: picked.name,
          contentType: picked.contentType,
          sizeBytes: picked.bytes.length,
          category: 'contractor_photo',
        ),
        bytes: picked.bytes,
      );
      final result = await _repository.setContractorProfilePhoto(doc.id);
      photo.value = result;
      AppToast.success('Profile photo updated', 'Your photo was saved.');
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
      localPhotoBytes.value = null;
    } catch (e) {
      errorMessage.value = e.toString();
      localPhotoBytes.value = null;
    } finally {
      isPhotoLoading.value = false;
    }
  }

  Future<void> removeProfilePhoto() async {
    isPhotoLoading.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.clearContractorProfilePhoto();
      photo.value = result;
      localPhotoBytes.value = null;
      AppToast.info('Profile photo removed', 'Your photo was cleared.');
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isPhotoLoading.value = false;
    }
  }

  Future<void> submitRightsRequest() async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final created = await _repository.createRightsRequest(
        RightsRequestCreate(
          requestType: rightsType.value,
          notes: rightsNotesCtrl.text,
        ),
      );
      lastRights.value = created;
      rightsNotesCtrl.clear();
      AppToast.success(
        'Request submitted',
        '${created.requestType} · ${created.status}',
      );
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> runPrivacyExport() async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final result = await _repository.privacyExport();
      lastExport.value = result;
      AppToast.info(
        'Privacy export',
        result.message ?? result.downloadUrl ?? 'Export requested',
      );
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> confirmWithdrawConsent() async {
    if (!canConsent) {
      errorMessage.value = 'Missing compliance.consent.manage.';
      return;
    }
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Withdraw consent?'),
        content: const Text(
          'Withdrawing sensitive-data consent may block future platform-mediated '
          'access to that credential class. Your provider may still retain lawful '
          'copies outside this app. This does not delete historical records by itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _repository.withdrawConsent(
        credentialType: withdrawTypeCtrl.text.trim(),
      );
      AppToast.info(
        'Consent withdrawn',
        'Recorded for ${withdrawTypeCtrl.text.trim()}.',
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }
}
