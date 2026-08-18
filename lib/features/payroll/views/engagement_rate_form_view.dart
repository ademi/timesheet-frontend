import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/engagement_rate_bands_controller.dart';

/// Dedicated screen for creating a new engagement payment rate (WF-9).
class EngagementRateFormView extends StatefulWidget {
  const EngagementRateFormView({super.key});

  @override
  State<EngagementRateFormView> createState() => _EngagementRateFormViewState();
}

class _EngagementRateFormViewState extends State<EngagementRateFormView> {
  late final EngagementRateBandsController _controller;
  late final String _engagementId;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<EngagementRateBandsController>();
    final arg = Get.arguments;
    _engagementId =
        arg is String
            ? arg
            : (_controller.engagementId.value ?? '');
    if (_engagementId.isNotEmpty) {
      _controller.loadFor(_engagementId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('New payment rate')),
      body: Obx(() {
        final err = _controller.errorMessage.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              if (err != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    err,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Base rate is required. Evening, night, and weekend bands are '
                'optional.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
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
              _bandField(_controller.eveningRateCtrl, 'Evening (optional)'),
              _bandField(_controller.nightRateCtrl, 'Night (optional)'),
              _bandField(_controller.saturdayRateCtrl, 'Saturday (optional)'),
              _bandField(_controller.sundayRateCtrl, 'Sunday (optional)'),
              _bandField(_controller.phRateCtrl, 'Public holiday (optional)'),
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
              const SizedBox(height: 24),
              AsyncElevatedButton(
                onPressed: () async {
                  await _controller.createRate(popOnSuccess: true);
                },
                isLoading: _controller.isSaving.value,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Save payment rate'),
              ),
                ],
              ),
            ),
          ],
        );
      }),
    );
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
