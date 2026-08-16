import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/engagement_rate_bands_controller.dart';

/// Payment rate list for a fixed engagement. Create form lives on a separate
/// screen (WF-9).
class EngagementRateBandsSection extends StatefulWidget {
  const EngagementRateBandsSection({
    super.key,
    required this.engagementId,
  });

  final String engagementId;

  @override
  State<EngagementRateBandsSection> createState() =>
      _EngagementRateBandsSectionState();
}

class _EngagementRateBandsSectionState
    extends State<EngagementRateBandsSection> {
  late final EngagementRateBandsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<EngagementRateBandsController>();
    _controller.loadFor(widget.engagementId);
  }

  @override
  void didUpdateWidget(covariant EngagementRateBandsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engagementId != widget.engagementId) {
      _controller.loadFor(widget.engagementId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!_controller.canView) {
        return const Text(
          'No permission to view payment rates (payments.view).',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        );
      }

      final err = _controller.errorMessage.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (err != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(err, style: const TextStyle(color: AppColors.error)),
            ),
            const SizedBox(height: 12),
          ],
          if (_controller.isLoading.value && _controller.rates.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_controller.rates.isEmpty)
            const Text(
              'No rates yet for this engagement.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          for (final r in _controller.rates)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('Base ${r.displayBase} ${r.currencyCode}'),
                subtitle: Text(
                  '${r.effectiveFrom} → ${r.effectiveTo ?? 'open'}'
                  '${r.bands.evening != null ? ' · eve ${r.bands.evening}' : ''}'
                  '${r.bands.night != null ? ' · night ${r.bands.night}' : ''}',
                ),
              ),
            ),
          if (_controller.canManage) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed:
                  () => Get.toNamed(
                    AppRoutes.staffWorkforceRateForm,
                    arguments: widget.engagementId,
                  ),
              icon: const Icon(Icons.add),
              label: const Text('New payment rate'),
            ),
          ],
        ],
      );
    });
  }
}
