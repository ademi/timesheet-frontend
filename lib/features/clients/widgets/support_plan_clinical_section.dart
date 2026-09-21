import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/app_file_field.dart';
import '../../../shared/widgets/app_switch_field.dart';
import '../controllers/support_plan_clinical_store.dart';

/// Care-plan clinical on-file flags + document uploads (V040).
class SupportPlanClinicalSection extends StatelessWidget {
  const SupportPlanClinicalSection({
    super.key,
    required this.store,
    required this.clientId,
  });

  final SupportPlanClinicalStore store;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = store.isBusy.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Clinical documents',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Upload completed PDFs for now — structured checklist forms come later.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Behaviour support plan',
            helper:
                'Document on file is separate from the Care plan BSP flag below — set both when a BSP applies.',
            onFile: store.bspOnFile.value,
            pdfOnFile: store.bspPdfOnFile.value,
            onToggle: (v) => store.bspOnFile.value = v,
            onUpload:
                busy ? null : () => store.uploadBspPdf(clientId: clientId),
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Medical report',
            onFile: store.medicalPdfOnFile.value,
            pdfOnFile: store.medicalPdfOnFile.value,
            onToggle: null,
            onUpload:
                busy ? null : () => store.uploadMedicalPdf(clientId: clientId),
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Nutrition checklist',
            onFile: store.nutritionChecklistOnFile.value,
            pdfOnFile: store.nutritionPdfOnFile.value,
            onToggle: (v) => store.nutritionChecklistOnFile.value = v,
            onUpload:
                busy
                    ? null
                    : () => store.uploadNutritionPdf(clientId: clientId),
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Hazard checklist',
            onFile: store.hazardChecklistOnFile.value,
            pdfOnFile: store.hazardPdfOnFile.value,
            onToggle: (v) => store.hazardChecklistOnFile.value = v,
            onUpload:
                busy ? null : () => store.uploadHazardPdf(clientId: clientId),
          ),
        ],
      );
    });
  }
}

class _ClinicalDocRow extends StatelessWidget {
  const _ClinicalDocRow({
    required this.label,
    required this.onFile,
    required this.pdfOnFile,
    required this.onUpload,
    this.onToggle,
    this.helper,
  });

  final String label;
  final bool onFile;
  final bool pdfOnFile;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onUpload;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onToggle != null)
          AppSwitchField(
            label: label,
            subtitle: helper,
            value: onFile,
            onChanged: onToggle,
          ),
        if (onToggle != null) const SizedBox(height: 8),
        AppFileField(
          label: onToggle != null ? '$label PDF' : label,
          fileName: pdfOnFile ? 'On file' : null,
          enabled: onUpload != null,
          onPick: onUpload ?? () {},
          pickLabel: pdfOnFile ? 'Replace file' : 'Choose file',
          helperText: onToggle == null ? helper : null,
        ),
      ],
    );
  }
}
