import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/controllers/auth_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../subscription/billing_gate.dart';
import '../data/models/compliance_ops_models.dart';
import '../data/models/notification_display.dart';
import '../data/repositories/compliance_ops_repository.dart';

/// Staff / contractor home feed of recent notification events.
class HomeAlertsController extends GetxController {
  HomeAlertsController({
    required ComplianceOpsRepository repository,
    required SessionService session,
  }) : _repository = repository,
       _session = session;

  final ComplianceOpsRepository _repository;
  final SessionService _session;

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final events = <NotificationEventOut>[].obs;
  final subscription = Rxn<SubscriptionStatusOut>();

  bool get isStaff => _session.isStaff;
  bool get shouldShowDocsBanner => !isStaff && _session.needsDocsAttention;
  bool get canViewBilling =>
      isStaff &&
      (_session.hasPermission(AppPermissions.subscriptionView) ||
          _session.hasPermission(AppPermissions.billingView) ||
          _session.hasPermission(AppPermissions.tenantsManage));

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final raw = await _repository.listNotificationEvents(limit: 20);
      events.assignAll(dedupeNotificationEvents(raw));
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    }
    if (canViewBilling) {
      try {
        subscription.value = await _repository.getSubscription();
      } on AppFailure catch (_) {}
    }
    isLoading.value = false;
  }
}

class HomeAlertsView extends GetView<HomeAlertsController> {
  const HomeAlertsView({super.key});

  @override
  Widget build(BuildContext context) {
    final title = controller.isStaff ? 'Staff home' : 'Contractor home';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.load,
            icon: const Icon(Icons.refresh),
          ),
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.events.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
        final sub = controller.subscription.value;
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
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
              Text('Alerts', style: Get.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (controller.events.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No notification events yet.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              else
                for (final e in controller.events)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.notifications_outlined),
                    title: Text(notificationTitle(e.eventType, e.payload)),
                    subtitle: Text(formatNotificationTime(e.createdAt)),
                  ),
            ],
          ),
        );
      }),
    );
  }
}
