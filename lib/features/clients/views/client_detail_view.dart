import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../../shared/widgets/subject_tab_bar.dart';
import '../controllers/clients_controller.dart';
import '../widgets/client_detail_contacts_section.dart';
import '../widgets/client_detail_overview_section.dart';
import '../widgets/client_detail_profile_section.dart';
import '../widgets/client_detail_sites_section.dart';
import '../widgets/client_detail_support_section.dart';
import '../widgets/client_detail_visits_section.dart';
import '../widgets/ndis_capture_prompt.dart';

class ClientDetailView extends GetView<ClientsController> {
  const ClientDetailView({super.key});

  static const _tabLabels = [
    'Overview',
    'Care plan',
    'Profile & docs',
    'People',
    'Places',
    'Visits',
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final client = controller.selected.value;
      if (client == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Client')),
          body:
              controller.isLoading.value
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(child: Text('Client not found.')),
        );
      }
      final err = controller.errorMessage.value;
      final tab = controller.tabIndex.value;
      final profileSelected = tab == ClientsController.tabProfile;
      final overviewSelected = tab == ClientsController.tabOverview;
      final canEditProfile =
          controller.canManage || controller.canManageProfile;
      final canEditOverview = canEditProfile;
      final errorNotice =
          err == null
              ? null
              : Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FloatingErrorNotice(
                  message: err,
                  onDismiss: () => controller.errorMessage.value = null,
                ),
              );
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(client.fullName),
          actions: [
            if (controller.canManage)
              IconButton(
                tooltip: 'Edit',
                onPressed:
                    controller.isSaving.value
                        ? null
                        : () => controller.openEdit(client),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (controller.canManage)
              IconButton(
                tooltip: 'Delete',
                onPressed:
                    controller.isSaving.value
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
            if (errorNotice != null && !profileSelected && !overviewSelected)
              errorNotice,
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
                  if (ClientsController.isOnboardingIncomplete(client)) ...[
                    const SizedBox(height: 12),
                    _IncompleteOnboardingBanner(
                      onContinue: controller.canManage
                          ? () => controller.openResumeOnboarding(client)
                          : null,
                    ),
                  ],
                  if (controller.showNdisCapturePrompt) ...[
                    const SizedBox(height: 12),
                    NdisCapturePrompt(
                      onAddDetails:
                          () =>
                              controller.tabIndex.value =
                                  ClientsController.tabOverview,
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
            Expanded(child: _tabContent(tab)),
            if (errorNotice != null && overviewSelected) errorNotice,
            if (overviewSelected && canEditOverview)
              FormStickyActions(
                onCancel: controller.discardOverviewDrafts,
                primaryLabel: 'Save',
                onPrimary: controller.saveOverviewProfile,
                isLoading: controller.isSaving.value,
              ),
            if (errorNotice != null && profileSelected) errorNotice,
            if (profileSelected && canEditProfile)
              FormStickyActions(
                onCancel: controller.discardProfileDrafts,
                primaryLabel: 'Save type & profile',
                onPrimary: controller.saveClientTypeProfile,
                isLoading: controller.isSaving.value,
              ),
          ],
        ),
      );
    });
  }

  Widget _scrollTab(Widget child) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [PageContent(child: child)],
    );
  }

  Widget _tabContent(int tab) {
    switch (tab) {
      case ClientsController.tabPlaces:
        return _scrollTab(
          ClientDetailSitesSection(
            sites: controller.sites.toList(),
            canManage: controller.canManage,
            onAdd: () => controller.beginSiteForm(),
            onEdit: (s) => controller.beginSiteForm(site: s),
            onDelete: controller.deleteSite,
          ),
        );
      case ClientsController.tabPeople:
        return _scrollTab(
          ClientDetailContactsSection(
            contacts: controller.contacts.toList(),
            canManage: controller.canManage,
            onAdd: () => controller.beginContactForm(),
            onEdit: (c) => controller.beginContactForm(contact: c),
            onDelete: controller.deleteContact,
          ),
        );
      case ClientsController.tabCarePlan:
        return _scrollTab(_carePlanTempContent());
      case ClientsController.tabVisits:
        return _scrollTab(
          ClientDetailVisitsSection(
            upcoming: controller.upcomingVisits.toList(),
            past: controller.pastVisits.toList(),
            isLoading: controller.isLoadingVisits.value,
            error: controller.visitsError.value,
            truncated: controller.visitsTruncated.value,
            hasVisitsAccess: controller.canViewVisits,
            onOpen: controller.openVisitDetail,
          ),
        );
      case ClientsController.tabProfile:
        return _scrollTab(ClientDetailProfileSection(controller: controller));
      case ClientsController.tabOverview:
      default:
        return _scrollTab(
          ClientDetailOverviewSection(controller: controller),
        );
    }
  }

  /// Temporary Care plan body: old Support tab minus the visits list.
  Widget _carePlanTempContent() {
    if (controller.canManageSupport ||
        controller.hasOngoing ||
        controller.canManage) {
      return ClientDetailSupportSection(
        hasOngoing: controller.hasOngoing,
        canManage: controller.canManageSupport,
        supportItemCode: controller.standingJob.value?.supportItemCode,
        supportItemName: controller.standingJob.value?.supportItemName,
        onStartOngoing: controller.startOngoingSupport,
        onBookOne: controller.bookOneSession,
        onOpenOngoing: controller.openOngoingSupport,
        canManageSupportPlan: controller.canManage,
        supportPlanStatus: controller.supportPlan.value?.status,
        supportPlanNextReview: controller.supportPlan.value?.nextReviewAt,
        supportPlanOverdue: controller.supportPlan.value?.reviewOverdue == true,
        onOpenSupportPlan: controller.openSupportPlan,
      );
    }
    return const Text(
      'No support arrangement yet.',
      style: TextStyle(color: AppColors.textMuted),
    );
  }
}

class _IncompleteOnboardingBanner extends StatelessWidget {
  const _IncompleteOnboardingBanner({this.onContinue});

  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.openSlotBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.openSlot),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Onboarding incomplete',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.openSlot,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Finish adding this participant\'s details to complete setup.',
            style: TextStyle(fontSize: 13),
          ),
          if (onContinue != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onContinue,
                child: const Text('Continue onboarding'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
