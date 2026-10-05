import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../../shared/models/profile_photo_models.dart';
import '../../../../../shared/widgets/profile_photo_editor.dart';
import '../../../../clients/data/models/client_models.dart';
import '../../../../shifts/utils/allocation_math.dart';
import '../../../domain/occurrence_draft.dart';
import '../roster_composer_controller.dart';

/// Step 1 — clients (+ allocation / slots for group).
class ComposerPeopleSection extends GetView<RosterComposerController> {
  const ComposerPeopleSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ids = controller.draft.value.participantIds;
      final showAlloc = controller.showsAllocation;
      final showSlots = controller.showsWorkerCount;
      final slotsCount = controller.workerSlotCount;
      final preset = controller.draft.value.preset;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ComposerPreset>(
            key: const Key('composer-preset'),
            segments: const [
              ButtonSegment(
                value: ComposerPreset.oneSession,
                label: Text('One session'),
              ),
              ButtonSegment(value: ComposerPreset.group, label: Text('Group')),
            ],
            selected: {preset},
            onSelectionChanged: (next) {
              if (next.isNotEmpty) controller.setPreset(next.first);
            },
          ),
          const SizedBox(height: 16),
          Text('Clients', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            controller.isGroup
                ? 'Search and add participants (max 32).'
                : 'Search and select the client for this session.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          for (final id in ids)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _ClientPhoto(
                photo: controller.photoFor(id),
              ),
              title: Text(controller.participantName(id) ?? id),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => controller.removeParticipant(id),
              ),
            ),
          if (ids.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'No client selected yet.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          if (controller.isGroup || ids.isEmpty) ...[
            const SizedBox(height: 4),
            _ClientSearchField(controller: controller),
          ],
          if (showAlloc) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Equal split'),
              subtitle: const Text(
                'Split 100% evenly across clients',
                style: TextStyle(fontSize: 12),
              ),
              value: controller.draft.value.equalSplit,
              onChanged: controller.setEqualSplit,
            ),
            Text(
              'Allocation ${controller.draft.value.equalSplit ? 'equal' : 'custom'}',
              key: const Key('composer-allocation'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            if (!controller.draft.value.equalSplit && ids.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final id in ids) ...[
                _AllocationPercentField(
                  key: Key('composer-alloc-$id'),
                  participantId: id,
                  label: controller.participantName(id) ?? id,
                  initial: controller.allocationPercents[id],
                  onChanged: controller.setAllocationPercent,
                ),
                const SizedBox(height: 8),
              ],
              Text(
                key: const Key('composer-alloc-remaining'),
                remainingCapacityLabel([
                  for (final id in ids)
                    controller.allocationPercents[id] ?? 0.0,
                ]),
                style: TextStyle(
                  color:
                      sumsTo100([
                            for (final id in ids)
                              controller.allocationPercents[id] ?? 0.0,
                          ])
                          ? AppColors.textMuted
                          : AppColors.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
          if (showSlots) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('composer-worker-count'),
              value: slotsCount,
              decoration: const InputDecoration(
                labelText: 'Worker slots',
                helperText: 'Fill on the Workers step; empty slots open for claim',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (var n = 1; n <= 8; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (v) {
                if (v != null) controller.setWorkerSlots(v);
              },
            ),
          ],
          if (atHardCap(ids.length))
            const Text(
              'Groups are limited to 32 participants',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
        ],
      );
    });
  }
}

class _AllocationPercentField extends StatefulWidget {
  const _AllocationPercentField({
    super.key,
    required this.participantId,
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String participantId;
  final String label;
  final double? initial;
  final void Function(String participantId, double? percent) onChanged;

  @override
  State<_AllocationPercentField> createState() =>
      _AllocationPercentFieldState();
}

class _AllocationPercentFieldState extends State<_AllocationPercentField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    _ctrl = TextEditingController(
      text: v == null ? '' : (v == v.roundToDouble() ? '${v.round()}' : v.toString()),
    );
  }

  @override
  void didUpdateWidget(covariant _AllocationPercentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      final v = widget.initial;
      final next =
          v == null
              ? ''
              : (v == v.roundToDouble() ? '${v.round()}' : v.toString());
      if (_ctrl.text != next) _ctrl.text = next;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Allocation % · ${widget.label}',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixText: '%',
      ),
      onChanged: (raw) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          widget.onChanged(widget.participantId, null);
          return;
        }
        widget.onChanged(widget.participantId, double.tryParse(trimmed));
      },
    );
  }
}

/// Autocomplete kept outside draft Obx writes so selecting a row cannot lose
/// the pick to a rebuild race (mutating [clientSearch] used to rebuild parent).
class _ClientSearchField extends StatelessWidget {
  const _ClientSearchField({required this.controller});

  final RosterComposerController controller;

  Iterable<ClientOut> _optionsFor(String raw) {
    final q = raw.trim().toLowerCase();
    final taken = controller.draft.value.participantIds.toSet();
    final list = <ClientOut>[
      for (final c in controller.clients)
        if (!taken.contains(c.id) &&
            (q.isEmpty || c.fullName.toLowerCase().contains(q)))
          c,
    ];
    list.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
    return list.take(12);
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ClientOut>(
      key: const Key('composer-client-autocomplete'),
      displayStringForOption: (c) => c.fullName,
      optionsBuilder: (textEditingValue) => _optionsFor(textEditingValue.text),
      onSelected: (client) async {
        await controller.addParticipant(client);
      },
      fieldViewBuilder: (
        context,
        textController,
        focusNode,
        onFieldSubmitted,
      ) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText:
                controller.isGroup
                    ? 'Search clients to add'
                    : 'Search clients',
            border: const OutlineInputBorder(),
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 480),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final client = options.elementAt(index);
                  return ListTile(
                    leading: _ClientPhoto(
                      photo: controller.photoFor(client.id),
                      size: 36,
                    ),
                    title: Text(client.fullName),
                    onTap: () => onSelected(client),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClientPhoto extends StatelessWidget {
  const _ClientPhoto({this.photo, this.size = 44});

  final ProfilePhotoOut? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ProfilePhotoEditor(
      networkUrl: photo?.downloadUrl,
      documentId: photo?.documentId,
      readOnly: true,
      size: size,
      showLabel: false,
    );
  }
}
