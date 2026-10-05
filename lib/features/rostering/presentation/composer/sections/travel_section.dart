import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../shifts/data/models/shift_travel_models.dart';
import '../roster_composer_controller.dart';

/// Optional labour travel shares — empty is OK; pin shown after publish.
class ComposerTravelSection extends StatefulWidget {
  const ComposerTravelSection({super.key});

  @override
  State<ComposerTravelSection> createState() => _ComposerTravelSectionState();
}

class _ComposerTravelSectionState extends State<ComposerTravelSection> {
  late final RosterComposerController controller;
  late final TextEditingController _minutesCtrl;

  @override
  void initState() {
    super.initState();
    controller = Get.find<RosterComposerController>();
    _minutesCtrl = TextEditingController(
      text: controller.travelLabourMinutes.value,
    );
  }

  @override
  void dispose() {
    _minutesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final minutes = controller.travelLabourMinutes.value;
      final mode = controller.travelMode.value;
      final err = controller.travelError.value;
      final labour = [
        for (final c in controller.travelClaims)
          if (c.isLabour) c,
      ];
      final pin = labour.isEmpty ? null : labour.first.pinStatus;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Travel', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Optional. Empty is OK.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          if (pin != null && pin != TravelSharePinStatus.draft) ...[
            const SizedBox(height: 8),
            Text(
              key: const Key('composer-travel-pin'),
              'Pin: ${pin.apiValue}',
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('composer-travel-minutes'),
            controller: _minutesCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Labour minutes',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: controller.setTravelLabourMinutes,
          ),
          if (minutes.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<TravelApportionmentMode>(
              key: const Key('composer-travel-mode'),
              value: mode,
              decoration: const InputDecoration(
                labelText: 'Share mode',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: TravelApportionmentMode.equal,
                  child: Text('Equal'),
                ),
                DropdownMenuItem(
                  value: TravelApportionmentMode.nominated,
                  child: Text('Nominated'),
                ),
                DropdownMenuItem(
                  value: TravelApportionmentMode.explicit,
                  child: Text('Explicit'),
                ),
              ],
              onChanged: (v) {
                if (v != null) controller.setTravelMode(v);
              },
            ),
            if (mode == TravelApportionmentMode.nominated) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('composer-travel-nominee'),
                value: controller.travelNominatedClientId.value,
                decoration: const InputDecoration(
                  labelText: 'Nominated participant',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final id in controller.draft.value.participantIds)
                    DropdownMenuItem(
                      value: id,
                      child: Text(controller.participantName(id) ?? id),
                    ),
                ],
                onChanged: controller.setTravelNominatedClientId,
              ),
            ],
            if (mode == TravelApportionmentMode.explicit) ...[
              const SizedBox(height: 12),
              for (final id in controller.draft.value.participantIds) ...[
                _ExplicitShareField(
                  key: Key('composer-travel-share-$id'),
                  clientId: id,
                  label: controller.participantName(id) ?? id,
                  initial: controller.travelExplicitShares[id] ?? '',
                  onChanged: controller.setTravelExplicitShare,
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
          if (err != null) ...[
            const SizedBox(height: 8),
            Text(
              err,
              key: const Key('composer-travel-error'),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      );
    });
  }
}

class _ExplicitShareField extends StatefulWidget {
  const _ExplicitShareField({
    super.key,
    required this.clientId,
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String clientId;
  final String label;
  final String initial;
  final void Function(String clientId, String minutes) onChanged;

  @override
  State<_ExplicitShareField> createState() => _ExplicitShareFieldState();
}

class _ExplicitShareFieldState extends State<_ExplicitShareField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Share minutes · ${widget.label}',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => widget.onChanged(widget.clientId, v),
    );
  }
}
