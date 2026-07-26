import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/staff_visits_controller.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

String _fmtDay(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

class StaffVisitsBoardView extends GetView<StaffVisitsController> {
  const StaffVisitsBoardView({super.key});

  @override
  Widget build(BuildContext context) {
    // Re-apply job_id when navigating here while controller already exists.
    controller.applyRouteArgs();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Visits'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final start = controller.rangeStart.value;
        final end = start.add(const Duration(days: 6));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => controller.shiftRange(-7),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '${_fmtDay(start)} – ${_fmtDay(end)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        onPressed: () => controller.shiftRange(7),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  TextField(
                    controller: controller.jobIdCtrl,
                    decoration: InputDecoration(
                      labelText: 'Filter job_id (optional)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: controller.applyFilters,
                      ),
                    ),
                    onSubmitted: (_) => controller.applyFilters(),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: controller.statusFilter.value.isEmpty
                        ? null
                        : controller.statusFilter.value,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All statuses')),
                      DropdownMenuItem(
                        value: 'scheduled',
                        child: Text('scheduled'),
                      ),
                      DropdownMenuItem(
                        value: 'checked_in',
                        child: Text('checked_in'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('completed'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('cancelled'),
                      ),
                    ],
                    onChanged: controller.setStatusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: _ErrorBox(err),
              ),
            Expanded(
              child: controller.isLoading.value && controller.visits.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: controller.load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: controller.visits.isEmpty
                            ? 1
                            : controller.visits.length,
                        itemBuilder: (context, i) {
                          if (controller.visits.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text('No visits in this range.'),
                            );
                          }
                          final v = controller.visits[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(v.jobTitle ?? 'Job ${v.jobId}'),
                              subtitle: Text(
                                '${_fmt(v.scheduledStart)} · ${v.status}'
                                '${v.contractorName != null ? ' · ${v.contractorName}' : ''}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => controller.openDetail(v),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      }),
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
