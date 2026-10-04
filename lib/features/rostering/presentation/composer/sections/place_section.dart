import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../../app/themes/app_colors.dart';
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
              'Ad-hoc labelled place',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            trailing: Icon(
              otherSelected ? Icons.check_circle : Icons.circle_outlined,
              color: otherSelected ? AppColors.brand : AppColors.slate400,
            ),
            onTap: () {
              if (place is! ShiftPlaceLabelled) {
                controller.setPlace(
                  const ShiftPlaceIn.labelled(
                    label: '',
                    latitude: -33.8688,
                    longitude: 151.2093,
                    postalCode: '',
                  ),
                );
              }
            },
          ),
          if (otherSelected) ...[
            const SizedBox(height: 8),
            _OtherPlaceFields(place: place),
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
            '${s.clientName} · participant site',
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
  const _OtherPlaceFields({required this.place});

  final ShiftPlaceLabelled place;

  @override
  State<_OtherPlaceFields> createState() => _OtherPlaceFieldsState();
}

class _OtherPlaceFieldsState extends State<_OtherPlaceFields> {
  late final TextEditingController _label;
  late final TextEditingController _postal;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  final controller = Get.find<RosterComposerController>();

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.place.label);
    _postal = TextEditingController(text: widget.place.postalCode);
    _lat = TextEditingController(text: widget.place.latitude.toString());
    _lng = TextEditingController(text: widget.place.longitude.toString());
  }

  @override
  void didUpdateWidget(covariant _OtherPlaceFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place.label != widget.place.label &&
        _label.text != widget.place.label) {
      _label.text = widget.place.label;
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _postal.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  void _commit() {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) return;
    controller.setPlace(
      ShiftPlaceIn.labelled(
        label: _label.text.trim(),
        latitude: lat,
        longitude: lng,
        postalCode: _postal.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _label,
          decoration: const InputDecoration(
            labelText: 'Label',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _commit(),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _postal,
          decoration: const InputDecoration(
            labelText: 'Postal code',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => _commit(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _lat,
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                ],
                onChanged: (_) => _commit(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lng,
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                ],
                onChanged: (_) => _commit(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
