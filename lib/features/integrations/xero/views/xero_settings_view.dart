import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/responsive/page_content.dart';
import '../../../../shared/utils/visit_datetime_format.dart';
import '../controllers/xero_settings_controller.dart';
import '../data/models/xero_models.dart';

/// Settings → Integrations → Xero (connect / status / disconnect).
class XeroSettingsView extends GetView<XeroSettingsController> {
  const XeroSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Xero')),
      body: Obx(() {
        final loading = controller.isLoading.value;
        final st = controller.status.value;
        final err = controller.errorMessage.value;

        if (loading && st == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return PageContent(
          width: PageContentWidth.narrow,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Integrations', style: Get.textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Connect Xero to optionally send posted payment batches as '
                'draft timesheets. Hours stay in Rostiq until you choose '
                'Send to Xero. Finish pay runs in Xero.',
                style: TextStyle(fontSize: 13),
              ),
              if (err != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(err, style: const TextStyle(color: AppColors.error)),
                ),
              ],
              const SizedBox(height: 24),
              Text('Connection', style: Get.textTheme.titleSmall),
              const SizedBox(height: 12),
              if (st != null && !st.featureEnabled)
                const Text(
                  'Xero integration is turned off for this environment.',
                  style: TextStyle(fontSize: 13),
                )
              else ...[
                _ConnectionPanel(status: st),
                const SizedBox(height: 16),
                if (controller.isConnected)
                  OutlinedButton(
                    onPressed:
                        controller.isDisconnecting.value
                            ? null
                            : controller.disconnect,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child:
                        controller.isDisconnecting.value
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Disconnect'),
                  )
                else
                  FilledButton(
                    onPressed:
                        !controller.canManageXero ||
                                controller.isConnecting.value
                            ? null
                            : controller.connect,
                    child:
                        controller.isConnecting.value
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Connect Xero'),
                  ),
                if (controller.isConnected) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        controller.isLoading.value
                            ? null
                            : controller.loadStatus,
                    child: const Text('Refresh status'),
                  ),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _ConnectionPanel extends StatelessWidget {
  const _ConnectionPanel({required this.status});

  final XeroConnectionStatus? status;

  @override
  Widget build(BuildContext context) {
    final connected = status?.connected ?? false;
    final org = status?.orgName?.trim();
    final at = status?.connectedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            connected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              connected
                  ? AppColors.primary.withValues(alpha: 0.25)
                  : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.check_circle_outline : Icons.link_off,
                color: connected ? AppColors.success : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                connected ? 'Connected' : 'Not connected',
                style: Get.textTheme.titleSmall,
              ),
            ],
          ),
          if (connected) ...[
            const SizedBox(height: 8),
            Text(
              (org != null && org.isNotEmpty) ? org : 'Xero organisation',
              style: const TextStyle(fontSize: 14),
            ),
            if (at != null) ...[
              const SizedBox(height: 4),
              Text(
                'Connected ${formatVisitDateTime(at)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
            if (status?.mappingComplete == false) ...[
              const SizedBox(height: 8),
              const Text(
                'Mapping incomplete — map workers and pay items before '
                'sending batches to Xero.',
                style: TextStyle(fontSize: 13, color: AppColors.openSlot),
              ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Connect your Xero organisation (use Demo Company AU for tests). '
                'Payments stay unchanged until you explicitly Send to Xero.',
                style: TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
