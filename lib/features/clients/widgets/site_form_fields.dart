import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/clients_controller.dart';

/// Australian states/territories for site forms.
const auStates = <String>[
  'NSW',
  'VIC',
  'QLD',
  'WA',
  'SA',
  'TAS',
  'ACT',
  'NT',
];

/// Shared address / postal / access-notes / geocode-confirm fields.
///
/// Used by the standalone site form and the onboarding Address step.
/// When [primaryMode] is true, primary is locked on and postal is required.
class SiteFormFields extends StatefulWidget {
  const SiteFormFields({
    super.key,
    required this.controller,
    this.primaryMode = false,
    this.showNameField = true,
  });

  final ClientsController controller;
  final bool primaryMode;
  final bool showNameField;

  @override
  State<SiteFormFields> createState() => _SiteFormFieldsState();
}

class _SiteFormFieldsState extends State<SiteFormFields> {
  ClientsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    if (widget.primaryMode) {
      controller.siteIsPrimary.value = true;
    }
  }

  @override
  void didUpdateWidget(covariant SiteFormFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.primaryMode && !oldWidget.primaryMode) {
      controller.siteIsPrimary.value = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final stateValue = controller.siteState.value;
      final stateItems = {stateValue, ...auStates}.toList();
      final isPrimary =
          widget.primaryMode || controller.siteIsPrimary.value;
      final postalRequired = isPrimary;
      final formatted = controller.geocodeFormattedAddress.value;
      final confirmed = controller.addressConfirmed.value;
      final lookingUp = controller.isGeocoding.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showNameField) ...[
            TextField(
              controller: controller.siteNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: controller.siteAddressCtrl,
            onChanged: (_) => controller.invalidateSiteAddressConfirm(),
            decoration: const InputDecoration(
              labelText: 'Address line 1 *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.siteCityCtrl,
            onChanged: (_) => controller.invalidateSiteAddressConfirm(),
            decoration: const InputDecoration(
              labelText: 'City *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: stateValue,
            items: [
              for (final s in stateItems)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) {
              if (v == null) return;
              controller.siteState.value = v;
              controller.siteStateCtrl.text = v;
              controller.invalidateSiteAddressConfirm();
            },
            decoration: const InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.sitePostalCtrl,
            decoration: InputDecoration(
              labelText: postalRequired ? 'Postal code *' : 'Postal code',
              border: const OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isPrimary,
            onChanged: widget.primaryMode
                ? null
                : (v) => controller.siteIsPrimary.value = v,
            title: const Text('Primary site'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller.siteAccessNotesCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Access notes',
              hintText: 'Gate code, key location, entry instructions…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          if (formatted == null && !confirmed) ...[
            AsyncOutlinedButton(
              onPressed: controller.lookupSiteAddress,
              isLoading: lookingUp,
              child: const Text('Look up address'),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: confirmed
                    ? AppColors.primaryLight
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: confirmed
                      ? AppColors.primary
                      : AppColors.slate500.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    confirmed ? 'Confirmed address' : 'Matched address',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatted ?? 'Coordinates ready',
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                  if (!confirmed) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: controller.editSiteAddress,
                            child: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: controller.confirmSiteAddress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                            ),
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: controller.editSiteAddress,
                      child: const Text('Edit address'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}
