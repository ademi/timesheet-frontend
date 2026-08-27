import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/availability_rules_readout.dart';
import '../../../shared/widgets/eligibility_incomplete_panel.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../../shared/widgets/subject_tab_bar.dart';
import '../../../shared/widgets/visit_day_agenda.dart';
import '../../clients/widgets/client_detail_visits_section.dart';
import '../../payroll/widgets/engagement_rate_bands_section.dart';
import '../controllers/workforce_controller.dart';
import '../data/models/engagement_models.dart';

class WorkforceDetailView extends GetView<WorkforceController> {
  const WorkforceDetailView({super.key});

  static const _tabLabels = [
    'Overview',
    'Profile',
    'Credentials',
    'Visits',
    'Schedule',
  ];

  @override
  Widget build(BuildContext context) {
    final arg = Get.arguments;
    final EngagementOut? initial =
        arg is EngagementOut ? arg : controller.selected;
    if (initial == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Engagement')),
        body: const Center(child: Text('Engagement not found.')),
      );
    }

    return Obx(() {
      EngagementOut current = initial;
      for (final e in controller.items) {
        if (e.id == initial.id) {
          current = e;
          break;
        }
      }
      if (controller.selected?.id == initial.id) {
        current = controller.selected!;
      }
      final err = controller.errorMessage.value;
      final tab = controller.tabIndex.value;

      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(current.displayName),
        ),
        body: Column(
          children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(
                      err,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    trailing: IconButton(
                      tooltip: 'Dismiss',
                      onPressed: controller.clearError,
                      icon: const Icon(Icons.close, color: AppColors.error),
                    ),
                  ),
                ),
              ),
            if (controller.eligibilityReasons.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: EligibilityIncompletePanel(
                  reasons: controller.eligibilityReasons.toList(),
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
                    current.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SubjectTabBar(
              labels: _tabLabels,
              index: tab,
              keyPrefix: 'contractor-detail-tab',
              onChanged: (i) => controller.tabIndex.value = i,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  PageContent(
                    width: PageContentWidth.wide,
                    child: _tabContent(current, tab),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _tabContent(EngagementOut current, int tab) {
    switch (tab) {
      case WorkforceController.tabProfile:
        return _profileContent(current);
      case WorkforceController.tabCredentials:
        return _credentialsContent(current);
      case WorkforceController.tabVisits:
        return ClientDetailVisitsSection(
          upcoming: controller.upcomingVisits.toList(),
          past: controller.pastVisits.toList(),
          isLoading: controller.isLoadingVisits.value,
          error: controller.visitsError.value,
          truncated: controller.visitsTruncated.value,
          hasVisitsAccess: controller.canViewVisits,
          showPast: false,
          onOpen: controller.openVisitDetail,
        );
      case WorkforceController.tabSchedule:
        return _scheduleContent();
      case WorkforceController.tabOverview:
      default:
        return _overviewContent(current);
    }
  }

  Widget _profileContent(EngagementOut current) {
    if (controller.isLoadingProfile.value &&
        controller.staffProfile.value == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Email: ${controller.staffProfile.value?.email ?? current.contractorEmail ?? '—'}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller.profileFullNameCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profilePhoneCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: 12),
        Obx(
          () => ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of birth'),
            subtitle: Text(
              controller.profileDob.value == null
                  ? 'Not set'
                  : controller.profileDob.value!
                      .toIso8601String()
                      .split('T')
                      .first,
            ),
            trailing: controller.canInvite
                ? const Icon(Icons.calendar_today_outlined)
                : null,
            onTap: !controller.canInvite
                ? null
                : () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: Get.context!,
                      initialDate: controller.profileDob.value ??
                          DateTime(now.year - 30),
                      firstDate: DateTime(now.year - 80),
                      lastDate: now,
                    );
                    if (picked != null) controller.profileDob.value = picked;
                  },
          ),
        ),
        TextField(
          controller: controller.profileAbnCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'ABN'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Address',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.profileAddress1Ctrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Address line 1'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileAddress2Ctrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Address line 2'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileSuburbCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Suburb'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller.profileStateCtrl,
                enabled: controller.canInvite,
                decoration: const InputDecoration(labelText: 'State'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller.profilePostcodeCtrl,
                enabled: controller.canInvite,
                decoration: const InputDecoration(labelText: 'Postcode'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileCountryCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Country'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Screening / checks (CRM)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller.profileScreeningNumberCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'NDIS screening number'),
        ),
        const SizedBox(height: 12),
        Obx(
          () => DropdownButtonFormField<String>(
            value: controller.profileScreeningStatus.value,
            decoration: const InputDecoration(labelText: 'Clearance status'),
            items: const [
              DropdownMenuItem(value: 'cleared', child: Text('Cleared')),
              DropdownMenuItem(value: 'excluded', child: Text('Excluded')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: controller.canInvite
                ? (v) => controller.profileScreeningStatus.value = v
                : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileScreeningStateCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Screening state'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileWwccNumberCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'WWCC number'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileWwccStateCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'WWCC state'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileLicenceNumberCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Licence number'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileLicenceStateCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Licence state'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileVehiclePlateCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Vehicle plate'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller.profileVehicleStateCtrl,
          enabled: controller.canInvite,
          decoration: const InputDecoration(labelText: 'Vehicle state'),
        ),
        if (controller.canInvite) ...[
          const SizedBox(height: 20),
          AsyncElevatedButton(
            onPressed: controller.saveStaffProfile,
            isLoading: controller.isSavingProfile.value,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Save profile'),
          ),
        ],
      ],
    );
  }

  Widget _scheduleContent() {
    final availabilityErr = controller.scheduleError.value;
    final visitsErr = controller.visitsError.value;
    final loading = controller.isLoadingVisits.value ||
        controller.isLoadingAvailability.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Availability',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (availabilityErr != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              availabilityErr,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 8),
        ],
        AvailabilityRulesReadout(
          rules: controller.detailAvailability.toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Timetable',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        if (visitsErr != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.errorBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              visitsErr,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 8),
        ],
        VisitDayAgenda(
          visits: [
            for (final v in [
              ...controller.upcomingVisits,
              ...controller.pastVisits,
            ])
              AgendaVisit(
                start: v.scheduledStart,
                end: v.scheduledEnd,
                title: v.jobTitle ?? 'Visit',
                status: v.status,
                onOpen: () => controller.openVisitDetail(v),
              ),
          ],
        ),
      ],
    );
  }

  Widget _credentialsContent(EngagementOut current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Review submitted certificates. Required document types are edited on the review screen.',
        ),
        if (!current.isEnded) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => controller.openCredentialReview(current),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Review credentials'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _overviewContent(EngagementOut current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('Status', current.statusLabel),
        const SizedBox(height: 16),
        const Text(
          'Lifecycle',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _lifecycleSection(current),
        const SizedBox(height: 24),
        const Text(
          'Payment rates',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        EngagementRateBandsSection(
          key: ValueKey(current.id),
          engagementId: current.id,
          canEditRates: !current.isEnded,
        ),
      ],
    );
  }

  Widget _lifecycleSection(EngagementOut current) {
    if (!controller.canApprove && !controller.canManage) {
      return const Text(
        'No lifecycle actions available for your role.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
      );
    }

    if (current.isInvited) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Waiting for the contractor to accept the invite.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          if (controller.canManage) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: controller.isSaving.value
                  ? null
                  : () => controller.runAction('withdraw', current),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Withdraw invite'),
            ),
          ],
        ],
      );
    }

    final actions = <Widget>[
      if (controller.canApprove && current.isAwaitingApproval) ...[
        _actionButton(
          label: 'Approve documents',
          onPressed: () => controller.runAction('approve', current),
        ),
        _actionButton(
          label: 'Approve and activate for work',
          onPressed: () => controller.runAction('approve_and_activate', current),
        ),
      ],
      if (controller.canManage && current.isApproved)
        _actionButton(
          label: 'Activate',
          onPressed: () => controller.runAction('activate', current),
        ),
      if (controller.canManage && current.isActive)
        _actionButton(
          label: 'Suspend',
          onPressed: () => controller.runAction('suspend', current),
        ),
      if (controller.canManage && current.isSuspended)
        _actionButton(
          label: 'Resume',
          onPressed: () => controller.runAction('resume', current),
        ),
      if (controller.canManage && !current.isEnded && !current.isInvited)
        OutlinedButton(
          onPressed: controller.isSaving.value
              ? null
              : () => controller.runAction('end', current),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: const Text('End engagement'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in actions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: child,
          ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return AsyncElevatedButton(
      onPressed: onPressed,
      isLoading: controller.isSaving.value,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(48),
      ),
      child: Text(label),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
