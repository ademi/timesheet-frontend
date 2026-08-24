import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/invoice_export_detail_controller.dart';
import '../controllers/invoice_exports_controller.dart';
import '../data/models/billing_models.dart';

String _fmtDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

String _fmtDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

String _fmtMoney(double amount, String currency) =>
    '$currency ${amount.toStringAsFixed(2)}';

class InvoiceExportDetailView extends GetView<InvoiceExportDetailController> {
  const InvoiceExportDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Export detail')),
      body: Obx(() {
        final export = controller.selected.value;
        final err = controller.errorMessage.value;
        if (export == null) {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Center(child: Text(err ?? 'Export not loaded.'));
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageContent(
                width: PageContentWidth.narrow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (err != null) ...[
                      _ErrorBox(err),
                      const SizedBox(height: 12),
                    ],
                    _SummaryHeader(export: export),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AsyncOutlinedButton(
                          onPressed: controller.downloadCsv,
                          isLoading: controller.isDownloadingCsv.value,
                          child: const Text('Download CSV'),
                        ),
                        if (controller.canVoid)
                          AsyncOutlinedButton(
                            onPressed: () =>
                                controller.confirmAndVoidExport(context),
                            isLoading: controller.isVoiding.value,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                            ),
                            child: const Text('Void export'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Lines (${export.lines.length})',
                      style: Get.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    if (export.lines.isEmpty)
                      const Text(
                        'No line items on this export.',
                        style: TextStyle(color: AppColors.textMuted),
                      )
                    else
                      for (final line in export.lines)
                        _ExportLineTile(
                          line: line,
                          currency: export.currencyCode,
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
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.export});
  final InvoiceExportOut export;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          invoiceExportStatusLabel(export.status),
          style: Get.textTheme.titleMedium?.copyWith(
            color: export.isVoid ? AppColors.textMuted : null,
          ),
        ),
        const SizedBox(height: 8),
        Text('Lines: ${export.lineCount}'),
        Text(
          'Total: ${_fmtMoney(export.totalAmount, export.currencyCode)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text('Created: ${_fmtDateTime(export.createdAt)}'),
        if (export.finalizedAt != null)
          Text('Finalized: ${_fmtDateTime(export.finalizedAt!)}'),
      ],
    );
  }
}

class _ExportLineTile extends StatelessWidget {
  const _ExportLineTile({
    required this.line,
    required this.currency,
  });

  final InvoiceExportLineOut line;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ndis = line.participantNdisNumber?.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.clientName ?? 'Client',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (ndis != null && ndis.isNotEmpty)
              Text(
                'NDIS: $ndis',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            const SizedBox(height: 4),
            Text(
              line.supportItemNumber,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            Text(line.supportItemName),
            const SizedBox(height: 8),
            Text('Service date: ${_fmtDate(line.serviceDate)}'),
            Text(
              'Tier: ${PriceTier.labelForOverride(line.priceTier)}',
            ),
            const SizedBox(height: 4),
            Text(
              '${line.quantity.toStringAsFixed(2)} ${line.unit} '
              '@ ${_fmtMoney(line.unitPrice, currency)} '
              '= ${_fmtMoney(line.lineAmount, currency)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
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
