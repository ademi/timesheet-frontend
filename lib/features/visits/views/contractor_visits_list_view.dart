import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/contractor_visits_controller.dart';

String _fmt(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}

class ContractorVisitsListView extends GetView<ContractorVisitsController> {
  const ContractorVisitsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Visits'),
        actions: shellAppBarActions(),
      ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final showOpenTab = controller.canClaimShifts;
        return Column(
          children: [
            if (showOpenTab)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: PageContent(
                  child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mine', label: Text('Mine')),
                    ButtonSegment(value: 'open', label: Text('Open')),
                  ],
                  selected: {controller.selectedTab.value},
                  onSelectionChanged: (values) {
                    controller.selectTab(values.first);
                  },
                ),
                ),
              ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: PageContent(child: _ErrorBox(err)),
              ),
            Expanded(
              child:
                  controller.isLoading.value &&
                          (controller.selectedTab.value == 'open'
                              ? controller.openShifts.isEmpty
                              : controller.visits.isEmpty)
                      ? const Center(child: CircularProgressIndicator())
                      : controller.selectedTab.value == 'open'
                      ? _OpenShiftsList(controller: controller)
                      : _MineVisitsList(controller: controller),
            ),
          ],
        );
      }),
    );
  }
}

class _MineVisitsList extends StatelessWidget {
  const _MineVisitsList({required this.controller});
  final ContractorVisitsController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          if (controller.isWeb)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Check-in / complete require the mobile app with location enabled.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          if (controller.visits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No upcoming visits.'),
            ),
          for (final v in controller.visits)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(v.jobTitle ?? v.tenantName ?? 'Visit'),
                subtitle: Text('${_fmt(v.scheduledStart)} · ${v.status}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => controller.openDetail(v),
              ),
            ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenShiftsList extends StatelessWidget {
  const _OpenShiftsList({required this.controller});
  final ContractorVisitsController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.loadOpenShifts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          if (controller.openShifts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No open shifts available.'),
            ),
          for (final shift in controller.openShifts)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: AppColors.openSlotBackground,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shift.jobTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (shift.clientName?.isNotEmpty == true)
                      Text(shift.clientName!),
                    Text(
                      '${_fmt(shift.scheduledStart)}'
                      '${shift.suburb != null ? ' · ${shift.suburb}' : ''}',
                    ),
                    Text(
                      '${shift.openSlots} of ${shift.requiredSlots} open',
                      style: const TextStyle(color: AppColors.openSlot),
                    ),
                    const SizedBox(height: 8),
                    AsyncElevatedButton(
                      onPressed: () => controller.claimShift(shift.id),
                      isLoading: controller.isSaving.value,
                      child: const Text('Claim'),
                    ),
                  ],
                ),
              ),
            ),
              ],
            ),
          ),
        ],
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
