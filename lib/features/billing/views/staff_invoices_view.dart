import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../../visits/data/models/visit_models.dart';
import '../controllers/staff_invoices_controller.dart';
import '../data/models/invoice_export_models.dart';

class StaffInvoicesView extends GetView<StaffInvoicesController> {
  const StaffInvoicesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: shellAppBarActions(),
      ),
      body: Obx(() {
        final tab = controller.tabIndex.value;
        return Column(
          children: [
            PageContent(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Exports'),
                      selected: tab == 0,
                      onSelected: (_) => controller.tabIndex.value = 0,
                    ),
                    ChoiceChip(
                      label: const Text('Create'),
                      selected: tab == 1,
                      onSelected: (_) => controller.tabIndex.value = 1,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh:
                    tab == 0
                        ? controller.loadExports
                        : controller.loadCompletedVisits,
                child:
                    tab == 0
                        ? _ExportsTab(controller: controller)
                        : _CreateExportTab(controller: controller),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _ExportsTab extends StatelessWidget {
  const _ExportsTab({required this.controller});

  final StaffInvoicesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isLoadingExports.value;
      final error = controller.exportListError.value;
      if (loading && controller.exports.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          PageContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (loading) const LinearProgressIndicator(minHeight: 2),
                if (error != null) ...[
                  _ErrorBox(error),
                  const SizedBox(height: 12),
                ],
                if (controller.exports.isEmpty && error == null)
                  _EmptyExports(onCreate: () => controller.tabIndex.value = 1),
                for (final export in controller.exports)
                  _ExportCard(
                    export: export,
                    onTap: () => controller.openExport(export),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _CreateExportTab extends StatelessWidget {
  const _CreateExportTab({required this.controller});

  final StaffInvoicesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loading = controller.isLoadingVisits.value;
      final error = controller.createError.value;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          PageContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Invoice Export',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a service period, then select completed visits to '
                  'include in the claim export.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      loading ? null : () => controller.pickPeriod(context),
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(_formatRange(controller.periodRange.value)),
                ),
                if (loading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBox(error),
                ],
                const SizedBox(height: 12),
                if (loading && controller.completedVisits.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (controller.completedVisits.isEmpty && error == null)
                  const Text('No completed visits in this period.')
                else ...[
                  Text(
                    '${controller.selectedVisitIds.length} of '
                    '${controller.completedVisits.length} visits selected',
                    style: Get.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final visit in controller.completedVisits)
                    _VisitCard(
                      visit: visit,
                      selected: controller.selectedVisitIds.contains(visit.id),
                      enabled:
                          controller.canManage && !controller.isSaving.value,
                      onChanged: () => controller.toggleVisit(visit.id),
                    ),
                ],
                PermissionGate(
                  permission: AppPermissions.billingManage,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AsyncElevatedButton(
                      onPressed:
                          controller.selectedVisitIds.isEmpty
                              ? null
                              : controller.createExport,
                      isLoading: controller.isSaving.value,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Create export'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({required this.export, required this.onTap});

  final InvoiceExportOut export;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          '${export.totalAmount.toStringAsFixed(2)} ${export.currencyCode}',
        ),
        subtitle: Text(
          '${export.status} · ${export.lineCount} claim lines\n'
          '${_formatDateTime(export.createdAt)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final VisitOut visit;
  final bool selected;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final title =
        visit.jobTitle?.trim().isNotEmpty == true
            ? visit.jobTitle!.trim()
            : 'Visit ${visit.id}';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: selected,
        onChanged: enabled ? (_) => onChanged() : null,
        title: Text(title),
        subtitle: Text(
          '${_formatDateTime(visit.scheduledStart)} · '
          '${visit.scheduledEnd.difference(visit.scheduledStart).inMinutes / 60} hours',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}

class _EmptyExports extends StatelessWidget {
  const _EmptyExports({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No invoice exports yet. Create one from completed visits.'),
        PermissionGate(
          permission: AppPermissions.billingManage,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create export'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

String _formatRange(DateTimeRange range) =>
    '${_ymd(range.start)} → ${_ymd(range.end)}';

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${_ymd(local)} ${two(local.hour)}:${two(local.minute)}';
}

String _ymd(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
