import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../../shared/widgets/async_action.dart';
import '../../../../../shared/widgets/au_state_dropdown.dart';
import '../../../../shifts/data/models/shift_models.dart';
import '../../../data/composer_models.dart';
import '../roster_composer_controller.dart';
import 'travel_section.dart';

/// Step 3 — place triad (centre / client site / Other) + optional travel.
class ComposerPlaceSection extends GetView<RosterComposerController> {
  const ComposerPlaceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final place = controller.draft.value.place;
      final options = controller.placeOptions.value;
      final loading = controller.placeOptionsLoading.value;
      final err = controller.placeOptionsError.value;
      final otherSelected = place is ShiftPlaceLabelled;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Place', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Centre, a participant site, or another address — not only client homes.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (err != null) ...[
            Text(err, style: const TextStyle(color: AppColors.error)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: controller.retryPlaceOptions,
                child: const Text('Retry'),
              ),
            ),
          ],
          if (!loading &&
              err == null &&
              options.branches.isEmpty &&
              options.participantSites.isEmpty &&
              !otherSelected)
            const Text(
              'Add a place',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ..._branchTiles(options, place),
          ..._siteTiles(options, place),
          ListTile(
            key: const Key('composer-place-other'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Other address'),
            subtitle: const Text(
              'Look up an ad-hoc address',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            trailing: Icon(
              otherSelected ? Icons.check_circle : Icons.circle_outlined,
              color: otherSelected ? AppColors.brand : AppColors.slate400,
            ),
            onTap: controller.beginOtherPlace,
          ),
          if (otherSelected) ...[
            const SizedBox(height: 8),
            const _OtherPlaceFields(),
          ],
          const SizedBox(height: 28),
          const ComposerTravelSection(),
        ],
      );
    });
  }

  List<Widget> _branchTiles(PlaceOptionsOut options, ShiftPlaceIn? place) {
    return [
      for (final b in options.branches)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(b.name),
          subtitle: Text(
            b.displayAddress,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          trailing: Icon(
            _isBranchSelected(place, b.id)
                ? Icons.check_circle
                : Icons.circle_outlined,
            color:
                _isBranchSelected(place, b.id)
                    ? AppColors.brand
                    : AppColors.slate400,
          ),
          onTap: () => controller.setPlace(ShiftPlaceIn.branch(b.id)),
        ),
    ];
  }

  List<Widget> _siteTiles(PlaceOptionsOut options, ShiftPlaceIn? place) {
    return [
      for (final s in options.participantSites)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${s.clientName} · ${s.name}'),
          subtitle: Text(
            s.displayAddress.isEmpty
                ? 'Participant site'
                : s.displayAddress,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          trailing: Icon(
            _isSiteSelected(place, s.id)
                ? Icons.check_circle
                : Icons.circle_outlined,
            color:
                _isSiteSelected(place, s.id)
                    ? AppColors.brand
                    : AppColors.slate400,
          ),
          onTap: () => controller.setPlace(ShiftPlaceIn.clientSite(s.id)),
        ),
    ];
  }

  bool _isBranchSelected(ShiftPlaceIn? place, String branchId) =>
      place is ShiftPlaceBranch && place.branchId == branchId;

  bool _isSiteSelected(ShiftPlaceIn? place, String siteId) =>
      place is ShiftPlaceClientSite && place.clientSiteId == siteId;
}

class _OtherPlaceFields extends StatefulWidget {
  const _OtherPlaceFields();

  @override
  State<_OtherPlaceFields> createState() => _OtherPlaceFieldsState();
}

class _OtherPlaceFieldsState extends State<_OtherPlaceFields> {
  final controller = Get.find<RosterComposerController>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final formatted = controller.otherGeocodeFormatted.value;
      final confirmed = controller.otherAddressConfirmed.value;
      final lookingUp = controller.otherIsGeocoding.value;
      final err = controller.otherGeocodeError.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller.otherLabelCtrl,
            decoration: const InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'Community centre / park',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) {
              if (confirmed) controller.commitOtherPlaceFromGeocode();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.otherAddressLine1Ctrl,
            onChanged: (_) => controller.invalidateOtherAddressConfirm(),
            decoration: const InputDecoration(
              labelText: 'Address line 1 *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.otherCityCtrl,
            onChanged: (_) => controller.invalidateOtherAddressConfirm(),
            decoration: const InputDecoration(
              labelText: 'Suburb / city *',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          AuStateDropdown(
            value: controller.otherStateCtrl.text,
            onChanged: (selected) {
              controller.otherStateCtrl.text = selected;
              controller.invalidateOtherAddressConfirm();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller.otherPostalCtrl,
            decoration: const InputDecoration(
              labelText: 'Postal code *',
              hintText: 'e.g. 2000',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) {
              controller.commitOtherPlaceFromGeocode();
            },
          ),
          const SizedBox(height: 12),
          if (formatted == null && !confirmed) ...[
            AsyncOutlinedButton(
              key: const Key('composer-other-lookup'),
              onPressed: controller.lookupOtherAddress,
              isLoading: lookingUp,
              child: const Text('Look up address'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Next also looks up automatically when address fields are filled.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: confirmed ? AppColors.primaryLight : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      confirmed
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
                            onPressed: controller.editOtherAddress,
                            child: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: controller.confirmOtherAddress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cta,
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
                      onPressed: controller.editOtherAddress,
                      child: const Text('Edit address'),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (err != null) ...[
            const SizedBox(height: 8),
            Text(
              err,
              key: const Key('composer-other-geocode-error'),
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      );
    });
  }
}
