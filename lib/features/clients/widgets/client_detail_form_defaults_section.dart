import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/clients_controller.dart';

/// Per-client default form templates (A8-X1) — feeds visit form resolver.
class ClientDetailFormDefaultsSection extends StatelessWidget {
  const ClientDetailFormDefaultsSection({super.key, required this.controller});

  final ClientsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.formDefaultsLoading.value;
      final saving = controller.formDefaultsSaving.value;
      final err = controller.formDefaultsError.value;
      final catalog = controller.formDefaultsCatalog.toList(growable: false);
      final selected = controller.formDefaultsSelectedIds.toSet();
      final canEdit = controller.canManage;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Visit form defaults',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Templates applied to new visits for this client (unless the shift overrides them).',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (err != null) ...[
            Text(err, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            TextButton(
              onPressed: () {
                final id = controller.selected.value?.id;
                if (id != null) controller.loadFormDefaults(id);
              },
              child: const Text('Retry'),
            ),
          ],
          if (!loading && catalog.isEmpty)
            const Text(
              'No active form templates yet. Create one under Supports → Form templates.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            )
          else
            for (final t in catalog)
              CheckboxListTile(
                key: Key('client-form-default-${t.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: selected.contains(t.id),
                onChanged:
                    canEdit && !saving
                        ? (v) =>
                            controller.toggleFormDefaultTemplate(t.id, v == true)
                        : null,
                title: Text(t.name),
                controlAffinity: ListTileControlAffinity.leading,
              ),
          if (canEdit && catalog.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AsyncElevatedButton(
                key: const Key('client-form-defaults-save'),
                onPressed: controller.saveFormDefaults,
                isLoading: saving,
                child: const Text('Save form defaults'),
              ),
            ),
          ],
        ],
      );
    });
  }
}
