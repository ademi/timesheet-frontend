import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/models/shift_models.dart';
import '../data/models/shift_participant_models.dart';
import '../utils/allocation_math.dart';
import 'participant_allocation_form.dart';

class ShiftParticipantsSection extends StatelessWidget {
  const ShiftParticipantsSection({
    super.key,
    required this.shift,
    required this.clients,
    required this.participantNames,
    required this.canManage,
    required this.isSaving,
    required this.onAdd,
    required this.onUpdate,
    required this.onReplaceTimeBased,
    required this.onRemove,
  });

  final ShiftOut shift;
  final List<ShiftClientOption> clients;
  final Map<String, String> participantNames;
  final bool canManage;
  final bool isSaving;
  final Future<void> Function(ShiftParticipantCreateRequest request) onAdd;
  final Future<void> Function(
    ShiftParticipantOut participant,
    ShiftParticipantAllocationUpdateRequest request,
  )
  onUpdate;
  final Future<void> Function(
    ShiftParticipantOut participant,
    ShiftParticipantCreateRequest request,
  )
  onReplaceTimeBased;
  final Future<void> Function(ShiftParticipantOut participant, String reason)
  onRemove;

  List<ShiftParticipantOut> get _active =>
      activeParticipants(shift.participants);

  String _name(String id) => participantNames[id] ?? 'Participant';

  String _formatNumber(double value) =>
      value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(1);

  String _participantTitle(ShiftParticipantOut participant) {
    final name = _name(participant.participantId);
    return participant.participantId == shift.clientId ? '$name (host)' : name;
  }

  String _participantSubtitle(ShiftParticipantOut participant) {
    if (participant.allocationStrategy == 'percentage') {
      return 'Percentage · ${_formatNumber(participant.allocationValue)}%';
    }
    final count = participant.timeWindows?.length ?? 0;
    return 'Time-based · $count window${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final removed =
        shift.participants
            .where((participant) => !participant.isActive)
            .toList();
    final strategy = active.isEmpty ? null : active.first.allocationStrategy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Participants',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (canManage && shift.status == 'draft')
              TextButton.icon(
                onPressed: isSaving ? null : () => _showAdd(context, strategy),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add'),
              ),
          ],
        ),
        Text(
          'Host job client: ${shift.clientName ?? 'Unknown'}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 8),
        if (active.isEmpty)
          const Text('No active participants.')
        else
          for (final participant in active)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_participantTitle(participant)),
              subtitle: Text(_participantSubtitle(participant)),
              trailing:
                  !canManage
                      ? null
                      : Wrap(
                        spacing: 4,
                        children: [
                          if (shift.status == 'draft')
                            IconButton(
                              tooltip:
                                  'Edit ${_name(participant.participantId)}',
                              onPressed:
                                  isSaving
                                      ? null
                                      : () => _showEdit(context, participant),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          IconButton(
                            tooltip:
                                'Remove ${_name(participant.participantId)}',
                            onPressed:
                                isSaving
                                    ? null
                                    : () => _showRemove(context, participant),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
            ),
        const SizedBox(height: 4),
        Text(
          strategy == 'time_based'
              ? 'Time-based · ${active.fold<int>(0, (sum, participant) => sum + (participant.timeWindows?.length ?? 0))} windows'
              : 'Sum: ${_formatNumber(sumActivePercentage(active))}% · '
                  'Remaining: ${_formatNumber(remainingPercentage(active))}%',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (removed.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Removed (${removed.length})'),
            children: [
              for (final participant in removed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_name(participant.participantId)),
                  subtitle: Text(_participantSubtitle(participant)),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _showAdd(BuildContext context, String? strategy) async {
    final activeIds = _active.map((participant) => participant.participantId);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => _FormSheet(
            title: 'Add participant',
            child: ParticipantAllocationForm(
              clients: clients,
              excludeClientIds: activeIds.toSet(),
              shiftStart: shift.scheduledStart,
              shiftEnd: shift.scheduledEnd,
              lockStrategy: strategy,
              remainingPercentage: remainingPercentage(shift.participants),
              onSubmit: (request) async {
                await onAdd(request);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
            ),
          ),
    );
  }

  Future<void> _showEdit(
    BuildContext context,
    ShiftParticipantOut participant,
  ) async {
    final isTimeBased = participant.allocationStrategy == 'time_based';
    final participantClient = [
      (id: participant.participantId, name: _name(participant.participantId)),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetContext) => _FormSheet(
            title: 'Edit participant',
            child: ParticipantAllocationForm(
              clients: isTimeBased ? participantClient : clients,
              excludeClientIds: const {},
              shiftStart: shift.scheduledStart,
              shiftEnd: shift.scheduledEnd,
              lockStrategy: participant.allocationStrategy,
              remainingPercentage:
                  remainingPercentage(shift.participants) +
                  participant.allocationValue,
              submitLabel: 'Save',
              initialParticipantId:
                  isTimeBased ? null : participant.participantId,
              initialAllocationValue:
                  isTimeBased ? null : participant.allocationValue,
              initialTimeWindows: participant.timeWindows
                  ?.map(
                    (window) => ShiftParticipantAllocationWindow(
                      participantStartTime: window.participantStartTime,
                      participantEndTime: window.participantEndTime,
                    ),
                  )
                  .toList(growable: false),
              onSubmit: (request) async {
                await onReplaceTimeBased(participant, request);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              },
              onSubmitUpdate:
                  isTimeBased
                      ? null
                      : (request) async {
                        await onUpdate(participant, request);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
            ),
          ),
    );
  }

  Future<void> _showRemove(
    BuildContext context,
    ShiftParticipantOut participant,
  ) async {
    final reasonController = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: Text('Remove ${_name(participant.participantId)}?'),
              content: TextField(
                controller: reasonController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) return;
                    await onRemove(participant, reason);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('Remove'),
                ),
              ],
            ),
      );
    } finally {
      reasonController.dispose();
    }
  }
}

class _FormSheet extends StatelessWidget {
  const _FormSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
