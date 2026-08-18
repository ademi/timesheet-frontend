import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/services/session_service.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../engagements/data/repositories/engagements_repository.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../subscription/billing_gate.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../controllers/notifications_feed_controller.dart';
import '../data/models/compliance_ops_models.dart';
import '../data/models/staff_home_stats.dart';
import '../data/repositories/compliance_ops_repository.dart';
import '../widgets/notification_bell_button.dart';

/// Staff dashboard / contractor home (alerts live in the AppBar bell).
class HomeAlertsController extends GetxController {
  HomeAlertsController({
    required ComplianceOpsRepository repository,
    required SessionService session,
    ClientsRepository? clientsRepository,
    EngagementsRepository? engagementsRepository,
    JobsRepository? jobsRepository,
    VisitsRepository? visitsRepository,
    NotificationsFeedController? notificationsFeed,
    void Function(String title, String message)? showSnack,
  }) : _repository = repository,
       _session = session,
       _clientsRepository = clientsRepository,
       _engagementsRepository = engagementsRepository,
       _jobsRepository = jobsRepository,
       _visitsRepository = visitsRepository,
       _notificationsFeed = notificationsFeed,
       _showSnack = showSnack ?? _defaultSnack;

  final ComplianceOpsRepository _repository;
  final SessionService _session;
  final ClientsRepository? _clientsRepository;
  final EngagementsRepository? _engagementsRepository;
  final JobsRepository? _jobsRepository;
  final VisitsRepository? _visitsRepository;
  final NotificationsFeedController? _notificationsFeed;
  final void Function(String title, String message) _showSnack;

  static void _defaultSnack(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.primary,
      colorText: AppColors.onPrimary,
    );
  }

  final isLoading = false.obs;
  final isLoadingStats = false.obs;
  final errorMessage = RxnString();
  final subscription = Rxn<SubscriptionStatusOut>();
  final pendingSharingRequests = <SharingAccessRequestOut>[].obs;
  final approvingRequestId = RxnString();
  final stats = Rxn<StaffHomeStats>();

  bool get isStaff => _session.isStaff;
  bool get isContractor => _session.isContractor;
  bool get shouldShowDocsBanner => !isStaff && _session.needsDocsAttention;
  bool get canViewBilling =>
      isStaff &&
      (_session.hasPermission(AppPermissions.subscriptionView) ||
          _session.hasPermission(AppPermissions.billingView) ||
          _session.hasPermission(AppPermissions.tenantsManage));

  bool get canReadClients =>
      _session.hasPermission(AppPermissions.clientsRead) ||
      _session.hasPermission(AppPermissions.clientsManage);
  bool get canReadContractors =>
      _session.hasPermission(AppPermissions.contractorsRead) ||
      _session.hasPermission(AppPermissions.contractorsManage);
  bool get canReadJobs =>
      _session.hasPermission(AppPermissions.jobsRead) ||
      _session.hasPermission(AppPermissions.jobsManage);
  bool get canReadVisits =>
      _session.hasPermission(AppPermissions.visitsRead) ||
      _session.hasPermission(AppPermissions.visitsManage) ||
      _session.hasPermission(AppPermissions.jobsManage);

  bool get showDashboard => isStaff;

  static const _cacheTtl = Duration(seconds: 45);
  DateTime? _lastLoadedAt;
  Future<void>? _loadInFlight;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  bool get _isFresh =>
      _lastLoadedAt != null &&
      DateTime.now().difference(_lastLoadedAt!) < _cacheTtl;

  Future<void> load({bool force = false}) async {
    if (_loadInFlight != null) return _loadInFlight!;
    if (!force && _isFresh) return;

    final future = _loadBody(force: force);
    _loadInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> _loadBody({required bool force}) async {
    isLoading.value = true;
    errorMessage.value = null;

    final feed =
        _notificationsFeed ??
        (Get.isRegistered<NotificationsFeedController>()
            ? Get.find<NotificationsFeedController>()
            : null);
    final notificationsFuture = feed?.load(force: force);

    if (isContractor) {
      try {
        final pending = await _repository.listSharingAccessRequests(
          status: 'pending',
        );
        pendingSharingRequests.assignAll(pending);
      } on AppFailure catch (_) {
        // Non-blocking: home still useful without share banners.
      }
    } else {
      pendingSharingRequests.clear();
    }
    if (canViewBilling) {
      try {
        subscription.value = await _repository.getSubscription();
      } on AppFailure catch (_) {}
    }

    await notificationsFuture;

    isLoading.value = false;

    if (showDashboard) {
      await loadStats();
    } else {
      stats.value = null;
    }
    _lastLoadedAt = DateTime.now();
  }

  Future<void> loadStats() async {
    if (!showDashboard) return;
    isLoadingStats.value = true;

    final clientsFuture = _loadClientCounts();
    final contractorsFuture = _loadContractorCounts();
    final jobsFuture = _loadJobCounts();
    final visitsFuture = _loadVisitCounts();

    final clients = await clientsFuture;
    final contractors = await contractorsFuture;
    final jobs = await jobsFuture;
    final visits = await visitsFuture;

    stats.value = StaffHomeStats(
      clientsTotal: clients.$1,
      clientsActive: clients.$2,
      contractorsTotal: contractors.$1,
      contractorsActive: contractors.$2,
      contractorsInvited: contractors.$3,
      contractorsPendingDocs: contractors.$4,
      jobsTotal: jobs.$1,
      jobsOpen: jobs.$2,
      visitsToday: visits.$1,
      visitsScheduledToday: visits.$2,
      visitsCompletedToday: visits.$3,
      visitsThisWeek: visits.$4,
    );
    isLoadingStats.value = false;
  }

  Future<(int, int)> _loadClientCounts() async {
    final repo = _clientsRepository;
    if (!canReadClients || repo == null) return (0, 0);
    try {
      final clients = await repo.listClients();
      return (
        clients.length,
        clients.where((c) => c.status == 'active').length,
      );
    } on AppFailure catch (_) {
      return (0, 0);
    }
  }

  Future<(int, int, int, int)> _loadContractorCounts() async {
    final repo = _engagementsRepository;
    if (!canReadContractors || repo == null) {
      return (0, 0, 0, 0);
    }
    try {
      final engagements = await repo.listTenantEngagements();
      return (
        engagements.length,
        engagements.where((e) => e.isActive).length,
        engagements.where((e) => e.isInvited).length,
        engagements.where((e) => e.isPendingDocs).length,
      );
    } on AppFailure catch (_) {
      return (0, 0, 0, 0);
    }
  }

  Future<(int, int)> _loadJobCounts() async {
    final repo = _jobsRepository;
    if (!canReadJobs || repo == null) return (0, 0);
    try {
      final jobs = await repo.listJobs();
      return (jobs.length, jobs.where((j) => j.isOpen).length);
    } on AppFailure catch (_) {
      return (0, 0);
    }
  }

  Future<(int, int, int, int)> _loadVisitCounts() async {
    final repo = _visitsRepository;
    if (!canReadVisits || repo == null) return (0, 0, 0, 0);
    try {
      final now = DateTime.now();
      final dayStart = DateTime(now.year, now.month, now.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final visits = await repo.listVisits(
        from: dayStart.toUtc(),
        to: dayStart.add(const Duration(days: 7)).toUtc(),
      );
      final week = visits.where((v) => !v.isCancelled).length;
      final today =
          visits.where((v) {
            final start = v.scheduledStart.toLocal();
            return !start.isBefore(dayStart) && start.isBefore(dayEnd);
          }).toList(growable: false);
      return (
        today.where((v) => !v.isCancelled).length,
        today.where((v) => v.isScheduled).length,
        today.where((v) => v.isCompleted).length,
        week,
      );
    } on AppFailure catch (_) {
      return (0, 0, 0, 0);
    }
  }

  void openRoute(String route) {
    if (Get.currentRoute == route) return;
    Get.offNamed(route);
  }

  String tenantLabelFor(SharingAccessRequestOut request) {
    for (final e in _session.engagements) {
      if (e.id == request.engagementId && e.tenantName.isNotEmpty) {
        return e.tenantName;
      }
    }
    for (final e in _session.engagements) {
      if (e.tenantId == request.tenantId && e.tenantName.isNotEmpty) {
        return e.tenantName;
      }
    }
    return 'An organisation';
  }

  Future<bool> approveSharingRequest(SharingAccessRequestOut request) async {
    approvingRequestId.value = request.id;
    errorMessage.value = null;
    try {
      await _repository.approveSharingAccessRequest(request.id);
      final tenant = tenantLabelFor(request);
      _showSnack('Access approved', 'Credentials shared with $tenant.');
      try {
        final pending = await _repository.listSharingAccessRequests(
          status: 'pending',
        );
        pendingSharingRequests.assignAll(pending);
      } on AppFailure catch (_) {
        pendingSharingRequests.removeWhere((r) => r.id == request.id);
      }
      return true;
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      return false;
    } catch (e) {
      errorMessage.value = e.toString();
      return false;
    } finally {
      approvingRequestId.value = null;
    }
  }
}

class HomeAlertsView extends GetView<HomeAlertsController> {
  const HomeAlertsView({super.key});

  @override
  Widget build(BuildContext context) {
    final title = controller.isStaff ? 'Dashboard' : 'Contractor home';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        actions: shellAppBarActions(
          onRefresh: () {
            controller.load(force: true);
          },
        ),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.stats.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
        final sub = controller.subscription.value;
        final stats = controller.stats.value;
        return RefreshIndicator(
          onRefresh: () => controller.load(force: true),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              if (controller.shouldShowDocsBanner) ...[
                MaterialBanner(
                  content: const Text(
                    'Documents still needed for an engagement. '
                    'Upload required credentials to continue.',
                  ),
                  leading: const Icon(Icons.description_outlined),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  actions: [
                    TextButton(
                      onPressed:
                          () => Get.toNamed(AppRoutes.contractorCredentials),
                      child: const Text('Upload credentials'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              for (final request in controller.pendingSharingRequests) ...[
                MaterialBanner(
                  content: Text(
                    '${controller.tenantLabelFor(request)} requested access '
                    'to your credentials for compliance review.',
                  ),
                  leading: const Icon(Icons.shield_outlined),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  actions: [
                    TextButton(
                      onPressed:
                          controller.approvingRequestId.value == request.id
                              ? null
                              : () => controller.approveSharingRequest(request),
                      child:
                          controller.approvingRequestId.value == request.id
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Approve'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (err != null) ...[
                Container(
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
                const SizedBox(height: 12),
              ],
              if (sub != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Subscription: ${sub.status}'
                          '${sub.planName != null ? ' · ${sub.planName}' : ''}',
                        ),
                      ),
                      TextButton(
                        onPressed: BillingGate.openBillingUrl,
                        child: const Text('Billing'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (controller.showDashboard) ...[
                Text('Overview', style: Get.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (controller.isLoadingStats.value && stats == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (stats != null)
                  _StaffDashboardGrid(stats: stats, controller: controller),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Use the notification icon above for alerts and updates.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _StaffDashboardGrid extends StatelessWidget {
  const _StaffDashboardGrid({
    required this.stats,
    required this.controller,
  });

  final StaffHomeStats stats;
  final HomeAlertsController controller;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    if (controller.canReadClients) {
      tiles.add(
        _StatTile(
          icon: Icons.people_outline,
          label: 'Clients',
          value: '${stats.clientsTotal}',
          detail: '${stats.clientsActive} active',
          onTap: () => controller.openRoute(AppRoutes.staffClients),
        ),
      );
    }

    if (controller.canReadContractors) {
      tiles.add(
        _StatTile(
          icon: Icons.groups_outlined,
          label: 'Contractors',
          value: '${stats.contractorsActive}',
          detail:
              '${stats.contractorsInvited} invited'
              '${stats.contractorsPendingDocs > 0 ? ' · ${stats.contractorsPendingDocs} pending docs' : ''}',
          onTap: () => controller.openRoute(AppRoutes.staffWorkforce),
        ),
      );
    }

    if (controller.canReadJobs) {
      tiles.add(
        _StatTile(
          icon: Icons.work_outline,
          label: 'Jobs',
          value: '${stats.jobsOpen}',
          detail: '${stats.jobsTotal} total',
          onTap: () => controller.openRoute(AppRoutes.staffJobs),
        ),
      );
    }

    if (controller.canReadVisits) {
      tiles.add(
        _StatTile(
          icon: Icons.event_available_outlined,
          label: 'Visits today',
          value: '${stats.visitsToday}',
          detail:
              '${stats.visitsScheduledToday} scheduled · ${stats.visitsCompletedToday} done',
          onTap: () => controller.openRoute(AppRoutes.staffVisits),
        ),
      );
      tiles.add(
        _StatTile(
          icon: Icons.calendar_view_week_outlined,
          label: 'Visits (7 days)',
          value: '${stats.visitsThisWeek}',
          detail: 'From today',
          onTap: () => controller.openRoute(AppRoutes.staffVisits),
        ),
      );
    }

    if (tiles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No overview stats available for your permissions.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = switch (Breakpoints.classify(width)) {
          DeviceClass.phone => 2,
          DeviceClass.tablet => 3,
          DeviceClass.desktop => 4,
        };
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns >= 3 ? 1.45 : 1.35,
          children: tiles,
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBackground,
      elevation: 1,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.slate600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
