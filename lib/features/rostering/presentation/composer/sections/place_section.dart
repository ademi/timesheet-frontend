import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
import '../../../../shifts/data/models/shift_models.dart';
import '../../../data/composer_models.dart';
import '../roster_composer_controller.dart';

class ComposerPlaceSection extends GetView<RosterComposerController> {
  const ComposerPlaceSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final place = controller.draft.value.place;
      final options = controller.placeOptions.value;
      final loading = controller.placeOptionsLoading.value;
      final err = controller.placeOptionsError.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Place', style: Get.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Where support happens.',
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
              options.participantSites.isEmpty)
            const Text(
              'Add a place',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ..._branchTiles(options, place),
          ..._siteTiles(options, place),
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
            b.location ?? 'Centre',
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
          title: Text(s.name),
          subtitle: Text(
            s.clientName,
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
