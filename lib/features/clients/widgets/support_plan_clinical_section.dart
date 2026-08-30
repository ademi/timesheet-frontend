import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
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
            onUpload: busy
                ? null
                : () => store.uploadBspPdf(clientId: clientId),
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Medical report',
            onFile: store.medicalPdfOnFile.value,
            pdfOnFile: store.medicalPdfOnFile.value,
            onToggle: null,
            onUpload: busy
                ? null
                : () => store.uploadMedicalPdf(clientId: clientId),
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Nutrition checklist',
            onFile: store.nutritionChecklistOnFile.value,
            pdfOnFile: store.nutritionPdfOnFile.value,
            onToggle: (v) => store.nutritionChecklistOnFile.value = v,
            onUpload: busy
                ? null
                : () => store.uploadNutritionPdf(clientId: clientId),
          ),
          const SizedBox(height: 12),
          _ClinicalDocRow(
            label: 'Hazard checklist',
            onFile: store.hazardChecklistOnFile.value,
            pdfOnFile: store.hazardPdfOnFile.value,
            onToggle: (v) => store.hazardChecklistOnFile.value = v,
            onUpload: busy
                ? null
                : () => store.uploadHazardPdf(clientId: clientId),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            subtitle: helper != null
                ? Text(helper!, style: const TextStyle(fontSize: 12))
                : null,
            value: onFile,
            onChanged: onToggle,
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label),
            trailing: Text(
              pdfOnFile ? 'PDF on file' : 'No PDF',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pdfOnFile ? AppColors.success : AppColors.textMuted,
              ),
            ),
          ),
        if (onToggle == null && helper != null) ...[
          Text(
            helper!,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
        ],
        if (onToggle != null && helper == null)
          Padding(
            padding: const EdgeInsets.only(left: 0, bottom: 4),
            child: Text(
              pdfOnFile ? 'PDF on file' : 'No PDF uploaded',
              style: TextStyle(
                fontSize: 12,
                color: pdfOnFile ? AppColors.success : AppColors.textMuted,
              ),
            ),
          ),
        OutlinedButton(
          onPressed: onUpload,
          child: Text(pdfOnFile ? 'Replace PDF' : 'Upload PDF'),
        ),
      ],
    );
  }
}
