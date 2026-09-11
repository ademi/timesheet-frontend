import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../clients/data/models/client_models.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../utils/allocation_math.dart';
import '../utils/group_participant_draft.dart';
import 'group_shift_edit_controller.dart';

class GroupShiftEditView extends GetView<GroupShiftEditController> {
  const GroupShiftEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit group')),
      body: Obx(() {
        final draft = controller.draft.value;
        final err = controller.errorMessage.value;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (err != null) ...[
                          _ErrorBox(err),
                          const SizedBox(height: 12),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Equal split'),
                          value: draft.equalSplit,
                          onChanged:
                              controller.isSaving.value
                                  ? null
                                  : (v) => controller.setEqualSplit(v),
                        ),
                        if (!draft.equalSplit) ...[
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              controller.remainingLabel,
                              style: TextStyle(
                                color:
                                    sumsTo100(
                                          draft.participants.map(
                                            (p) => p.allocationValue,
                                          ),
                                        )
                                        ? AppColors.textMuted
                                        : AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed:
                                controller.isSaving.value ||
                                        atHardCap(draft.length)
                                    ? null
                                    : () => _openPicker(context),
                            icon: const Icon(Icons.person_add_outlined),
                            label: const Text('Add'),
                          ),
                        ),
                        for (final row in draft.participants)
                          _EditRow(
                            row: row,
                            equalSplit: draft.equalSplit,
                            enabled: !controller.isSaving.value,
                            onRemove:
                                () => controller.removeParticipant(
                                  row.participantId,
                                ),
                            onAllocationChanged:
                                draft.equalSplit
                                    ? null
                                    : (v) => controller.setAllocation(
                                      row.participantId,
                                      v,
                                    ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            FormStickyActions(
              onCancel:
                  controller.isSaving.value ? null : () => Get.back(),
              primaryLabel: 'Save',
              onPrimary: controller.isSaving.value ? null : controller.save,
              isLoading: controller.isSaving.value,
            ),
          ],
        );
      }),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    if (!Get.isRegistered<ClientsRepository>()) return;
    final repo = Get.find<ClientsRepository>();
    List<ClientOut> clients;
    try {
      clients = await repo.listClients();
    } catch (_) {
      return;
    }
    final taken = {
      for (final p in controller.draft.value.participants) p.participantId,
    };
    final candidates = [
      for (final c in clients)
        if (!taken.contains(c.id)) c,
    ];
    if (!context.mounted) return;
    final picked = await Navigator.of(context).push<ClientOut>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => _EditParticipantPickerPage(candidates: candidates),
      ),
    );
    if (picked != null) {
      await controller.addParticipant(
        participantId: picked.id,
        displayName: picked.fullName,
      );
    }
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.row,
    required this.equalSplit,
    required this.enabled,
    required this.onRemove,
    this.onAllocationChanged,
  });

  final GroupParticipantDraft row;
  final bool equalSplit;
  final bool enabled;
  final VoidCallback onRemove;
  final ValueChanged<double>? onAllocationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          minVerticalPadding: 12,
          title: Text(row.displayName),
          subtitle: Text(
            equalSplit
                ? '${row.allocationValue.toStringAsFixed(2)}%'
                : 'Capacity %',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          trailing: IconButton(
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close),
          ),
        ),
        if (!equalSplit && onAllocationChanged != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextFormField(
              enabled: enabled,
              initialValue: row.allocationValue.toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Capacity %',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (raw) {
                final v = double.tryParse(raw);
                if (v != null) onAllocationChanged!(v);
              },
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

class _EditParticipantPickerPage extends StatefulWidget {
  const _EditParticipantPickerPage({required this.candidates});
  final List<ClientOut> candidates;

  @override
  State<_EditParticipantPickerPage> createState() =>
      _EditParticipantPickerPageState();
}

class _EditParticipantPickerPageState
    extends State<_EditParticipantPickerPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = [
      for (final c in widget.candidates)
        if (q.isEmpty || c.fullName.toLowerCase().contains(q)) c,
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add participant')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search clients',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child:
                list.isEmpty
                    ? const Center(child: Text('No clients to add.'))
                    : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final c = list[index];
                        return ListTile(
                          minVerticalPadding: 14,
                          title: Text(c.fullName),
                          onTap: () => Navigator.of(context).pop(c),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
