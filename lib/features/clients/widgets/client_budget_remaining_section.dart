import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/models/budget_summary_models.dart';

class ClientBudgetRemainingSection extends StatelessWidget {
  const ClientBudgetRemainingSection({
    super.key,
    required this.summary,
    this.isLoading = false,
  });

  final BudgetSummaryOut? summary;
  final bool isLoading;

  static const _labels = <String, String>{
    'core': 'Core',
    'capacity_building': 'Capacity building',
    'capital': 'Capital',
    'other': 'Other',
  };

  @override
  Widget build(BuildContext context) {
    if (summary == null && !isLoading) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Budget remaining',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (isLoading && summary == null)
          const LinearProgressIndicator(minHeight: 2)
        else
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.45),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                children: [
                  _BudgetCell('Envelope', isHeader: true),
                  _BudgetCell('Declared', isHeader: true, alignEnd: true),
                  _BudgetCell('Spent', isHeader: true, alignEnd: true),
                  _BudgetCell('Remaining', isHeader: true, alignEnd: true),
                ],
              ),
              for (final envelope in summary!.envelopes)
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  children: [
                    _BudgetCell(_labels[envelope.key] ?? envelope.key),
                    _BudgetCell(_money(envelope.declared), alignEnd: true),
                    _BudgetCell(_money(envelope.spent), alignEnd: true),
                    _BudgetCell(
                      _money(envelope.remaining),
                      alignEnd: true,
                      isNegative:
                          envelope.remaining != null && envelope.remaining! < 0,
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }

  static String _money(double? value) {
    if (value == null) return '—';
    if (value < 0) return '-\$${(-value).toStringAsFixed(2)}';
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _BudgetCell extends StatelessWidget {
  const _BudgetCell(
    this.text, {
    this.isHeader = false,
    this.alignEnd = false,
    this.isNegative = false,
  });

  final String text;
  final bool isHeader;
  final bool alignEnd;
  final bool isNegative;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
      child: Text(
        text,
        textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          color:
              isNegative
                  ? AppColors.openSlot
                  : (isHeader ? AppColors.textMuted : AppColors.textDark),
        ),
      ),
    );
  }
}
