import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/token_storage.dart';
import '../../subscription/billing_gate.dart';
import '../data/datasources/compliance_ops_remote_datasource.dart';
import '../data/models/compliance_ops_models.dart';
import '../data/models/notification_display.dart';
import '../data/repositories/compliance_ops_repository.dart';

/// App-wide notification events feed (AppBar bell).
class NotificationsFeedController extends GetxController {
  NotificationsFeedController({
    required ComplianceOpsRepository repository,
  }) : _repository = repository;

  final ComplianceOpsRepository _repository;

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final events = <NotificationEventOut>[].obs;
  final acknowledgedCount = 0.obs;

  int get badgeCount {
    final unread = events.length - acknowledgedCount.value;
    return unread < 0 ? 0 : unread;
  }

  /// Ensures a long-lived feed controller for shell AppBars.
  static void ensureRegistered() {
    if (!Get.isRegistered<TokenStorage>()) {
      Get.put<TokenStorage>(TokenStorage(), permanent: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(Get.find<TokenStorage>()), permanent: true);
    }
    if (!Get.isRegistered<ComplianceOpsRemoteDataSource>()) {
      Get.lazyPut<ComplianceOpsRemoteDataSource>(
        () => ComplianceOpsRemoteDataSource(
          authenticatedDio: Get.find<ApiClient>().dio,
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<ComplianceOpsRepository>()) {
      Get.lazyPut<ComplianceOpsRepository>(
        () => ComplianceOpsRepository(
          remote: Get.find<ComplianceOpsRemoteDataSource>(),
        ),
        fenix: true,
      );
    }
    if (!Get.isRegistered<NotificationsFeedController>()) {
      Get.put(
        NotificationsFeedController(
          repository: Get.find<ComplianceOpsRepository>(),
        ),
        permanent: true,
      );
    }
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  static const _cacheTtl = Duration(seconds: 45);
  DateTime? _lastLoadedAt;
  Future<void>? _loadInFlight;

  bool get _isFresh =>
      _lastLoadedAt != null &&
      DateTime.now().difference(_lastLoadedAt!) < _cacheTtl;

  Future<void> load({bool force = false}) async {
    if (_loadInFlight != null) return _loadInFlight!;
    if (!force && _isFresh) return;

    final future = _loadBody();
    _loadInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    }
  }

  Future<void> _loadBody() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final raw = await _repository.listNotificationEvents(limit: 50);
      events.assignAll(dedupeNotificationEvents(raw));
      if (acknowledgedCount.value > events.length) {
        acknowledgedCount.value = events.length;
      }
      _lastLoadedAt = DateTime.now();
    } on AppFailure catch (e) {
      await BillingGate.showIfNeeded(e);
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void markOpened() {
    acknowledgedCount.value = events.length;
  }
}
