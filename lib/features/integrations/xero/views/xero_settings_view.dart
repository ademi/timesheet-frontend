import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/responsive/page_content.dart';
import '../../../../shared/utils/humanize_label.dart';
import '../../../../shared/utils/visit_datetime_format.dart';
import '../controllers/xero_settings_controller.dart';
import '../data/models/xero_models.dart';

/// Settings → Integrations → Xero (connect + mapping).
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
                'Optional: connect Xero Payroll to send posted payment batches. '
                'Hours go as drafts; finish pay in Xero. '
                'Without Xero, create → post → void in Payments is unchanged.',
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
                  child: Text(
                    err,
                    style: const TextStyle(color: AppColors.error),
                  ),
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
                        controller.isLoading.value ||
                                controller.isMappingLoading.value
                            ? null
                            : () async {
                              await controller.loadStatus();
                              await controller.loadMappingData();
                            },
                    child: const Text('Refresh status'),
                  ),
                  if (controller.mappingIncomplete) ...[
                    const SizedBox(height: 16),
                    const _MappingIncompleteBanner(),
                  ],
                  const SizedBox(height: 24),
                  Text('Mappings', style: Get.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text(
                    'Map workers and pay bands before Send to Xero. '
                    'Hours go as drafts; finish pay in Xero.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  if (controller.isMappingLoading.value)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    const _MappingTabs(),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _MappingIncompleteBanner extends StatelessWidget {
  const _MappingIncompleteBanner();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<XeroSettingsController>();
    final workers = c.unmappedContractorIds.length;
    final bands = c.unmappedBandKeys.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.openSlot.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Mapping incomplete — $workers worker(s) and $bands pay band(s) still '
        'need a Xero map before you can Send a batch.',
        style: const TextStyle(fontSize: 13, color: AppColors.openSlot),
      ),
    );
  }
}

class _MappingTabs extends StatelessWidget {
  const _MappingTabs();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            tabs: [Tab(text: 'Workers'), Tab(text: 'Pay items')],
          ),
          const SizedBox(height: 12),
          // Fixed height so TabBarView works inside ListView.
          SizedBox(
            height: 420,
            child: TabBarView(
              children: const [_EmployeesMappingTab(), _PayItemsMappingTab()],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeesMappingTab extends GetView<XeroSettingsController> {
  const _EmployeesMappingTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final employees = controller.xeroEmployees;
      final rows = controller.contractorRows;

      if (employees.isEmpty) {
        return _EmptyCatalogue(
          title: 'No Xero employees found',
          body:
              'Create payroll employees in Xero (Demo Company AU for tests), '
              'then refresh.',
          onOpenXero: controller.openXeroInBrowser,
          onRefresh: controller.loadMappingData,
        );
      }

      if (rows.isEmpty) {
        return const Center(
          child: Text(
            'No workers to map yet. Add engagements or create a payment batch first.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final row = rows[i];
                final selected = controller.employeeSelection[row.contractorId];
                final validIds = {for (final e in employees) e.employeeId};
                final value =
                    selected != null && validIds.contains(selected)
                        ? selected
                        : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (row.needsMap)
                          const Text(
                            'Needs map',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.openSlot,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: value,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Xero employee',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Not mapped'),
                        ),
                        ...employees.map(
                          (e) => DropdownMenuItem<String?>(
                            value: e.employeeId,
                            child: Text(
                              e.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged:
                          controller.canManageXero
                              ? (v) => controller.setEmployeeMapping(
                                row.contractorId,
                                v,
                              )
                              : null,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                controller.isSavingEmployees.value
                    ? null
                    : controller.saveEmployeeMappings,
            child:
                controller.isSavingEmployees.value
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Save worker mappings'),
          ),
        ],
      );
    });
  }
}

class _PayItemsMappingTab extends GetView<XeroSettingsController> {
  const _PayItemsMappingTab();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rates = controller.xeroEarningsRates;
      final unmapped = controller.unmappedBandKeys.toSet();

      if (rates.isEmpty) {
        return _EmptyCatalogue(
          title: 'No Xero earnings rates found',
          body:
              'Add earnings rates / pay items in Xero Payroll, then refresh.',
          onOpenXero: controller.openXeroInBrowser,
          onRefresh: controller.loadMappingData,
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView.separated(
              itemCount: XeroBandKeys.all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final band = XeroBandKeys.all[i];
                final selected = controller.payItemSelection[band];
                final validIds = {for (final r in rates) r.earningsRateId};
                final value =
                    selected != null && validIds.contains(selected)
                        ? selected
                        : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            humanizeLabel(band),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (unmapped.contains(band))
                          const Text(
                            'Needs map',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.openSlot,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: value,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Xero earnings rate',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Not mapped'),
                        ),
                        ...rates.map(
                          (r) => DropdownMenuItem<String?>(
                            value: r.earningsRateId,
                            child: Text(
                              r.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged:
                          controller.canManageXero
                              ? (v) =>
                                  controller.setPayItemMapping(band, v)
                              : null,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed:
                controller.isSavingPayItems.value
                    ? null
                    : controller.savePayItemMappings,
            child:
                controller.isSavingPayItems.value
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Save pay-item mappings'),
          ),
        ],
      );
    });
  }
}

class _EmptyCatalogue extends StatelessWidget {
  const _EmptyCatalogue({
    required this.title,
    required this.body,
    required this.onOpenXero,
    required this.onRefresh,
  });

  final String title;
  final String body;
  final Future<void> Function() onOpenXero;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Get.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onOpenXero, child: const Text('Open Xero')),
            TextButton(onPressed: onRefresh, child: const Text('Refresh')),
          ],
        ),
      ),
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
