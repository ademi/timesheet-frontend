import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'support_plan_professional_fields.dart';
import 'support_plan_specialist_types.dart';

/// One dynamic support specialist row (type + optional custom label + 7 fields).
class SupportPlanSpecialistEntry {
  SupportPlanSpecialistEntry._({
    required this.id,
    required this.type,
    String? customLabel,
    SupportPlanProfessionalFields? fields,
    bool expanded = false,
  })  : customLabelCtrl = TextEditingController(text: customLabel ?? ''),
        fields = fields ?? SupportPlanProfessionalFields(),
        expanded = expanded.obs;

  static int _idSeq = 0;

  static String _nextId() =>
      'specialist-${DateTime.now().microsecondsSinceEpoch}-${++_idSeq}';

  factory SupportPlanSpecialistEntry.fromLegacy({
    required String type,
    required SupportPlanProfessionalFields fields,
  }) {
    if (!SupportPlanSpecialistTypes.isValid(type)) {
      throw ArgumentError.value(type, 'type', 'unknown specialist type');
    }
    return SupportPlanSpecialistEntry._(
      id: _nextId(),
      type: type,
      fields: fields,
    );
  }

  factory SupportPlanSpecialistEntry.create(
    String type, {
    String? customLabel,
    bool expanded = false,
  }) {
    if (!SupportPlanSpecialistTypes.isValid(type)) {
      throw ArgumentError.value(type, 'type', 'unknown specialist type');
    }
    return SupportPlanSpecialistEntry._(
      id: _nextId(),
      type: type,
      customLabel: customLabel,
      expanded: expanded,
    );
  }

  final String id;
  final String type;
  final TextEditingController customLabelCtrl;
  final SupportPlanProfessionalFields fields;
  final RxBool expanded;
  final revision = 0.obs;

  String get title {
    revision.value;
    return SupportPlanSpecialistTypes.label(
        type,
        customLabel: customLabelCtrl.text,
      );
  }

  String get nameFieldLabel =>
      SupportPlanSpecialistTypes.nameFieldLabel(type);

  bool get isOther => type == SupportPlanSpecialistTypes.other;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (isOther && customLabelCtrl.text.trim().isNotEmpty)
          'custom_label': customLabelCtrl.text.trim(),
        'name': fields.nameCtrl.text.trim(),
        'company': fields.companyCtrl.text.trim(),
        'abn_acn': fields.abnAcnCtrl.text.trim(),
        'org_id': fields.orgIdCtrl.text.trim(),
        'phone': fields.phoneCtrl.text.trim(),
        'email': fields.emailCtrl.text.trim(),
        'address': fields.addressCtrl.text.trim(),
      };

  factory SupportPlanSpecialistEntry.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    if (!SupportPlanSpecialistTypes.isValid(type)) {
      throw FormatException('Invalid specialist type: $type');
    }
    final entry = SupportPlanSpecialistEntry.create(
      type,
      customLabel: json['custom_label']?.toString(),
    );
    entry.fields.nameCtrl.text = json['name']?.toString() ?? '';
    entry.fields.companyCtrl.text = json['company']?.toString() ?? '';
    entry.fields.abnAcnCtrl.text = json['abn_acn']?.toString() ?? '';
    entry.fields.orgIdCtrl.text = json['org_id']?.toString() ?? '';
    entry.fields.phoneCtrl.text = json['phone']?.toString() ?? '';
    entry.fields.emailCtrl.text = json['email']?.toString() ?? '';
    entry.fields.addressCtrl.text = json['address']?.toString() ?? '';
    return entry;
  }

  bool get hasAnyFieldFilled {
    if (customLabelCtrl.text.trim().isNotEmpty) return true;
    return fields.nameCtrl.text.trim().isNotEmpty ||
        fields.companyCtrl.text.trim().isNotEmpty ||
        fields.abnAcnCtrl.text.trim().isNotEmpty ||
        fields.orgIdCtrl.text.trim().isNotEmpty ||
        fields.phoneCtrl.text.trim().isNotEmpty ||
        fields.emailCtrl.text.trim().isNotEmpty ||
        fields.addressCtrl.text.trim().isNotEmpty;
  }

  void dispose() {
    customLabelCtrl.dispose();
    fields.dispose();
  }
}
