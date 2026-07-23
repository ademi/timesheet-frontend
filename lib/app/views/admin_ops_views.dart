import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/attendance_api_client.dart';
import '../controllers/subscription_store.dart';
import '../routes/app_routes.dart';
import '../themes/app_colors.dart';
import 'widgets/app_back_button.dart';

/// Thin admin list screens for audit / notifications / geofence (F-03)
/// and subscription status + billing link (F-06).
class AdminOpsListController extends GetxController {
  AdminOpsListController({
    required Dio dio,
    required this.title,
    required this.path,
    required this.itemBuilder,
    this.query,
  }) : _dio = dio;

  final Dio _dio;
  final String title;
  final String path;
  final Map<String, dynamic>? query;
  final String Function(Map<String, dynamic> row) itemBuilder;

  final rows = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final response = await _dio.get<dynamic>(path, queryParameters: query);
      final data = response.data;
      if (data is Map && data['items'] is List) {
        rows.assignAll(
          (data['items'] as List).whereType<Map>().map(
                (e) => Map<String, dynamic>.from(e),
              ),
        );
      } else if (data is List) {
        rows.assignAll(
          data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      } else {
        rows.clear();
      }
    } on DioException catch (e) {
      error.value = e.message ?? 'Request failed';
    } finally {
      isLoading.value = false;
    }
  }
}

class AdminOpsListView extends GetView<AdminOpsListController> {
  const AdminOpsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
        title: Text(controller.title),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error.value != null) {
          return Center(child: Text(controller.error.value!));
        }
        if (controller.rows.isEmpty) {
          return const Center(child: Text('No records.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: controller.rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final row = controller.rows[i];
            return ListTile(
              tileColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(controller.itemBuilder(row)),
            );
          },
        );
      }),
    );
  }
}

class AdminBillingController extends GetxController {
  AdminBillingController({required Dio dio}) : _dio = dio;

  final Dio _dio;
  final isLoading = false.obs;
  final statusText = 'Loading…'.obs;
  final detailText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.apiV1}/subscription',
      );
      final data = response.data ?? <String, dynamic>{};
      statusText.value = '${data['status'] ?? 'unknown'}';
      detailText.value =
          'Active: ${data['is_active'] == true} · Readonly: ${data['is_readonly'] == true}';
      if (Get.isRegistered<SubscriptionStore>()) {
        // Keep store loosely in sync for banners.
      }
    } on DioException catch (e) {
      final snap = Get.isRegistered<SubscriptionStore>()
          ? Get.find<SubscriptionStore>().snapshot.value
          : null;
      if (snap != null) {
        statusText.value = snap.status;
        detailText.value =
            snap.message ??
            'Active: ${snap.isActive} · Readonly: ${snap.isReadonly}';
      } else {
        statusText.value = 'Unavailable';
        detailText.value = e.message ?? 'Could not load subscription';
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> copyBillingLink() async {
    await Clipboard.setData(
      ClipboardData(text: AppConstants.billingBaseUrl),
    );
    Get.snackbar(
      'Billing',
      'Landing billing URL copied. Complete checkout there.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

class AdminBillingView extends GetView<AdminBillingController> {
  const AdminBillingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
        title: const Text('Billing'),
        backgroundColor: AppColors.darkBrown,
        actions: [
          IconButton(
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Status: ${controller.statusText.value}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(controller.detailText.value),
              const SizedBox(height: 24),
              const Text(
                'Checkout and plan changes run on the landing billing page '
                '(GoCardless hosted flow).',
              ),
              const SizedBox(height: 12),
              SelectableText(AppConstants.billingBaseUrl),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.copyBillingLink,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy billing link'),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class AdminAuditBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AdminOpsListController(
        dio: Get.find<AttendanceApiClient>().dio,
        title: 'Security audit',
        path: '${AppConstants.apiV1}/auth/audit/events',
        query: const {'limit': 50},
        itemBuilder: (row) =>
            '${row['action'] ?? '?'} · ${row['created_at'] ?? ''}',
      ),
    );
  }
}

class AdminNotificationsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AdminOpsListController(
        dio: Get.find<AttendanceApiClient>().dio,
        title: 'Notifications',
        path: '${AppConstants.apiV1}/notifications/events',
        itemBuilder: (row) =>
            '${row['event_type'] ?? row['title'] ?? '?'} · ${row['created_at'] ?? ''}',
      ),
    );
  }
}

class AdminGeofenceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AdminOpsListController(
        dio: Get.find<AttendanceApiClient>().dio,
        title: 'Geofence zones',
        path: '${AppConstants.apiV1}/geofence/zones',
        itemBuilder: (row) => '${row['name'] ?? row['id'] ?? '?'}',
      ),
    );
  }
}

class AdminBillingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AdminBillingController(
        dio: Get.find<AttendanceApiClient>().dio,
      ),
    );
  }
}
