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
    return Obx(() {
      if (controller.isLoadingProfile.value &&
          controller.staffProfile.value == null) {
        return const Center(child: CircularProgressIndicator());
      }
      final profile = controller.staffProfile.value;
      final screening = profile?.compliance['screening'];
      final checks = profile?.compliance['checks'];
      final qualifications = profile?.compliance['qualifications'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Profile information is entered by the contractor. '
            'Staff can review it here but cannot edit it.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _row('Email', profile?.email ?? current.contractorEmail ?? '—'),
          _row('Full name', profile?.fullName ?? current.displayName),
          _row('Phone', _orDash(profile?.phone)),
          _row(
            'Date of birth',
            profile?.dob == null
                ? '—'
                : profile!.dob!.toIso8601String().split('T').first,
          ),
          _row('ABN', _orDash(profile?.abn)),
          const SizedBox(height: 16),
          const Text(
            'Address',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _row('Line 1', _orDash(profile?.address.addressLine1)),
          _row('Line 2', _orDash(profile?.address.addressLine2)),
          _row('Suburb', _orDash(profile?.address.suburb)),
          _row('State', _orDash(profile?.address.state)),
          _row('Postcode', _orDash(profile?.address.postcode)),
          _row('Country', _orDash(profile?.address.country)),
          const SizedBox(height: 16),
          const Text(
            'Screening',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (screening is Map) ...[
            _row('NDIS screening number', _mapText(screening, 'number')),
            _row('Clearance status', _mapText(screening, 'status')),
            _row('Issue date', _mapText(screening, 'issue_date')),
            _row('Expiry date', _mapText(screening, 'expiry_date')),
            _row('State/territory', _mapText(screening, 'state')),
          ] else
            const Text(
              'No screening details on file.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          const SizedBox(height: 16),
          const Text(
            'Qualifications',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (qualifications is List && qualifications.isNotEmpty)
            for (var i = 0; i < qualifications.length; i++)
              if (qualifications[i] is Map) ...[
                if (i > 0) const SizedBox(height: 8),
                _row(
                  'Type',
                  _mapText(qualifications[i] as Map, 'type'),
                ),
                _row(
                  'Issue date',
                  _mapText(qualifications[i] as Map, 'issue_date'),
                ),
                _row(
                  'Expiry date',
                  _mapText(qualifications[i] as Map, 'expiry_date'),
                ),
              ]
          else
            const Text(
              'No qualifications on file.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          const SizedBox(height: 16),
          const Text(
            'Checks',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (checks is Map) ...[
            _checkSection('WWCC', checks['wwcc']),
            _checkSection('Driver licence', checks['drivers_licence'],
                numberKey: 'number'),
            _checkSection('Vehicle registration', checks['vehicle_registration'],
                numberKey: 'plate'),
          ] else
            const Text(
              'No check details on file.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          if (profile?.paymentDetails != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Payment',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _row('Account name', profile!.paymentDetails!.accountName),
            _row('BSB', profile.paymentDetails!.bsb),
            _row(
              'Account number',
              profile.paymentDetails!.accountNumberMasked,
            ),
          ],
        ],
      );
    });
  }

  Widget _checkSection(
    String label,
    Object? value, {
    String numberKey = 'number',
  }) {
    if (value is! Map) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _row(label, '—'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('$label number', _mapText(value, numberKey)),
        _row('$label state', _mapText(value, 'state')),
        _row('$label expiry', _mapText(value, 'expiry_date')),
      ],
    );
  }

  String _orDash(String? value) =>
      value == null || value.trim().isEmpty ? '—' : value.trim();

  String _mapText(Map map, String key) {
    final value = map[key];
    if (value == null) return '—';
    final text = value.toString().trim();
    return text.isEmpty ? '—' : text;
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
