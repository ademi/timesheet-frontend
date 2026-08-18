import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/responsive/max_width_box.dart';
import '../controllers/contractor_payments_controller.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

class ContractorPaymentsView extends GetView<ContractorPaymentsController> {
  const ContractorPaymentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My payments'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: MaxWidthBox(
        maxWidth: Breakpoints.narrowContent,
        child: Obx(() {
        final err = controller.errorMessage.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment status comes from your visits '
                    '(no contractor payment-batches list yet).',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Unpaid'),
                        selected: controller.paymentFilter.value == 'unpaid',
                        onSelected: (_) => controller.setFilter('unpaid'),
                      ),
                      ChoiceChip(
                        label: const Text('Paid'),
                        selected: controller.paymentFilter.value == 'paid',
                        onSelected: (_) => controller.setFilter('paid'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
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
              ),
            Expanded(
              child: controller.isLoading.value && controller.visits.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: controller.load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (controller.visits.isEmpty)
                            const Text('No visits for this filter.'),
                          for (final v in controller.visits)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(v.jobTitle ?? v.tenantName ?? 'Visit'),
                                subtitle: Text(
                                  '${_fmt(v.scheduledStart)} · ${v.status} · '
                                  '${v.paymentStatus}',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      }),
      ),
    );
  }
}
