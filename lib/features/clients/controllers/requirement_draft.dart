import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/client_profile_models.dart';

/// In-memory editor state for one type requirement on Add/Edit Client.
class RequirementDraft {
  RequirementDraft(this.requirement) {
    if (requirement.isForm) {
      for (final field in requirement.formFields) {
        formFieldCtrls[field.id] = TextEditingController();
      }
    }
    if (requirement.isLegal) {
      relationshipCtrl.text = 'self';
      method.value = 'staff_recorded';
    }
  }

  final ClientTypeRequirement requirement;

  final textCtrl = TextEditingController();
  final dateValue = Rxn<DateTime>();
  final boolValue = false.obs;
  final multiSelect = <String>[].obs;
  final localFiles = <PickedClientFile>[].obs;
  final existingDocumentId = RxnString();
  final existingDocumentFilename = RxnString();

  final formFieldCtrls = <String, TextEditingController>{};

  final legalDoc = Rxn<ClientLegalDocumentCurrent>();
  final legalLoading = false.obs;
  final legalAccepted = false.obs;
  final participantNameCtrl = TextEditingController();
  final relationshipCtrl = TextEditingController();
  final method = 'staff_recorded'.obs;
  final noteCtrl = TextEditingController();
  final alreadyAccepted = false.obs;

  bool get capturesField =>
      requirement.capturesField || requirement.isSharingFlag;

  bool get capturesDocument => requirement.capturesDocument;

  Object? get fieldValueJson {
    final type = requirement.valueType ?? 'text';
    switch (type) {
      case 'boolean':
      case 'sharing_flag':
        return boolValue.value;
      case 'date':
        final d = dateValue.value;
        if (d == null) return null;
        return _ymd(d);
      case 'number':
        final raw = textCtrl.text.trim();
        if (raw.isEmpty) return null;
        return num.tryParse(raw) ?? raw;
      case 'multiselect':
        return multiSelect.isEmpty ? null : List<String>.from(multiSelect);
      case 'textarea':
      case 'text':
      case 'select':
      default:
        final raw = textCtrl.text.trim();
        return raw.isEmpty ? null : raw;
    }
  }

  Map<String, dynamic>? get formPayload {
    if (!requirement.isForm) return null;
    final map = <String, dynamic>{};
    var any = false;
    for (final entry in formFieldCtrls.entries) {
      final v = entry.value.text.trim();
      if (v.isNotEmpty) {
        map[entry.key] = v;
        any = true;
      }
    }
    return any ? map : null;
  }

  bool get hasFieldContent {
    if (!capturesField) return false;
    final type = requirement.valueType ?? 'text';
    if (type == 'boolean' || requirement.isSharingFlag) {
      return _booleanTouched;
    }
    return fieldValueJson != null;
  }

  /// True when the user actually interacted with a boolean (sharing / switch).
  bool get booleanTouched => _booleanTouched;
  bool _booleanTouched = false;

  void setBool(bool value) {
    _booleanTouched = true;
    boolValue.value = value;
  }

  bool get hasDocumentContent =>
      localFiles.isNotEmpty || existingDocumentId.value != null;

  bool get hasFormContent => formPayload != null;

  bool get hasLegalContent =>
      legalAccepted.value && participantNameCtrl.text.trim().isNotEmpty;

  bool get hasAnyContent {
    if (requirement.isForm) return hasFormContent;
    if (requirement.isLegal) return hasLegalContent;
    if (requirement.isSharingFlag) return _booleanTouched;
    return hasFieldContent || localFiles.isNotEmpty;
  }

  void applyFact(ClientProfileFactOut fact) {
    if (fact.documentId != null) {
      existingDocumentId.value = fact.documentId;
      existingDocumentFilename.value = 'Document on file';
    }
    final value = fact.valueJson;
    if (value == null) return;
    final type = requirement.valueType ?? 'text';
    switch (type) {
      case 'boolean':
        _booleanTouched = true;
        boolValue.value = value == true || value == 'true';
      case 'date':
        if (value is String && value.isNotEmpty) {
          dateValue.value = DateTime.tryParse(value);
        }
      case 'number':
        textCtrl.text = value.toString();
      case 'multiselect':
        if (value is List) {
          multiSelect.assignAll(value.map((e) => e.toString()));
        }
      default:
        textCtrl.text = value.toString();
    }
  }

  void applyForm(ClientFormSubmissionOut submission) {
    for (final entry in submission.payloadJson.entries) {
      final ctrl = formFieldCtrls[entry.key];
      if (ctrl != null && entry.value != null) {
        ctrl.text = entry.value.toString();
      }
    }
  }

  void applyLegal(ClientLegalAcceptanceOut acceptance) {
    alreadyAccepted.value = true;
    legalAccepted.value = true;
    if (acceptance.participantOrRepName != null) {
      participantNameCtrl.text = acceptance.participantOrRepName!;
    }
    if (acceptance.relationship != null) {
      relationshipCtrl.text = acceptance.relationship!;
    }
    if (acceptance.method != null) {
      method.value = acceptance.method!;
    }
  }

  static String formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  void dispose() {
    textCtrl.dispose();
    for (final c in formFieldCtrls.values) {
      c.dispose();
    }
    participantNameCtrl.dispose();
    relationshipCtrl.dispose();
    noteCtrl.dispose();
  }

  static String _ymd(DateTime d) => formatDate(d);
}
