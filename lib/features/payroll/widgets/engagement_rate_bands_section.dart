import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/engagement_rate_bands_controller.dart';

/// Payment rate list + new payment rate form for a fixed engagement.
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
            const Divider(height: 32),
            Text('New payment rate', style: Get.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _controller.effectiveFromCtrl,
              decoration: const InputDecoration(
                labelText: 'Effective from (YYYY-MM-DD)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller.baseRateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Base *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            _bandField(_controller.eveningRateCtrl, 'Evening'),
            _bandField(_controller.nightRateCtrl, 'Night'),
            _bandField(_controller.saturdayRateCtrl, 'Saturday'),
            _bandField(_controller.sundayRateCtrl, 'Sunday'),
            _bandField(_controller.phRateCtrl, 'Public holiday'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller.eveningStartCtrl,
              decoration: const InputDecoration(
                labelText: 'Evening start',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller.eveningEndCtrl,
              decoration: const InputDecoration(
                labelText: 'Evening end',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller.nightStartCtrl,
              decoration: const InputDecoration(
                labelText: 'Night start',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller.nightEndCtrl,
              decoration: const InputDecoration(
                labelText: 'Night end',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            AsyncElevatedButton(
              onPressed: _controller.createRate,
              isLoading: _controller.isSaving.value,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Save payment rates'),
            ),
          ],
        ],
      );
    });
  }

  Widget _bandField(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
