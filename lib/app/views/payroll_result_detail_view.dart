import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/models/payroll/result_out.dart';
import '../routes/app_routes.dart';
import '../routes/route_args.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/responsive/max_width_box.dart';

class PayrollResultDetailView extends StatelessWidget {
  const PayrollResultDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments;
    if (args is! PayrollResultDetailArgs) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Payroll Result'),
          backgroundColor: AppColors.darkBrown,
        ),
        body: Center(
          child: TextButton(
            onPressed: Get.back,
            child: const Text('Go back'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackRoute: AppRoutes.payrollPeriodResults,
        ),
        title: Text(args.result.employeeName ?? 'Payroll Result'),
        backgroundColor: AppColors.darkBrown,
      ),
      body: MaxWidthBox(
        maxWidth: Breakpoints.maxContent,
        child: PayrollResultDetailContent(result: args.result),
      ),
    );
  }
}

class PayrollResultDetailContent extends StatelessWidget {
  const PayrollResultDetailContent({super.key, required this.result});

  final ResultOut result;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SummaryCard(result: result),
        const SizedBox(height: 16),
        _SnapshotSection(
          title: 'Rate Snapshot',
          entries: result.rateSnapshot.entries,
        ),
        const SizedBox(height: 16),
        _SnapshotSection(
          title: 'Calc Snapshot',
          entries: result.calcSnapshot.entries,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result});

  final ResultOut result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result.employeeName ?? result.employeeId,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _row('Regular (mins)', '${result.regularMinutes}'),
            _row('Overtime (mins)', '${result.overtimeMinutes}'),
            _row('Night (mins)', '${result.nightMinutes}'),
            _row('Weekend (mins)', '${result.weekendMinutes}'),
            _row('Amount due', result.amountDue.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SnapshotSection extends StatelessWidget {
  const _SnapshotSection({
    required this.title,
    required this.entries,
  });

  final String title;
  final Iterable<MapEntry<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${e.key}: ${e.value}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
