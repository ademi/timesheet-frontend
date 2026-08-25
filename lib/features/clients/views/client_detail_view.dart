import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../../shared/widgets/subject_tab_bar.dart';
import '../controllers/clients_controller.dart';
import '../widgets/client_detail_contacts_section.dart';
import '../widgets/client_detail_facts_section.dart';
import '../widgets/client_detail_profile_section.dart';
import '../widgets/client_detail_sites_section.dart';
import '../widgets/client_detail_support_section.dart';
import '../widgets/client_detail_visits_section.dart';
import '../widgets/ndis_capture_prompt.dart';

class ClientDetailView extends GetView<ClientsController> {
  const ClientDetailView({super.key});

  static const _tabLabels = [
    'Overview',
    'Support',
    'Locations',
    'Contacts',
    'Details',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final client = controller.selected.value;
      if (client == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Client')),
          body: controller.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: Text('Client not found.')),
        );
      }
      final err = controller.errorMessage.value;
      final tab = controller.tabIndex.value;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(client.fullName),
          actions: [
            if (controller.canManage)
              IconButton(
                tooltip: 'Edit',
                onPressed: controller.isSaving.value
                    ? null
                    : () => controller.openEdit(client),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (controller.canManage)
              IconButton(
                tooltip: 'Delete',
                onPressed: controller.isSaving.value
                    ? null
                    : () => controller.deleteClient(client),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: Column(
          children: [
            if (controller.isLoading.value)
              const LinearProgressIndicator(minHeight: 2),
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  ProfilePhotoEditor(
                    networkUrl: controller.detailPhoto.value?.downloadUrl,
                    documentId: controller.detailPhoto.value?.documentId,
                    isLoading: controller.isDetailPhotoLoading.value,
                    readOnly: true,
                    size: 72,
                    showLabel: false,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    client.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  if (controller.ndisNumber != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'NDIS ${controller.ndisNumber}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (controller.showNdisCapturePrompt) ...[
                    const SizedBox(height: 12),
                    NdisCapturePrompt(
                      onAddDetails: () =>
                          controller.tabIndex.value = ClientsController.tabDetails,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SubjectTabBar(
              labels: _tabLabels,
              index: tab,
              keyPrefix: 'client-detail-tab',
              onChanged: (i) => controller.tabIndex.value = i,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  PageContent(
                    child: _tabContent(tab),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _tabContent(int tab) {
    switch (tab) {
      case ClientsController.tabLocations:
        return ClientDetailSitesSection(
          sites: controller.sites.toList(),
          canManage: controller.canManage,
          onAdd: () => controller.beginSiteForm(),
          onEdit: (s) => controller.beginSiteForm(site: s),
          onDelete: controller.deleteSite,
        );
      case ClientsController.tabContacts:
        return ClientDetailContactsSection(
          contacts: controller.contacts.toList(),
          canManage: controller.canManage,
          onAdd: () => controller.beginContactForm(),
          onEdit: (c) => controller.beginContactForm(contact: c),
          onDelete: controller.deleteContact,
        );
      case ClientsController.tabSupport:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.canManageSupport || controller.hasOngoing)
              ClientDetailSupportSection(
                hasOngoing: controller.hasOngoing,
                canManage: controller.canManageSupport,
                supportItemCode: controller.standingJob.value?.supportItemCode,
                supportItemName: controller.standingJob.value?.supportItemName,
                onStartOngoing: controller.startOngoingSupport,
                onBookOne: controller.bookOneSession,
                onOpenOngoing: controller.openOngoingSupport,
              )
            else
              const Text(
                'No support arrangement yet.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            const SizedBox(height: 24),
            ClientDetailVisitsSection(
              upcoming: controller.upcomingVisits.toList(),
              past: controller.pastVisits.toList(),
              isLoading: controller.isLoadingVisits.value,
              error: controller.visitsError.value,
              truncated: controller.visitsTruncated.value,
              hasVisitsAccess: controller.canViewVisits,
              onOpen: controller.openVisitDetail,
            ),
          ],
        );
      case ClientsController.tabDetails:
        return ClientDetailProfileSection(controller: controller);
      case ClientsController.tabOverview:
      default:
        return ClientDetailFactsSection(facts: controller.quickFacts);
    }
  }
}
