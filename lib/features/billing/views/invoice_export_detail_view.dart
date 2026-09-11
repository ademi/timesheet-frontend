import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/invoice_export_detail_controller.dart';
import '../data/models/billing_models.dart';
import '../widgets/billing_ui.dart';

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
                    if (controller.isLoading.value)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    if (err != null) ...[
                      BillingErrorBox(err),
                      const SizedBox(height: 12),
                    ],
                    _SummaryHeader(export: export),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AsyncElevatedButton(
                          onPressed: controller.downloadCsv,
                          isLoading: controller.isDownloadingCsv.value,
                          child: const Text('Download CSV'),
                        ),
                        if (controller.canVoid)
                          AsyncOutlinedButton(
                            onPressed:
                                () => controller.confirmAndVoidExport(context),
                            isLoading: controller.isVoiding.value,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: billingPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InvoiceExportStatusPill(status: export.status),
          const SizedBox(height: 10),
          Text(
            billingFmtMoney(export.totalAmount, export.currencyCode),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${export.lineCount} line${export.lineCount == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Created ${billingFmtDateTime(export.createdAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          if (export.finalizedAt != null)
            Text(
              'Finalized ${billingFmtDateTime(export.finalizedAt!)}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _ExportLineTile extends StatelessWidget {
  const _ExportLineTile({required this.line, required this.currency});

  final InvoiceExportLineOut line;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final ndis = line.participantNdisNumber?.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: billingPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  line.clientName ?? 'Client',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                billingFmtMoney(line.lineAmount, currency),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (line.shiftParticipantId != null) ...[
            const SizedBox(height: 2),
            const Text(
              'Group share',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            [
              if (ndis != null && ndis.isNotEmpty) 'NDIS $ndis',
              line.supportItemNumber,
              PriceTier.labelForOverride(line.priceTier),
              billingFmtDate(line.serviceDate),
            ].join(' · '),
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            line.supportItemName,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '${line.quantity.toStringAsFixed(2)} ${line.unit} @ '
            '${billingFmtMoney(line.unitPrice, currency)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
