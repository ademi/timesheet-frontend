import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/views/widgets/app_back_button.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../../shared/widgets/subject_tab_bar.dart';
import '../controllers/clients_controller.dart';
import '../controllers/support_plan_controller.dart';
import '../widgets/client_detail_care_plan_section.dart';
import '../widgets/client_detail_contacts_section.dart';
import '../widgets/client_detail_overview_section.dart';
import '../widgets/client_detail_profile_section.dart';
import '../widgets/client_detail_sites_section.dart';
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
      final carePlanSelected = tab == ClientsController.tabCarePlan;
      final archived = client.status == 'archived';
      final canEditProfile =
          !archived &&
          (controller.canManage || controller.canManageProfile);
      final canEditOverview = canEditProfile;
      final canEditCarePlan = !archived && controller.canManage;
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
          leading: const AppBackButton(fallbackRoute: AppRoutes.staffClients),
          title: Text(client.fullName),
          actions: [
            if (controller.canManage && !archived)
              IconButton(
                tooltip: 'Edit',
                onPressed:
                    controller.isSaving.value
                        ? null
                        : () => controller.openEdit(client),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (controller.canManage && !archived)
              IconButton(
                tooltip: 'Archive',
                onPressed:
                    controller.isSaving.value
                        ? null
                        : () => controller.deleteClient(client),
                icon: const Icon(Icons.archive_outlined),
              ),
            if (controller.canManage && archived)
              IconButton(
                tooltip: 'Restore',
                onPressed:
                    controller.isSaving.value
                        ? null
                        : () => controller.restoreClient(client),
                icon: const Icon(Icons.unarchive_outlined),
              ),
          ],
        ),
        body: Column(
          children: [
            if (controller.isLoading.value)
              const LinearProgressIndicator(minHeight: 2),
            if (errorNotice != null &&
                !profileSelected &&
                !overviewSelected &&
                !carePlanSelected)
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
                  if (archived) ...[
                    const SizedBox(height: 12),
                    _ArchivedClientBanner(
                      onRestore:
                          controller.canManage
                              ? () => controller.restoreClient(client)
                              : null,
                      isBusy: controller.isSaving.value,
                    ),
                  ],
                  if (ClientsController.isOnboardingIncomplete(client)) ...[
                    const SizedBox(height: 12),
                    _IncompleteOnboardingBanner(
                      onContinue:
                          controller.canManage && !archived
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
              onChanged: (i) {
                if (i == ClientsController.tabCarePlan) {
                  controller.ensureCarePlanController();
                }
                controller.tabIndex.value = i;
              },
            ),
            Expanded(child: _tabContent(tab, canEdit: !archived)),
            if (errorNotice != null && overviewSelected) errorNotice,
            if (overviewSelected &&
                canEditOverview &&
                controller.overviewEditing.value)
              FormStickyActions(
                onCancel: controller.discardOverviewDrafts,
                primaryLabel: 'Save',
                onPrimary: controller.saveOverviewProfile,
                isLoading: controller.isSaving.value,
              ),
            if (carePlanSelected && Get.isRegistered<SupportPlanController>())
              _CarePlanSticky(canEdit: canEditCarePlan),
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

  Widget _tabContent(int tab, {required bool canEdit}) {
    final manage = canEdit && controller.canManage;
    final manageSupport = canEdit && controller.canManageSupport;
    switch (tab) {
      case ClientsController.tabPlaces:
        return _scrollTab(
          ClientDetailSitesSection(
            sites: controller.sites.toList(),
            canManage: manage,
            onAdd: () => controller.beginSiteForm(),
            onEdit: (s) => controller.beginSiteForm(site: s),
            onDelete: controller.deleteSite,
          ),
        );
      case ClientsController.tabPeople:
        return _scrollTab(
          ClientDetailContactsSection(
            contacts: controller.contacts.toList(),
            canManage: manage,
            onAdd: () => controller.beginContactForm(),
            onEdit: (c) => controller.beginContactForm(contact: c),
            onDelete: controller.deleteContact,
          ),
        );
      case ClientsController.tabCarePlan:
        if (!Get.isRegistered<SupportPlanController>()) {
          return _scrollTab(
            const Text(
              'No support arrangement yet.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return _scrollTab(
          ClientDetailCarePlanSection(
            controller: Get.find<SupportPlanController>(),
          ),
        );
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
            hasOngoing: controller.hasOngoing,
            canManage: manageSupport,
            supportItemCode: controller.standingJob.value?.supportItemCode,
            supportItemName: controller.standingJob.value?.supportItemName,
            onStartOngoing: controller.startOngoingSupport,
            onBookOne: controller.bookOneSession,
            onOpenOngoing: controller.openOngoingSupport,
          ),
        );
      case ClientsController.tabProfile:
        return _scrollTab(ClientDetailProfileSection(controller: controller));
      case ClientsController.tabOverview:
      default:
        return _scrollTab(
          ClientDetailOverviewSection(
            controller: controller,
            canEditOverride: canEdit,
          ),
        );
    }
  }
}

class _CarePlanSticky extends StatelessWidget {
  const _CarePlanSticky({required this.canEdit});

  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final plan = Get.find<SupportPlanController>();
      final err =
          plan.errorMessage.value ??
          plan.fundingConsent.errorMessage.value ??
          plan.clinical.errorMessage.value;
      final soft = plan.activateSoftWarning.value;
      final busy = plan.isBusy;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (soft != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FloatingErrorNotice(
                message: soft,
                onDismiss: () => plan.activateSoftWarning.value = null,
              ),
            ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: FloatingErrorNotice(
                message: err,
                onDismiss: () {
                  plan.errorMessage.value = null;
                  plan.fundingConsent.errorMessage.value = null;
                  plan.clinical.errorMessage.value = null;
                },
              ),
            ),
          if (canEdit)
            Obx(() {
              final step = plan.wizardStep.value;
              final onReview = step >= SupportPlanController.wizardStepCount - 1;
              return FormStickyActions(
                cancelLabel: step > 0 ? 'Back' : 'Discard',
                onCancel: busy
                    ? null
                    : () {
                        if (step > 0) {
                          plan.prevStep();
                        } else {
                          plan.discardDrafts();
                        }
                      },
                secondaryLabel: 'Save draft',
                onSecondary: busy ? null : () => plan.saveDraft(),
                primaryLabel: onReview ? 'Activate' : 'Next',
                onPrimary: onReview
                    ? (!plan.canActivate || busy ? null : () => plan.activate())
                    : (busy ? null : () => plan.nextStep()),
                isLoading: busy,
              );
            }),
        ],
      );
    });
  }
}

class _ArchivedClientBanner extends StatelessWidget {
  const _ArchivedClientBanner({this.onRestore, this.isBusy = false});

  final VoidCallback? onRestore;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Archived — records retained for legal and audit requirements.',
            style: TextStyle(fontSize: 13),
          ),
          if (onRestore != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isBusy ? null : onRestore,
                icon: const Icon(Icons.unarchive_outlined, size: 18),
                label: const Text('Restore'),
              ),
            ),
          ],
        ],
      ),
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
