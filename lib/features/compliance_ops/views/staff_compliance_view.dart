import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../subscription/billing_gate.dart';
import '../controllers/staff_compliance_controller.dart';

class StaffComplianceView extends GetView<StaffComplianceController> {
  const StaffComplianceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Compliance'),
        actions: [
          if (controller.canReviewCreds)
            TextButton(
              onPressed: () => Get.toNamed(AppRoutes.staffCredentialReview),
              child: const Text('Credential review'),
            ),
        ],
      ),
      body: Obx(() {
        final tab = controller.tabIndex.value;
        final err = controller.errorMessage.value;
        return Column(
          children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: _ErrorBox(err),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: [
                  if (controller.canRights)
                    ChoiceChip(
                      label: const Text('Rights'),
                      selected: tab == 0,
                      onSelected: (_) => controller.tabIndex.value = 0,
                    ),
                  if (controller.canAudit)
                    ChoiceChip(
                      label: const Text('Access history'),
                      selected: tab == 1,
                      onSelected: (_) => controller.tabIndex.value = 1,
                    ),
                  if (controller.canIncidents)
                    ChoiceChip(
                      label: const Text('Incidents'),
                      selected: tab == 2,
                      onSelected: (_) => controller.tabIndex.value = 2,
                    ),
                  ChoiceChip(
                    label: const Text('Alerts'),
                    selected: tab == 3,
                    onSelected: (_) => controller.tabIndex.value = 3,
                  ),
                ],
              ),
            ),
            Expanded(
              child: controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: controller.load,
                      child: tab == 0
                          ? _RightsTab(controller: controller)
                          : tab == 1
                              ? _AccessTab(controller: controller)
                              : tab == 2
                                  ? _IncidentsTab(controller: controller)
                                  : _AlertsTab(controller: controller),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _RightsTab extends StatelessWidget {
  const _RightsTab({required this.controller});
  final StaffComplianceController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.rights.isEmpty) const Text('No rights requests.'),
          for (final r in controller.rights)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${r.requestType} · ${r.status}'),
                subtitle: Text(
                  '${r.createdAt.toLocal()}'
                  '${r.notes != null ? '\n${r.notes}' : ''}',
                ),
                isThreeLine: r.notes != null,
              ),
            ),
        ],
      );
    });
  }
}

class _AccessTab extends StatelessWidget {
  const _AccessTab({required this.controller});
  final StaffComplianceController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (controller.accessHistory.isEmpty)
            const Text('No access history entries.'),
          for (final e in controller.accessHistory)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(e.action ?? 'event'),
                subtitle: Text(
                  '${e.createdAt.toLocal()}'
                  '${e.actorLabel != null ? ' · ${e.actorLabel}' : ''}'
                  '${e.detail != null ? '\n${e.detail}' : ''}',
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _IncidentsTab extends StatelessWidget {
  const _IncidentsTab({required this.controller});
  final StaffComplianceController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.selectedIncident.value;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dates below come from the API (including any assessment due). '
            'This screen does not provide legal advice.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (controller.canIncidents) ...[
            TextField(
              controller: controller.incidentTitleCtrl,
              decoration: const InputDecoration(
                labelText: 'New incident title *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller.incidentDescCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed:
                  controller.isSaving.value ? null : controller.createIncident,
              child: const Text('Create incident'),
            ),
            const Divider(height: 32),
          ],
          if (controller.incidents.isEmpty) const Text('No incidents.'),
          for (final i in controller.incidents)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(i.title),
                subtitle: Text(
                  '${i.status}'
                  '${i.assessmentClockLabel != null ? '\n${i.assessmentClockLabel}' : ''}',
                ),
                isThreeLine: i.assessmentClockLabel != null,
                onTap: () => controller.openIncident(i),
              ),
            ),
          if (selected != null) ...[
            const Divider(height: 24),
            Text('Detail', style: Get.textTheme.titleMedium),
            Text(selected.description ?? 'No description'),
            if (selected.assessmentClockLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(selected.assessmentClockLabel!),
              ),
            if (controller.canIncidents && selected.status != 'closed')
              TextButton(
                onPressed: () => controller.closeIncident(selected),
                child: const Text('Mark closed'),
              ),
          ],
        ],
      );
    });
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.controller});
  final StaffComplianceController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Recent notification events (credentials / visits / engagement).',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (controller.events.isEmpty) const Text('No events.'),
          for (final e in controller.events)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(e.summary),
                subtitle: Text(e.createdAt.toLocal().toString()),
              ),
            ),
          TextButton(
            onPressed: BillingGate.openBillingUrl,
            child: const Text('Open billing URL'),
          ),
        ],
      );
    });
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
