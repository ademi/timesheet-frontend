import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/app_file_field.dart';
import '../../../shared/widgets/app_switch_field.dart';
import '../controllers/support_plan_clinical_store.dart';
import '../models/identity_card_attachment.dart';

/// Care-plan clinical on-file flags + deferred document picks (V040).
///
/// PDFs stay local until Save draft / Activate.
class SupportPlanClinicalSection extends StatelessWidget {
  const SupportPlanClinicalSection({
    super.key,
    required this.store,
  });

  final SupportPlanClinicalStore store;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Clinical documents',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose PDFs here — they upload when you Save draft or Activate.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Medical report',
            onFile: store.medicalPdfOnFile.value,
            pdfOnFile: store.medicalPdfOnFile.value,
            pending: store.pendingMedical.value,
            isUploading: store.isUploadingMedical.value,
            onToggle: null,
            onPick: store.pickMedicalPdf,
            onClearPending: store.clearPendingMedical,
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Behaviour support plan',
            helper:
                'Document on file is separate from the Care plan BSP flag below — set both when a BSP applies. PDF uploads apply on Save draft / Activate.',
            onFile: store.bspOnFile.value,
            pdfOnFile: store.bspPdfOnFile.value,
            pending: store.pendingBsp.value,
            isUploading: store.isUploadingBsp.value,
            onToggle: (v) => store.bspOnFile.value = v,
            onPick: store.pickBspPdf,
            onClearPending: store.clearPendingBsp,
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Nutrition checklist',
            onFile: store.nutritionChecklistOnFile.value,
            pdfOnFile: store.nutritionPdfOnFile.value,
            pending: store.pendingNutrition.value,
            isUploading: store.isUploadingNutrition.value,
            onToggle: (v) => store.nutritionChecklistOnFile.value = v,
            onPick: store.pickNutritionPdf,
            onClearPending: store.clearPendingNutrition,
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Hazard checklist',
            onFile: store.hazardChecklistOnFile.value,
            pdfOnFile: store.hazardPdfOnFile.value,
            pending: store.pendingHazard.value,
            isUploading: store.isUploadingHazard.value,
            onToggle: (v) => store.hazardChecklistOnFile.value = v,
            onPick: store.pickHazardPdf,
            onClearPending: store.clearPendingHazard,
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
    required this.pending,
    required this.isUploading,
    required this.onPick,
    required this.onClearPending,
    this.onToggle,
    this.helper,
  });

  final String label;
  final bool onFile;
  final bool pdfOnFile;
  final PendingIdentityCardFile? pending;
  final bool isUploading;
  final ValueChanged<bool>? onToggle;
  final Future<void> Function() onPick;
  final VoidCallback onClearPending;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final hasPending = pending != null;
    final fileName =
        pending?.name ?? (pdfOnFile ? 'On file' : null);
    final pickLabel =
        hasPending || pdfOnFile ? 'Replace file' : 'Choose file';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onToggle != null)
          AppSwitchField(
            label: label,
            subtitle: helper,
            value: onFile,
            onChanged: isUploading ? null : onToggle,
          ),
        if (onToggle != null) const SizedBox(height: 8),
        AppFileField(
          label: onToggle != null ? '$label PDF' : label,
          fileName: fileName,
          enabled: !isUploading,
          onPick: () {
            onPick();
          },
          onClear: hasPending && !isUploading ? onClearPending : null,
          pickLabel: isUploading ? 'Uploading…' : pickLabel,
          helperText: onToggle == null ? helper : null,
        ),
      ],
    );
  }
}
