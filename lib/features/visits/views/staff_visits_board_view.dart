import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
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

class StaffVisitsBoardView extends StatefulWidget {
  const StaffVisitsBoardView({super.key});

  @override
  State<StaffVisitsBoardView> createState() => _StaffVisitsBoardViewState();
}

class _StaffVisitsBoardViewState extends State<StaffVisitsBoardView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<StaffVisitsController>();
    c.applyRouteArgs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.ensureBoardLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffVisitsController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Visits'),
        actions: shellAppBarActions(),
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
                  DropdownButtonFormField<String>(
                    value:
                        controller.jobIdFilter.value.isEmpty
                            ? null
                            : controller.jobIdFilter.value,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All jobs'),
                      ),
                      for (final job in controller.jobs)
                        DropdownMenuItem(value: job.id, child: Text(job.title)),
                    ],
                    onChanged: controller.setJobFilter,
                    decoration: const InputDecoration(
                      labelText: 'Job',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value:
                        controller.statusFilter.value.isEmpty
                            ? null
                            : controller.statusFilter.value,
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('All statuses'),
                      ),
                      DropdownMenuItem(
                        value: 'scheduled',
                        child: Text('Scheduled'),
                      ),
                      DropdownMenuItem(
                        value: 'checked_in',
                        child: Text('Checked in'),
                      ),
                      DropdownMenuItem(
                        value: 'completed',
                        child: Text('Completed'),
                      ),
                      DropdownMenuItem(
                        value: 'cancelled',
                        child: Text('Cancelled'),
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
              Padding(padding: const EdgeInsets.all(16), child: _ErrorBox(err)),
            Expanded(
              child:
                  controller.isLoading.value && controller.visits.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                        onRefresh: controller.load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount:
                              controller.visits.isEmpty
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
                                title: Text(v.jobTitle ?? 'Visit'),
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
