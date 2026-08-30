import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../data/models/strengths_needs_models.dart';
import '../data/repositories/clients_repository.dart';
import '../utils/strengths_needs_keys.dart';

class StrengthsNeedsController extends GetxController {
  StrengthsNeedsController({
    required ClientsRepository repository,
    String? clientId,
    String? assessmentId,
    this.clientName,
  })  : _repository = repository,
        clientId = clientId ?? '' {
    if (assessmentId != null && assessmentId.isNotEmpty) {
      this.assessmentId.value = assessmentId;
    }
  }

  final ClientsRepository _repository;
  final String? clientName;

  String clientId;

  final assessmentId = RxnString();
  final status = StrengthsNeedsKeys.statusDraft.obs;
  final isCurrent = false.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();

  final completedByCtrl = TextEditingController();
  final participantNameCtrl = TextEditingController();
  final supportersNamesCtrl = TextEditingController();
  final interviewDateCtrl = TextEditingController();
  final preferencesNotesCtrl = TextEditingController();
  final additionalNotesCtrl = TextEditingController();

  late final Map<String, TextEditingController> sectionCtrls = {
    for (final key in StrengthsNeedsKeys.allSectionKeys)
      key: TextEditingController(),
  };

  bool get isBusy => isLoading.value || isSaving.value;
  bool get isSubmitted => status.value == StrengthsNeedsKeys.statusSubmitted;
  bool get canEdit => !isSubmitted;

  @override
  void onInit() {
    super.onInit();
    _readArguments();
    if (clientId.isNotEmpty) {
      load();
    }
  }

  void _readArguments() {
    final args = Get.arguments;
    if (args is! Map) return;
    clientId = args['clientId']?.toString() ?? clientId;
    final aid = args['assessmentId']?.toString();
    if (aid != null && aid.isNotEmpty) {
      assessmentId.value = aid;
    }
  }

  Future<void> load() async {
    if (clientId.isEmpty) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      StrengthsNeedsDto? dto;
      final aid = assessmentId.value;
      if (aid != null && aid.isNotEmpty) {
        dto = await _repository.getStrengthsNeeds(clientId, aid);
      } else {
        final list = await _repository.listStrengthsNeeds(clientId);
        for (final item in list) {
          if (item.status == StrengthsNeedsKeys.statusDraft) {
            dto = item;
            break;
          }
        }
        if (dto == null) {
          for (final item in list) {
            if (item.status == StrengthsNeedsKeys.statusSubmitted &&
                item.isCurrent) {
              dto = item;
              break;
            }
          }
        }
      }
      if (dto != null) {
        applyLoaded(dto);
      } else {
        _clearFields();
        status.value = StrengthsNeedsKeys.statusDraft;
        isCurrent.value = false;
        assessmentId.value = null;
      }
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'Could not load Strengths & Needs assessment.';
    } finally {
      isLoading.value = false;
    }
  }

  void applyLoaded(StrengthsNeedsDto dto) {
    assessmentId.value = dto.id;
    status.value = dto.status;
    isCurrent.value = dto.isCurrent;
    final header = dto.body.header;
    completedByCtrl.text = header.completedBy;
    participantNameCtrl.text = header.participantName;
    supportersNamesCtrl.text = header.supportersNames;
    interviewDateCtrl.text = header.interviewDate ?? '';
    preferencesNotesCtrl.text = header.preferencesNotes;
    additionalNotesCtrl.text = dto.body.additionalNotes;
    for (final key in StrengthsNeedsKeys.allSectionKeys) {
      sectionCtrls[key]!.text = dto.body.sections[key] ?? '';
    }
  }

  StrengthsNeedsBody buildBody() {
    return StrengthsNeedsBody(
      header: StrengthsNeedsHeader(
        completedBy: completedByCtrl.text.trim(),
        participantName: participantNameCtrl.text.trim(),
        supportersNames: supportersNamesCtrl.text.trim(),
        interviewDate: interviewDateCtrl.text.trim().isEmpty
            ? null
            : interviewDateCtrl.text.trim(),
        preferencesNotes: preferencesNotesCtrl.text.trim(),
      ),
      sections: {
        for (final key in StrengthsNeedsKeys.allSectionKeys)
          key: sectionCtrls[key]!.text.trim(),
      },
      additionalNotes: additionalNotesCtrl.text.trim(),
    );
  }

  Future<bool> saveDraft() async {
    if (clientId.isEmpty || !canEdit) return false;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final body = buildBody();
      final aid = assessmentId.value;
      final StrengthsNeedsDto saved;
      if (aid == null || aid.isEmpty) {
        saved = await _repository.createStrengthsNeeds(
          clientId,
          StrengthsNeedsCreateRequest(body: body),
        );
      } else {
        saved = await _repository.patchStrengthsNeeds(
          clientId,
          aid,
          StrengthsNeedsUpdateRequest(body: body),
        );
      }
      applyLoaded(saved);
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Could not save draft.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  Future<bool> submit() async {
    if (clientId.isEmpty) return false;
    final saved = await saveDraft();
    if (!saved) return false;
    final aid = assessmentId.value;
    if (aid == null || aid.isEmpty) return false;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final submitted = await _repository.submitStrengthsNeeds(clientId, aid);
      applyLoaded(submitted);
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (_) {
      errorMessage.value = 'Could not submit assessment.';
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  void _clearFields() {
    completedByCtrl.clear();
    participantNameCtrl.clear();
    supportersNamesCtrl.clear();
    interviewDateCtrl.clear();
    preferencesNotesCtrl.clear();
    additionalNotesCtrl.clear();
    for (final ctrl in sectionCtrls.values) {
      ctrl.clear();
    }
  }

  @override
  void onClose() {
    completedByCtrl.dispose();
    participantNameCtrl.dispose();
    supportersNamesCtrl.dispose();
    interviewDateCtrl.dispose();
    preferencesNotesCtrl.dispose();
    additionalNotesCtrl.dispose();
    for (final ctrl in sectionCtrls.values) {
      ctrl.dispose();
    }
    super.onClose();
  }
}
