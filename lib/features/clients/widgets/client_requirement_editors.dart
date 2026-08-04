import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/clients_controller.dart';
import '../controllers/requirement_draft.dart';

/// Renders one schema-driven client type requirement.
class ClientRequirementEditor extends StatelessWidget {
  const ClientRequirementEditor({
    super.key,
    required this.controller,
    required this.draft,
  });

  final ClientsController controller;
  final RequirementDraft draft;

  @override
  Widget build(BuildContext context) {
    final req = draft.requirement;
    final title = req.isRequired ? '${req.label} *' : req.label;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (req.sensitivityClass != null &&
                  req.sensitivityClass!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.errorBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    req.sensitivityClass!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
          if (req.helpText != null && req.helpText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              req.helpText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (req.isForm)
            _FormFields(draft: draft)
          else if (req.isLegal)
            _LegalBlock(controller: controller, draft: draft)
          else if (req.isSharingFlag)
            _SharingSwitch(draft: draft)
          else ...[
            if (draft.capturesField) _FieldInput(controller: controller, draft: draft),
            if (draft.capturesField && draft.capturesDocument)
              const SizedBox(height: 10),
            if (draft.capturesDocument)
              _DocumentPicker(controller: controller, draft: draft),
          ],
        ],
      ),
    );
  }
}

class _FieldInput extends StatelessWidget {
  const _FieldInput({required this.controller, required this.draft});

  final ClientsController controller;
  final RequirementDraft draft;

  @override
  Widget build(BuildContext context) {
    final type = draft.requirement.valueType ?? 'text';
    final placeholder = draft.requirement.placeholder;

    switch (type) {
      case 'boolean':
        return Obx(
          () => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(draft.requirement.label),
            value: draft.boolValue.value,
            onChanged: draft.setBool,
          ),
        );
      case 'date':
        return Obx(() {
          final d = draft.dateValue.value;
          final label = d == null
              ? 'Select date'
              : RequirementDraft.formatDate(d);
          return OutlinedButton.icon(
            onPressed: () => controller.pickDateForRequirement(draft),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(label),
          );
        });
      case 'multiselect':
        final options = draft.requirement.selectOptions;
        return Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final opt in options)
                FilterChip(
                  label: Text(opt),
                  selected: draft.multiSelect.contains(opt),
                  onSelected: (selected) {
                    if (selected) {
                      draft.multiSelect.add(opt);
                    } else {
                      draft.multiSelect.remove(opt);
                    }
                  },
                ),
            ],
          ),
        );
      case 'select':
        final options = draft.requirement.selectOptions;
        return DropdownButtonFormField<String>(
          value: draft.textCtrl.text.isEmpty ? null : draft.textCtrl.text,
          items: [
            for (final opt in options)
              DropdownMenuItem(value: opt, child: Text(opt)),
          ],
          onChanged: (v) {
            draft.textCtrl.text = v ?? '';
          },
          decoration: InputDecoration(
            labelText: draft.requirement.label,
            hintText: placeholder,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );
      case 'textarea':
        return TextField(
          controller: draft.textCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: placeholder,
            border: const OutlineInputBorder(),
          ),
        );
      case 'number':
        return TextField(
          controller: draft.textCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: placeholder,
            border: const OutlineInputBorder(),
          ),
        );
      default:
        return TextField(
          controller: draft.textCtrl,
          decoration: InputDecoration(
            hintText: placeholder,
            border: const OutlineInputBorder(),
          ),
        );
    }
  }
}

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({required this.controller, required this.draft});

  final ClientsController controller;
  final RequirementDraft draft;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final files = draft.localFiles;
      final existing = draft.existingDocumentId.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: controller.isSaving.value
                ? null
                : () => controller.pickFilesForRequirement(draft),
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              draft.requirement.maxFiles > 1
                  ? 'Add file(s)'
                  : 'Upload file',
            ),
          ),
          if (existing != null) ...[
            const SizedBox(height: 6),
            Text(
              'Current document on file',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
          for (var i = 0; i < files.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
              title: Text(files[i].name, overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => controller.removePickedFile(draft, i),
              ),
            ),
        ],
      );
    });
  }
}

class _FormFields extends StatelessWidget {
  const _FormFields({required this.draft});

  final RequirementDraft draft;

  @override
  Widget build(BuildContext context) {
    final fields = draft.requirement.formFields;
    if (fields.isEmpty) {
      return const Text(
        'No form fields defined for this requirement.',
        style: TextStyle(color: AppColors.textMuted),
      );
    }
    return Column(
      children: [
        for (final field in fields) ...[
          TextField(
            controller: draft.formFieldCtrls[field.id],
            maxLines: field.type == 'textarea' ? 3 : 1,
            keyboardType: switch (field.type) {
              'number' => TextInputType.number,
              'phone' => TextInputType.phone,
              'email' => TextInputType.emailAddress,
              _ => TextInputType.text,
            },
            decoration: InputDecoration(
              labelText: field.required ? '${field.label} *' : field.label,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SharingSwitch extends StatelessWidget {
  const _SharingSwitch({required this.draft});

  final RequirementDraft draft;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow sharing'),
            subtitle: const Text(
              'Grant specific contractors later from Edit client.',
            ),
            value: draft.boolValue.value,
            onChanged: draft.setBool,
          ),
        ],
      ),
    );
  }
}

class _LegalBlock extends StatelessWidget {
  const _LegalBlock({required this.controller, required this.draft});

  final ClientsController controller;
  final RequirementDraft draft;

  static const _methods = [
    ('staff_recorded', 'Staff recorded'),
    ('verbal', 'Verbal'),
    ('wet_ink_sighted', 'Wet ink sighted'),
    ('uploaded_scan', 'Uploaded scan'),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = draft.legalLoading.value;
      final doc = draft.legalDoc.value;
      final already = draft.alreadyAccepted.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (doc == null)
            const Text(
              'Could not load consent text.',
              style: TextStyle(color: AppColors.error),
            )
          else ...[
            Text(
              doc.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (doc.counselPending)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Counsel review pending',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: MarkdownBody(
                    data: doc.contentMd,
                    selectable: true,
                    styleSheet:
                        MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (already) ...[
            const SizedBox(height: 8),
            const Text(
              'Consent already recorded. Update attestation below to re-confirm.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: draft.participantNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Participant / representative name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.relationshipCtrl,
            decoration: const InputDecoration(
              labelText: 'Relationship',
              hintText: 'self',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: draft.method.value,
            items: [
              for (final m in _methods)
                DropdownMenuItem(value: m.$1, child: Text(m.$2)),
            ],
            onChanged: (v) {
              if (v != null) draft.method.value = v;
            },
            decoration: const InputDecoration(
              labelText: 'Method *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: draft.noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Confirm consent recorded'),
            value: draft.legalAccepted.value,
            onChanged: (v) => draft.legalAccepted.value = v ?? false,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      );
    });
  }
}
