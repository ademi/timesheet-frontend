import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../app/data/models/document/document_models.dart';
import '../../../core/errors/app_failure.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/models/client_profile_models.dart';
import '../data/repositories/clients_repository.dart';
import '../models/identity_card_attachment.dart';
import '../utils/clinical_keys.dart';

/// Care-plan clinical on-file flags + deferred document uploads (profile facts).
///
/// PDFs are held locally until [persistFacts] (Save draft / Activate).
class SupportPlanClinicalStore {
  SupportPlanClinicalStore({
    required ClientsRepository repository,
    DocumentPipeline? documentPipeline,
    Future<({String name, List<int> bytes})?> Function()? pickPdfBytes,
    bool Function()? canUploadDocs,
    VoidCallback? onReload,
  }) : _repository = repository,
       _pipeline = documentPipeline,
       _pickPdfBytes = pickPdfBytes,
       _canUploadDocs = canUploadDocs ?? (() => true),
       onReload = onReload;

  final ClientsRepository _repository;
  final DocumentPipeline? _pipeline;
  final Future<({String name, List<int> bytes})?> Function()? _pickPdfBytes;
  final bool Function() _canUploadDocs;

  VoidCallback? onReload;

  final isLoading = false.obs;
  final isBusy = false.obs;
  final errorMessage = RxnString();

  bool hasHydrated = false;

  final _presentKeys = <String>{};
  final _factUpdatedAt = <String, DateTime>{};

  static const conflictMessage =
      'Clinical documents were updated elsewhere — review and save again.';

  final bspOnFile = false.obs;
  final nutritionChecklistOnFile = false.obs;
  final hazardChecklistOnFile = false.obs;

  final bspPdfOnFile = false.obs;
  final nutritionPdfOnFile = false.obs;
  final hazardPdfOnFile = false.obs;
  final medicalPdfOnFile = false.obs;

  final pendingMedical = Rxn<PendingIdentityCardFile>();
  final pendingBsp = Rxn<PendingIdentityCardFile>();
  final pendingNutrition = Rxn<PendingIdentityCardFile>();
  final pendingHazard = Rxn<PendingIdentityCardFile>();

  final isUploadingMedical = false.obs;
  final isUploadingBsp = false.obs;
  final isUploadingNutrition = false.obs;
  final isUploadingHazard = false.obs;

  Future<({String name, List<int> bytes})?> _resolvePickPdfBytes() async {
    final override = _pickPdfBytes;
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

  bool _ensureCanPick() {
    errorMessage.value = null;
    if (_pipeline == null) {
      errorMessage.value = 'Document upload is not configured.';
      return false;
    }
    if (!_canUploadDocs()) {
      errorMessage.value =
          'Missing documents.upload / clients.docs.manage permission.';
      return false;
    }
    return true;
  }

  Future<void> _pickInto(Rxn<PendingIdentityCardFile> pending) async {
    if (!_ensureCanPick()) return;
    final picked = await _resolvePickPdfBytes();
    if (picked == null) return;
    pending.value = PendingIdentityCardFile(
      name: picked.name,
      bytes: picked.bytes,
      contentType: 'application/pdf',
    );
  }

  Future<void> pickMedicalPdf() => _pickInto(pendingMedical);
  Future<void> pickBspPdf() => _pickInto(pendingBsp);
  Future<void> pickNutritionPdf() => _pickInto(pendingNutrition);
  Future<void> pickHazardPdf() => _pickInto(pendingHazard);

  void clearPendingMedical() => pendingMedical.value = null;
  void clearPendingBsp() => pendingBsp.value = null;
  void clearPendingNutrition() => pendingNutrition.value = null;
  void clearPendingHazard() => pendingHazard.value = null;

  void _clearAllPending() {
    pendingMedical.value = null;
    pendingBsp.value = null;
    pendingNutrition.value = null;
    pendingHazard.value = null;
  }

  void applyProfileBundle(ClientProfileBundle bundle) {
    _presentKeys
      ..clear()
      ..addAll(bundle.facts.map((f) => f.requirementKey));
    _factUpdatedAt
      ..clear()
      ..addEntries([
        for (final f in bundle.facts)
          if (f.updatedAt != null) MapEntry(f.requirementKey, f.updatedAt!),
      ]);

    bspOnFile.value = _boolFact(bundle, ClinicalKeys.bspOnFile) ?? false;
    nutritionChecklistOnFile.value =
        _boolFact(bundle, ClinicalKeys.nutritionChecklistOnFile) ?? false;
    hazardChecklistOnFile.value =
        _boolFact(bundle, ClinicalKeys.hazardChecklistOnFile) ?? false;

    bspPdfOnFile.value = _hasDocument(
      bundle,
      ClinicalKeys.behaviourSupportPlanDoc,
    );
    nutritionPdfOnFile.value = _hasDocument(
      bundle,
      ClinicalKeys.nutritionChecklist,
    );
    hazardPdfOnFile.value = _hasDocument(bundle, ClinicalKeys.hazardChecklist);
    medicalPdfOnFile.value = _hasDocument(bundle, ClinicalKeys.medicalReport);

    _clearAllPending();
    hasHydrated = true;
  }

  Future<void> reload(String clientId) async {
    if (clientId.isEmpty) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final bundle = await _repository.getClientProfile(clientId);
      applyProfileBundle(bundle);
      onReload?.call();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<String>> persistFacts({required String clientId}) async {
    if (!hasHydrated || clientId.isEmpty) return const [];

    final jobs = <({String key, String label, Future<void> future})>[];

    Future<void> uploadPending({
      required Rxn<PendingIdentityCardFile> pending,
      required RxBool uploading,
      required RxBool pdfOnFile,
      required String requirementKey,
      required String category,
    }) async {
      final file = pending.value;
      if (file == null) return;
      final pipeline = _pipeline;
      if (pipeline == null) {
        throw const AppFailure(
          message: 'Document upload is not configured.',
          code: 'upload_not_configured',
          presentation: AppFailurePresentation.inline,
        );
      }
      if (!_canUploadDocs()) {
        throw const AppFailure(
          message:
              'Missing documents.upload / clients.docs.manage permission.',
          code: 'permission_denied',
          presentation: AppFailurePresentation.inline,
        );
      }
      uploading.value = true;
      try {
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
        await _repository.upsertProfileFact(
          clientId,
          requirementKey,
          ProfileFactUpsert(documentId: doc.id),
        );
        pending.value = null;
        pdfOnFile.value = true;
      } finally {
        uploading.value = false;
      }
    }

    if (pendingMedical.value != null) {
      jobs.add((
        key: ClinicalKeys.medicalReport,
        label: 'Medical report PDF',
        future: uploadPending(
          pending: pendingMedical,
          uploading: isUploadingMedical,
          pdfOnFile: medicalPdfOnFile,
          requirementKey: ClinicalKeys.medicalReport,
          category: ClinicalKeys.documentCategoryMedical,
        ),
      ));
    }
    if (pendingBsp.value != null) {
      jobs.add((
        key: ClinicalKeys.behaviourSupportPlanDoc,
        label: 'Behaviour support plan PDF',
        future: uploadPending(
          pending: pendingBsp,
          uploading: isUploadingBsp,
          pdfOnFile: bspPdfOnFile,
          requirementKey: ClinicalKeys.behaviourSupportPlanDoc,
          category: ClinicalKeys.documentCategoryBsp,
        ),
      ));
    }
    if (pendingNutrition.value != null) {
      jobs.add((
        key: ClinicalKeys.nutritionChecklist,
        label: 'Nutrition checklist PDF',
        future: uploadPending(
          pending: pendingNutrition,
          uploading: isUploadingNutrition,
          pdfOnFile: nutritionPdfOnFile,
          requirementKey: ClinicalKeys.nutritionChecklist,
          category: ClinicalKeys.documentCategoryNutrition,
        ),
      ));
    }
    if (pendingHazard.value != null) {
      jobs.add((
        key: ClinicalKeys.hazardChecklist,
        label: 'Hazard checklist PDF',
        future: uploadPending(
          pending: pendingHazard,
          uploading: isUploadingHazard,
          pdfOnFile: hazardPdfOnFile,
          requirementKey: ClinicalKeys.hazardChecklist,
          category: ClinicalKeys.documentCategoryHazard,
        ),
      ));
    }

    void putBool(String key, String label, bool value) {
      jobs.add((
        key: key,
        label: label,
        future: _repository.upsertProfileFact(
          clientId,
          key,
          ProfileFactUpsert(
            valueJson: value,
            expectedUpdatedAt: _factUpdatedAt[key],
          ),
        ),
      ));
    }

    putBool(ClinicalKeys.bspOnFile, 'BSP on file', bspOnFile.value);
    putBool(
      ClinicalKeys.nutritionChecklistOnFile,
      'Nutrition checklist on file',
      nutritionChecklistOnFile.value,
    );
    putBool(
      ClinicalKeys.hazardChecklistOnFile,
      'Hazard checklist on file',
      hazardChecklistOnFile.value,
    );

    final results = await Future.wait(
      jobs.map((j) async {
        try {
          await j.future;
          return null;
        } on AppFailure catch (e) {
          if (e.code == 'profile_fact_conflict' || e.statusCode == 409) {
            return conflictMessage;
          }
          return j.label;
        } catch (_) {
          return j.label;
        }
      }),
    );
    return results.whereType<String>().toSet().toList(growable: false);
  }

  static ClientProfileFactOut? _fact(ClientProfileBundle b, String key) {
    for (final f in b.facts) {
      if (f.requirementKey == key) return f;
    }
    return null;
  }

  static bool? _boolFact(ClientProfileBundle b, String key) {
    final v = _fact(b, key)?.valueJson;
    if (v is bool) return v;
    if (v == null) return null;
    final s = v.toString().toLowerCase();
    if (s == 'true') return true;
    if (s == 'false') return false;
    return null;
  }

  static bool _hasDocument(ClientProfileBundle b, String key) {
    final docId = _fact(b, key)?.documentId;
    return docId != null && docId.isNotEmpty;
  }
}
