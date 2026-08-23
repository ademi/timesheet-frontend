import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../../visits/data/models/visit_models.dart';
import '../controllers/invoice_exports_controller.dart';
import '../data/models/billing_models.dart';
import '../utils/visit_export_preflight.dart';

String _fmtDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _fmtMoney(double amount, String currency) =>
    '$currency ${amount.toStringAsFixed(2)}';

String _ymd(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class InvoiceExportsListView extends GetView<InvoiceExportsController> {
  const InvoiceExportsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoice exports'),
        actions: shellAppBarActions(),
      ),
      body: Obx(() {
        final tab = controller.tabIndex.value;
        final err = controller.errorMessage.value;
        return Column(
          children: [
            PageContent(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (err != null) ...[
                      _ErrorBox(err),
                      const SizedBox(height: 12),
                    ],
                    if (controller.canManage)
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Exports'),
                            selected: tab == 0,
                            onSelected: (_) => controller.tabIndex.value = 0,
                          ),
                          ChoiceChip(
                            label: const Text('Create export'),
                            selected: tab == 1,
                            onSelected: (_) {
                              controller.tabIndex.value = 1;
                              controller.loadExportableVisits();
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (controller.isLoading.value &&
                (tab == 0
                    ? controller.exports.isEmpty
                    : controller.exportableVisits.isEmpty))
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: tab == 0 || !controller.canManage
                    ? _ExportsTab(controller: controller)
                    : _CreateExportTab(controller: controller),
              ),
          ],
        );
      }),
    );
  }
}

class _ExportsTab extends StatelessWidget {
  const _ExportsTab({required this.controller});
  final InvoiceExportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.exports.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: controller.loadExports,
        child: controller.exports.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 48),
                  Center(
                    child: Text(
                      'No invoice exports yet.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: controller.exports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final export = controller.exports[index];
                  return _ExportTile(
                    export: export,
                    onTap: () => controller.openDetail(export),
                  );
                },
              ),
      );
    });
  }
}

class _CreateExportTab extends StatelessWidget {
  const _CreateExportTab({required this.controller});
  final InvoiceExportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return RefreshIndicator(
        onRefresh: controller.loadExportableVisits,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => controller.pickPeriod(context),
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      'Period: ${_ymd(controller.periodRange.value.start)}'
                      ' – ${_ymd(controller.periodRange.value.end)}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select completed visits to export as NDIS plan-manager CSV lines.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  if (controller.lastVisitErrors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Export issues',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    for (final err in controller.lastVisitErrors)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${err.visitId}: ${err.message}',
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  if (controller.exportableVisits.isEmpty)
                    const Text(
                      'No completed visits in this period.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  for (final visit in controller.exportableVisits)
                    _VisitExportTile(
                      controller: controller,
                      visit: visit,
                    ),
                  const SizedBox(height: 16),
                  AsyncElevatedButton(
                    onPressed: controller.selectedVisitsReady
                        ? controller.createExport
                        : null,
                    isLoading: controller.isSaving.value,
                    child: Text(
                      controller.selectedVisitIds.isEmpty
                          ? 'Create export'
                          : 'Create export (${controller.selectedVisitIds.length})',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _VisitExportTile extends StatelessWidget {
  const _VisitExportTile({
    required this.controller,
    required this.visit,
  });

  final InvoiceExportsController controller;
  final VisitOut visit;

  @override
  Widget build(BuildContext context) {
    final preflight = controller.preflightFor(visit);
    final serverErr = controller.visitErrorFor(visit.id);
    final selected = controller.selectedVisitIds.contains(visit.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Checkbox(
          value: selected,
          onChanged: preflight.isReady
              ? (_) => controller.toggleVisit(visit.id)
              : null,
        ),
        title: Text(visit.jobTitle ?? 'Visit'),
        subtitle: Text(
          '${_fmtDateTime(visit.scheduledStart)}'
          '${visit.contractorName != null ? ' · ${visit.contractorName}' : ''}',
        ),
        children: [
          if (serverErr != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                serverErr.message,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          for (final check in preflight.checks)
            _PreflightRow(check: check),
        ],
      ),
    );
  }
}

class _PreflightRow extends StatelessWidget {
  const _PreflightRow({required this.check});
  final VisitExportCheck check;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (check.status) {
      case VisitExportCheckStatus.ok:
        icon = Icons.check_circle_outline;
        color = AppColors.primary;
      case VisitExportCheckStatus.warn:
        icon = Icons.warning_amber_outlined;
        color = AppColors.textMuted;
      case VisitExportCheckStatus.block:
        icon = Icons.error_outline;
        color = AppColors.error;
    }
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(check.label),
      subtitle: check.detail != null ? Text(check.detail!) : null,
    );
  }
}

class _ExportTile extends StatelessWidget {
  const _ExportTile({required this.export, required this.onTap});

  final InvoiceExportOut export;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(
          invoiceExportStatusLabel(export.status),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: export.isVoid ? AppColors.textMuted : null,
          ),
        ),
        subtitle: Text(
          '${export.lineCount} line${export.lineCount == 1 ? '' : 's'} · '
          '${_fmtMoney(export.totalAmount, export.currencyCode)}\n'
          'Created ${_fmtDateTime(export.createdAt)}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
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
