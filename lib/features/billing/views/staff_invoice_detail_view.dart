import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/permission_gate.dart';
import '../controllers/staff_invoices_controller.dart';
import '../data/models/invoice_export_models.dart';

class StaffInvoiceDetailView extends GetView<StaffInvoicesController> {
  const StaffInvoiceDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invoice Export'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.refreshSelectedExport,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Obx(() {
        final export = controller.selectedExport.value;
        final error = controller.detailError.value;
        if (controller.isLoadingDetail.value && export == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (export == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(error ?? 'Export not found'),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshSelectedExport,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              PageContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.isLoadingDetail.value)
                      const LinearProgressIndicator(minHeight: 2),
                    if (error != null) ...[
                      _DetailError(message: error),
                      const SizedBox(height: 12),
                    ],
                    _ExportSummary(export: export),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PermissionGate(
                          permission: AppPermissions.billingView,
                          child: AsyncOutlinedButton(
                            onPressed: controller.downloadSelectedCsv,
                            isLoading: controller.isDownloading.value,
                            child: const Text('Download CSV'),
                          ),
                        ),
                        if (!export.isVoided)
                          PermissionGate(
                            permission: AppPermissions.billingManage,
                            child: AsyncElevatedButton(
                              onPressed: () => _confirmVoid(context),
                              isLoading: controller.isVoiding.value,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Void export'),
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 32),
                    Text('Claim lines', style: Get.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (export.lines.isEmpty)
                      const Text('No claim lines.')
                    else
                      for (final entry in _groupLines(export.lines).entries)
                        _LineGroup(
                          label: entry.key,
                          lines: entry.value,
                          currencyCode: export.currencyCode,
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _confirmVoid(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Void invoice export?'),
            content: const Text(
              'This marks the export as voided. The exported claim lines remain '
              'available for audit.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Void export'),
              ),
            ],
          ),
    );
    if (confirmed == true) await controller.voidSelectedExport();
  }
}

class _ExportSummary extends StatelessWidget {
  const _ExportSummary({required this.export});

  final InvoiceExportOut export;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${export.totalAmount.toStringAsFixed(2)} '
                  '${export.currencyCode}',
                  style: Get.textTheme.headlineSmall,
                ),
                Chip(
                  label: Text(export.status.toUpperCase()),
                  backgroundColor:
                      export.isVoided
                          ? AppColors.errorBackground
                          : AppColors.surface,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${export.lineCount} claim lines'),
            Text('Created ${_dateTime(export.createdAt)}'),
            if (export.finalizedAt != null)
              Text('Finalized ${_dateTime(export.finalizedAt!)}'),
            const SizedBox(height: 4),
            SelectableText(export.id, style: Get.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _LineGroup extends StatelessWidget {
  const _LineGroup({
    required this.label,
    required this.lines,
    required this.currencyCode,
  });

  final String label;
  final List<InvoiceExportLineOut> lines;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final total = lines.fold<double>(0, (sum, line) => sum + line.lineAmount);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(label),
        subtitle: Text(
          '${lines.length} lines · ${total.toStringAsFixed(2)} $currencyCode',
        ),
        children: [
          for (final line in lines)
            ListTile(
              title: Text(line.supportItemName),
              subtitle: Text(
                '${line.supportItemNumber} · ${_date(line.serviceDate)}\n'
                '${line.quantity} ${line.unit} × '
                '${line.unitPrice.toStringAsFixed(2)}',
              ),
              isThreeLine: true,
              trailing: Text(
                '${line.lineAmount.toStringAsFixed(2)} $currencyCode',
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

Map<String, List<InvoiceExportLineOut>> _groupLines(
  List<InvoiceExportLineOut> lines,
) {
  final groups = <String, List<InvoiceExportLineOut>>{};
  for (final line in lines) {
    final clientName = line.clientName?.trim();
    final label =
        clientName != null && clientName.isNotEmpty
            ? clientName
            : line.shiftParticipantId == null
            ? 'Unassigned participant'
            : 'Participant ${line.shiftParticipantId}';
    groups.putIfAbsent(label, () => <InvoiceExportLineOut>[]).add(line);
  }
  return groups;
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${_date(local)} ${two(local.hour)}:${two(local.minute)}';
}

String _date(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)}';
}
