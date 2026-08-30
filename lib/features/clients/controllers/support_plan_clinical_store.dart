import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../app/data/models/document/document_models.dart';
import '../../../core/errors/app_failure.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/models/client_profile_models.dart';
import '../data/repositories/clients_repository.dart';
import '../utils/clinical_keys.dart';

/// Care-plan clinical on-file flags + document uploads (profile facts).
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

    bspPdfOnFile.value = _hasDocument(bundle, ClinicalKeys.behaviourSupportPlanDoc);
    nutritionPdfOnFile.value =
        _hasDocument(bundle, ClinicalKeys.nutritionChecklist);
    hazardPdfOnFile.value = _hasDocument(bundle, ClinicalKeys.hazardChecklist);
    medicalPdfOnFile.value = _hasDocument(bundle, ClinicalKeys.medicalReport);

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

  Future<bool> uploadClinicalPdf({
    required String clientId,
    required String requirementKey,
    required String category,
    required void Function(bool onFile) setOnFileFlag,
    required RxBool pdfOnFile,
  }) async {
    errorMessage.value = null;
    isBusy.value = true;
    try {
      final bytes = await _resolvePickPdfBytes();
      if (bytes == null) {
        errorMessage.value = 'Select a PDF to upload.';
        return false;
      }
      final pipeline = _pipeline;
      if (pipeline == null) {
        errorMessage.value = 'Document upload is not configured.';
        return false;
      }
      if (!_canUploadDocs()) {
        errorMessage.value =
            'Missing documents.upload / clients.docs.manage permission.';
        return false;
      }
      final doc = await pipeline.uploadEvidence(
        request: UploadUrlRequest(
          ownerType: 'client',
          ownerId: clientId,
          filename: bytes.name,
          contentType: 'application/pdf',
          sizeBytes: bytes.bytes.length,
          category: category,
        ),
        bytes: bytes.bytes,
      );
      await _repository.upsertProfileFact(
        clientId,
        requirementKey,
        ProfileFactUpsert(documentId: doc.id),
      );
      pdfOnFile.value = true;
      setOnFileFlag(true);
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> uploadBspPdf({required String clientId}) => uploadClinicalPdf(
        clientId: clientId,
        requirementKey: ClinicalKeys.behaviourSupportPlanDoc,
        category: ClinicalKeys.documentCategoryBsp,
        setOnFileFlag: (v) => bspOnFile.value = v,
        pdfOnFile: bspPdfOnFile,
      );

  Future<bool> uploadNutritionPdf({required String clientId}) =>
      uploadClinicalPdf(
        clientId: clientId,
        requirementKey: ClinicalKeys.nutritionChecklist,
        category: ClinicalKeys.documentCategoryNutrition,
        setOnFileFlag: (v) => nutritionChecklistOnFile.value = v,
        pdfOnFile: nutritionPdfOnFile,
      );

  Future<bool> uploadHazardPdf({required String clientId}) => uploadClinicalPdf(
        clientId: clientId,
        requirementKey: ClinicalKeys.hazardChecklist,
        category: ClinicalKeys.documentCategoryHazard,
        setOnFileFlag: (v) => hazardChecklistOnFile.value = v,
        pdfOnFile: hazardPdfOnFile,
      );

  Future<bool> uploadMedicalPdf({required String clientId}) => uploadClinicalPdf(
        clientId: clientId,
        requirementKey: ClinicalKeys.medicalReport,
        category: ClinicalKeys.documentCategoryMedical,
        setOnFileFlag: (_) {},
        pdfOnFile: medicalPdfOnFile,
      );

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
