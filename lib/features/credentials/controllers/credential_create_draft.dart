import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/models/document/document_models.dart';

/// Per-type create form state for the missing-credentials multi-section flow.
class CredentialCreateDraft {
  CredentialCreateDraft(this.credentialType);

  final String credentialType;
  final issuerCtrl = TextEditingController();
  final identifierCtrl = TextEditingController();
  final sensitiveConsentConfirmed = false.obs;
  final governmentIdAcknowledged = false.obs;
  final selectedEvidence = <DocumentOut>[].obs;
  final isSaving = false.obs;
  final isUploadingEvidence = false.obs;
  final uploadProgress = RxnDouble();
  final errorMessage = RxnString();
  final lastScanStatus = RxnString();

  bool get hasSelectedEvidence => selectedEvidence.isNotEmpty;

  bool get hasCleanEvidenceReady =>
      selectedEvidence.isNotEmpty &&
      selectedEvidence.every((doc) => doc.isScanClean);

  bool get hasPendingEvidenceScan =>
      selectedEvidence.any((doc) => doc.isScanPending);

  void dispose() {
    issuerCtrl.dispose();
    identifierCtrl.dispose();
  }
}
