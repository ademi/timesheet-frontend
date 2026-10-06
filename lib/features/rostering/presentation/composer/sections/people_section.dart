import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../../shared/models/profile_photo_models.dart';
import '../../../../../shared/widgets/profile_photo_editor.dart';
import '../../../../clients/data/models/client_models.dart';
import '../../../../shifts/utils/allocation_math.dart';
import '../../../domain/occurrence_draft.dart';
import '../roster_composer_controller.dart';

/// Step 1 — who is this for (preset + client pick).
///
/// In-page command search + results list (not an overlay autocomplete), so
/// duplicate names stay scannable and the parent ListView does not fight an
/// Overlay. Allocation / worker slots only appear for group after clients exist.
class ComposerPeopleSection extends GetView<RosterComposerController> {
  const ComposerPeopleSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ids = controller.draft.value.participantIds;
      final showAlloc = controller.showsAllocation && ids.isNotEmpty;
      final showSlots = controller.showsWorkerCount;
      final slotsCount = controller.workerSlotCount;
      final preset = controller.draft.value.preset;
      final isGroup = controller.isGroup;
      final showSearch = isGroup || ids.isEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Session type', style: Get.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ComposerPreset>(
            key: const Key('composer-preset'),
            segments: const [
              ButtonSegment(
                value: ComposerPreset.oneSession,
                label: Text('One session'),
                icon: Icon(Icons.person_outline, size: 18),
              ),
              ButtonSegment(
                value: ComposerPreset.group,
                label: Text('Group'),
                icon: Icon(Icons.groups_outlined, size: 18),
              ),
            ],
            selected: {preset},
            onSelectionChanged: (next) {
              if (next.isNotEmpty) controller.setPreset(next.first);
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  isGroup ? 'Participants' : 'Client',
                  style: Get.textTheme.titleMedium,
                ),
              ),
              if (ids.isNotEmpty)
                Text(
                  isGroup ? '${ids.length} selected' : 'Selected',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isGroup
                ? 'Search and add participants (max 32).'
                : 'Search and select the client for this session.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (ids.isNotEmpty) ...[
            for (final id in ids)
              _SelectedClientTile(
                name: controller.participantName(id) ?? id,
                photo: controller.photoFor(id),
                subtitle: _selectedSubtitle(id),
                onRemove: () => controller.removeParticipant(id),
              ),
            const SizedBox(height: 8),
          ] else
            const _EmptyClientHint(),
          if (showSearch) ...[
            _ClientCommandSearch(controller: controller),
            const SizedBox(height: 8),
            _ClientResultsList(controller: controller),
          ] else if (!isGroup && ids.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('composer-change-client'),
                onPressed: () => controller.removeParticipant(ids.first),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Change client'),
              ),
            ),
          if (showAlloc) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text('Allocation', style: Get.textTheme.titleSmall),
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
            if (!controller.draft.value.equalSplit) ...[
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
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: const Key('composer-worker-count'),
              value: slotsCount,
              decoration: const InputDecoration(
                labelText: 'Worker slots',
                helperText:
                    'Fill on the Workers step; empty slots open for claim',
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
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Groups are limited to 32 participants',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
        ],
      );
    });
  }

  String? _selectedSubtitle(String id) {
    for (final c in controller.clients) {
      if (c.id == id) return controller.clientPickerSubtitle(c);
    }
    return null;
  }
}

class _EmptyClientHint extends StatelessWidget {
  const _EmptyClientHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.brandSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.slate200),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_search_outlined, color: AppColors.brand, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No client selected yet. Type a name below to find one.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedClientTile extends StatelessWidget {
  const _SelectedClientTile({
    required this.name,
    required this.onRemove,
    this.photo,
    this.subtitle,
  });

  final String name;
  final ProfilePhotoOut? photo;
  final String? subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: _ClientPhoto(photo: photo),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle:
            subtitle == null || subtitle!.isEmpty
                ? null
                : Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close),
          onPressed: onRemove,
        ),
      ),
    );
  }
}

class _ClientCommandSearch extends StatefulWidget {
  const _ClientCommandSearch({required this.controller});

  final RosterComposerController controller;

  @override
  State<_ClientCommandSearch> createState() => _ClientCommandSearchState();
}

class _ClientCommandSearchState extends State<_ClientCommandSearch> {
  late final TextEditingController _text;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.controller.clientSearch.value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final q = widget.controller.clientSearch.value;
      if (_text.text != q) {
        final synced = q;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _text.text == synced) return;
          _text.value = TextEditingValue(
            text: synced,
            selection: TextSelection.collapsed(offset: synced.length),
          );
          setState(() {});
        });
      }
      return TextField(
        key: const Key('composer-client-search'),
        controller: _text,
        autofocus: false,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          labelText:
              widget.controller.isGroup
                  ? 'Search clients to add'
                  : 'Search clients',
          hintText: 'Name, email, or phone',
          border: const OutlineInputBorder(),
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon:
              q.isEmpty
                  ? null
                  : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _text.clear();
                      widget.controller.clientSearch.value = '';
                    },
                  ),
        ),
        onChanged: (value) {
          widget.controller.clientSearch.value = value;
        },
      );
    });
  }
}

class _ClientResultsList extends StatelessWidget {
  const _ClientResultsList({required this.controller});

  final RosterComposerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final q = controller.clientSearch.value.trim();
      if (q.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Keep typing to filter the client list.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        );
      }

      final options = controller.clientPickerOptions(q);
      if (options.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No clients match “$q”.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${options.length} match${options.length == 1 ? '' : 'es'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          for (final client in options)
            _ClientResultRow(
              key: ValueKey(client.id),
              client: client,
              subtitle: controller.clientPickerSubtitle(client),
              photo: controller.photoFor(client.id),
              onTap: () async {
                await controller.addParticipant(client);
                controller.clientSearch.value = '';
              },
            ),
        ],
      );
    });
  }
}

class _ClientResultRow extends StatelessWidget {
  const _ClientResultRow({
    super.key,
    required this.client,
    required this.subtitle,
    required this.onTap,
    this.photo,
  });

  final ClientOut client;
  final String subtitle;
  final ProfilePhotoOut? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _ClientPhoto(photo: photo, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline, color: AppColors.brand),
            ],
          ),
        ),
      ),
    );
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
