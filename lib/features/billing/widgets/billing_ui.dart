import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/invoice_exports_controller.dart';

String billingFmtDateTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String billingFmtDate(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

String billingFmtMoney(double amount, String currency) =>
    '$currency ${amount.toStringAsFixed(2)}';

String billingFmtYmd(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Status pill for finalized / void exports.
class InvoiceExportStatusPill extends StatelessWidget {
  const InvoiceExportStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final voided = status == 'void';
    final label = invoiceExportStatusLabel(status);
    return Semantics(
      label: 'Export status $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:
              voided
                  ? AppColors.primaryLight
                  : AppColors.dark.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: voided ? AppColors.textMuted : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class BillingErrorBox extends StatelessWidget {
  const BillingErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.25),
          ),
        ),
        child: Text(message, style: const TextStyle(color: AppColors.error)),
      ),
    );
  }
}

/// Border-only panel (no elevation) for interactive billing rows.
BoxDecoration billingPanelDecoration() => BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: AppColors.divider),
);
