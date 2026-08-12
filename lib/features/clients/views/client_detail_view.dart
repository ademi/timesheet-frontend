import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../controllers/clients_controller.dart';
import '../widgets/client_detail_contacts_section.dart';
import '../widgets/client_detail_facts_section.dart';
import '../widgets/client_detail_profile_section.dart';
import '../widgets/client_detail_sites_section.dart';
import '../widgets/client_detail_visits_section.dart';

class ClientDetailView extends GetView<ClientsController> {
  const ClientDetailView({super.key});

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
      final quickFacts = controller.quickFacts;
      final sites = controller.sites.toList();
      final contacts = controller.contacts.toList();
      final upcomingVisits = controller.upcomingVisits.toList();
      final pastVisits = controller.pastVisits.toList();
      final isLoadingVisits = controller.isLoadingVisits.value;
      final visitsError = controller.visitsError.value;
      final visitsTruncated = controller.visitsTruncated.value;
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ProfilePhotoEditor(
                        networkUrl: controller.detailPhoto.value?.downloadUrl,
                        documentId: controller.detailPhoto.value?.documentId,
                        isLoading: controller.isDetailPhotoLoading.value,
                        readOnly: true,
                        size: 72,
                        showLabel: false,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          client.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ClientDetailFactsSection(facts: quickFacts),
                  const SizedBox(height: 24),
                  ClientDetailSitesSection(
                    sites: sites,
                    canManage: controller.canManage,
                    onAdd: () => controller.beginSiteForm(),
                    onEdit: (s) => controller.beginSiteForm(site: s),
                    onDelete: controller.deleteSite,
                  ),
                  const SizedBox(height: 24),
                  ClientDetailContactsSection(
                    contacts: contacts,
                    canManage: controller.canManage,
                    onAdd: () => controller.beginContactForm(),
                    onEdit: (c) => controller.beginContactForm(contact: c),
                    onDelete: controller.deleteContact,
                  ),
                  const SizedBox(height: 24),
                  ClientDetailVisitsSection(
                    upcoming: upcomingVisits,
                    past: pastVisits,
                    isLoading: isLoadingVisits,
                    error: visitsError,
                    truncated: visitsTruncated,
                    hasVisitsAccess: controller.canViewVisits,
                    onOpen: controller.openVisitDetail,
                  ),
                  const SizedBox(height: 24),
                  ClientDetailProfileSection(controller: controller),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
