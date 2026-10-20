import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

/// Which Invoice exports segment the (i) sheet describes.
enum BillingTabInfo {
  exports,
  create,
  ageing90d,
  burn,
  pe,
  ar;

  String get shortLabel => switch (this) {
    BillingTabInfo.exports => 'Exports',
    BillingTabInfo.create => 'Create',
    BillingTabInfo.ageing90d => '90d',
    BillingTabInfo.burn => 'Burn',
    BillingTabInfo.pe => 'PE',
    BillingTabInfo.ar => 'AR',
  };
}

class _BillingTabInfoCopy {
  const _BillingTabInfoCopy({
    required this.title,
    required this.question,
    required this.purpose,
    required this.youCan,
    required this.notThis,
  });

  final String title;
  final String question;
  final String purpose;
  final String youCan;
  final String notThis;
}

_BillingTabInfoCopy _copyFor(BillingTabInfo tab) {
  switch (tab) {
    case BillingTabInfo.exports:
      return const _BillingTabInfoCopy(
        title: 'Exports',
        question: 'What exports already exist?',
        purpose:
            'History of invoice exports — download CSV, open a batch, or void '
            'when something was exported in error.',
        youCan:
            'Browse past exports, open detail, download CSV, and void when you '
            'have billing manage permission.',
        notThis:
            'Not where you pick visits to claim (that’s Create), and not the '
            '90d / Burn / PE / AR risk queues.',
      );
    case BillingTabInfo.create:
      return const _BillingTabInfoCopy(
        title: 'Create',
        question: 'Which visits should go on a new export?',
        purpose:
            'Pick completed visits and create a new NDIS plan-manager CSV '
            'export batch.',
        youCan:
            'Filter by host, participant, job, and period; select ready visits; '
            'fix coding on a visit; create the export.',
        notThis:
            'Not ageing or cash collection. Visits already exported won’t appear '
            'here — use Exports (void) or pick other visits.',
      );
    case BillingTabInfo.ageing90d:
      return const _BillingTabInfoCopy(
        title: '90d',
        question:
            'Which completed visits still need exporting before we lose the '
            'claim window?',
        purpose:
            'Completed visits that are not yet on an invoice export — work '
            'done, but not yet lodged as a claim. From Dec 2026, claims '
            'generally must be lodged within about 90 days of delivery.',
        youCan:
            'Scan risk bands (watch ≥60d, high ≥75d, critical ≥90d), filter to '
            'approaching 90 days or by client, open Fix on visit, or jump to '
            'Create via Export.',
        notThis:
            'Not money overdue from a plan manager (AR), not a payment enquiry '
            '(PE), and not budget remaining (Burn).',
      );
    case BillingTabInfo.burn:
      return const _BillingTabInfoCopy(
        title: 'Burn',
        question:
            'Who is running low on plan budget for this category?',
        purpose:
            'Budget / envelope warnings from declared budgets vs spend on the '
            'exported invoice ledger (your internal picture — not a live NDIA '
            'portal balance).',
        youCan:
            'Monitor soft warn and hard block alerts before a big Create export '
            'batch. Decide whether to pause exports, talk to the plan manager, '
            'or adjust rostering. This tab is read-only.',
        notThis:
            'Not visits waiting to be exported (90d), and not unpaid invoices '
            '(AR).',
      );
    case BillingTabInfo.pe:
      return const _BillingTabInfoCopy(
        title: 'PE',
        question: 'Which payment enquiries are open and ageing?',
        purpose:
            'Payment Enquiries — formal follow-ups / disputes in the NDIS '
            'payment process (lodged with NDIA / plan manager). Ageing bands '
            'are 14 / 30 / 60 days.',
        youCan:
            'View and refresh the PE register (client, status, days open, risk '
            'band, amount, notes). Operational chase usually happens outside '
            'this screen.',
        notThis:
            'Not the 5-day / 7-day / 14-day AR SLA on finalized exports, and '
            'not the 90-day claim window for unexported visits.',
      );
    case BillingTabInfo.ar:
      return const _BillingTabInfoCopy(
        title: 'AR',
        question: 'Which finalized invoices haven’t been paid?',
        purpose:
            'Accounts receivable — finalized invoice exports that are still '
            'unpaid. Counts from export finalized. SLA: watch ≥5d, high ≥7d, '
            'critical ≥14d.',
        youCan:
            'Filter by management type, set delay reasons (plan manager queue, '
            'participant hold, NDIA review, PE, rejected), and mark paid when '
            'remittance confirms (billing manage).',
        notThis:
            'Not visits you forgot to export (90d), and not the PE register — '
            'though you can tag AR with delay reason PE if payment is stuck on '
            'an enquiry.',
      );
  }
}

/// Bottom sheet explaining what a billing tower / exports tab is for.
Future<void> showBillingTabInfoSheet(
  BuildContext context, {
  required BillingTabInfo tab,
}) {
  final copy = _copyFor(tab);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy.title,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                copy.question,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _InfoBlock(
                label: 'Purpose',
                body: copy.purpose,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _InfoBlock(
                label: 'What you can do',
                body: copy.youCan,
                color: AppColors.dark,
              ),
              const SizedBox(height: 12),
              _InfoBlock(
                label: 'What this is not',
                body: copy.notThis,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.label,
    required this.body,
    required this.color,
  });

  final String label;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
