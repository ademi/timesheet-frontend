import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/job_models.dart';
import 'jobs_controller.dart';

/// Local draft row for one schema field while editing a template.
class FormTemplateFieldDraft {
  FormTemplateFieldDraft({
    required String id,
    required String label,
    String type = 'text',
    bool required = false,
    List<String> accept = const [],
  }) : idCtrl = TextEditingController(text: id),
       labelCtrl = TextEditingController(text: label),
       acceptCtrl = TextEditingController(text: accept.join(', ')),
       type = type.obs,
       required = required.obs;

  factory FormTemplateFieldDraft.fromJson(Map<String, dynamic> json) {
    final acceptRaw = json['accept'];
    return FormTemplateFieldDraft(
      id: (json['id'] ?? json['key'] ?? '').toString(),
      label: json['label'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      required: json['required'] as bool? ?? false,
      accept: acceptRaw is List
          ? acceptRaw
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
          : const <String>[],
    );
  }

  factory FormTemplateFieldDraft.blank({required String id}) =>
      FormTemplateFieldDraft(id: id, label: '', type: 'text');

  final TextEditingController idCtrl;
  final TextEditingController labelCtrl;
  final TextEditingController acceptCtrl;
  final RxString type;
  final RxBool required;

  /// When true, changing the label auto-updates the field id.
  bool syncIdFromLabel = true;

  void dispose() {
    idCtrl.dispose();
    labelCtrl.dispose();
    acceptCtrl.dispose();
  }

  Map<String, dynamic> toJson() {
    final accept = acceptCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return {
      'id': idCtrl.text.trim(),
      'type': type.value,
      'label': labelCtrl.text.trim(),
      'required': required.value,
      if (type.value == 'file' && accept.isNotEmpty) 'accept': accept,
    };
  }
}

class FormTemplateEditorController extends GetxController {
  final jobs = Get.find<JobsController>();

  final nameCtrl = TextEditingController();
  final isActive = true.obs;
  final fields = <FormTemplateFieldDraft>[].obs;
  final error = RxnString();
  final isSaving = false.obs;

  FormTemplateOut? existing;

  bool get isEditing => existing != null;

  @override
  void onInit() {
    super.onInit();
    final arg = Get.arguments;
    if (arg is FormTemplateOut) {
      existing = arg;
      nameCtrl.text = arg.name;
      isActive.value = arg.isActive;
      final raw = arg.schemaJson['fields'];
      if (raw is List) {
        fields.assignAll(
          raw
              .whereType<Map>()
              .map(
                (e) => FormTemplateFieldDraft.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((f) => f.idCtrl.text.isNotEmpty),
        );
        for (final f in fields) {
          f.syncIdFromLabel = false;
        }
      }
    }
    if (fields.isEmpty) {
      fields.add(
        FormTemplateFieldDraft(
          id: 'notes',
          label: 'Notes',
          type: 'textarea',
        )..syncIdFromLabel = false,
      );
    }
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    for (final f in fields) {
      f.dispose();
    }
    super.onClose();
  }

  void addField() {
    fields.add(FormTemplateFieldDraft.blank(id: _uniqueId('field')));
  }

  void removeField(int index) {
    if (fields.length <= 1) {
      error.value = 'At least one field is required.';
      return;
    }
    final removed = fields.removeAt(index);
    removed.dispose();
    error.value = null;
  }

  void reorderFields(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = fields.removeAt(oldIndex);
    fields.insert(newIndex, item);
  }

  void onLabelChanged(FormTemplateFieldDraft field) {
    if (!field.syncIdFromLabel) return;
    field.idCtrl.text = _uniqueId(
      slugifyFormFieldId(field.labelCtrl.text),
      exclude: field,
    );
  }

  void onIdEdited(FormTemplateFieldDraft field) {
    field.syncIdFromLabel = false;
  }

  String? validate() {
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return 'Template name is required.';
    if (fields.isEmpty) return 'Add at least one field.';

    final seen = <String>{};
    for (var i = 0; i < fields.length; i++) {
      final f = fields[i];
      final id = f.idCtrl.text.trim();
      final label = f.labelCtrl.text.trim();
      if (id.isEmpty) return 'Field ${i + 1}: id is required.';
      if (!seen.add(id)) return 'Duplicate field id: $id';
      if (label.isEmpty) return 'Field ${i + 1}: label is required.';
      if (!formTemplateFieldTypes.contains(f.type.value)) {
        return 'Field ${i + 1}: unsupported type.';
      }
    }
    return null;
  }

  Map<String, dynamic> buildSchemaJson() => {
    'fields': [for (final f in fields) f.toJson()],
  };

  Future<bool> save() async {
    final validationError = validate();
    if (validationError != null) {
      error.value = validationError;
      return false;
    }
    error.value = null;
    isSaving.value = true;
    try {
      final ok = await jobs.saveFormTemplate(
        id: existing?.id,
        name: nameCtrl.text.trim(),
        isActive: isActive.value,
        schemaJson: buildSchemaJson(),
      );
      return ok;
    } finally {
      isSaving.value = false;
    }
  }

  String _uniqueId(String base, {FormTemplateFieldDraft? exclude}) {
    var candidate = base.isEmpty ? 'field' : base;
    var n = 2;
    while (fields.any(
      (f) => f != exclude && f.idCtrl.text.trim() == candidate,
    )) {
      candidate = '${base}_$n';
      n++;
    }
    return candidate;
  }
}
