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
      final count = controller.draft.value.workerCount;
      final slotsCount = controller.draft.value.requiredSlots;
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
            Autocomplete<ClientOut>(
              key: const Key('composer-client-autocomplete'),
              displayStringForOption: (c) => c.fullName,
              optionsBuilder: (textEditingValue) {
                controller.clientSearch.value = textEditingValue.text;
                return controller.pickerCandidates.take(12);
              },
              onSelected: (client) {
                controller.addParticipant(client);
                controller.clientSearch.value = '';
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
                      constraints: const BoxConstraints(
                        maxHeight: 240,
                        maxWidth: 480,
                      ),
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
            ),
          ],
          if (showAlloc) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Equal split'),
              value: controller.draft.value.equalSplit,
              onChanged: controller.setEqualSplit,
            ),
            Text(
              'Allocation ${controller.draft.value.equalSplit ? 'equal' : 'custom'}',
              key: const Key('composer-allocation'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
          if (showSlots) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('composer-worker-count'),
                    value: count,
                    decoration: const InputDecoration(
                      labelText: 'Workers planned',
                      helperText: 'How many workers you expect',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (var n = 1; n <= 8; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (v) {
                      if (v != null) controller.setWorkerCount(v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('composer-required-slots'),
                    value: slotsCount,
                    decoration: const InputDecoration(
                      labelText: 'Open claim slots',
                      helperText: 'Holes left on the board',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (var n = 1; n <= 8; n++)
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (v) {
                      if (v != null) controller.setRequiredSlots(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'These can differ — e.g. plan 2 workers but leave 1 open claim '
              'slot, or pre-assign some and leave the rest claimable.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
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
