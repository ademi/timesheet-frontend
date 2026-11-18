import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../core/services/session_service.dart';
import '../../core/services/token_storage.dart';
import '../../shared/widgets/app_toast.dart';
import '../auth/landing_auth_handoff.dart';
import '../routes/app_navigator.dart';
import '../routes/app_routes.dart';
import '../routes/browser_url.dart';
import '../services/push_notification_service.dart';

/// Consumes landing-page hash tokens on `/admin-panel` or `/change-password`.
class LandingAuthHandoffController extends GetxController {
  LandingAuthHandoffController({
    TokenStorage? tokenStorage,
    SessionService? sessionService,
    @visibleForTesting String? fragmentOverride,
    @visibleForTesting String? pathOverride,
    @visibleForTesting void Function(String location)? navigateOverride,
  }) : _tokenStorage = tokenStorage,
       _sessionService = sessionService,
       _fragmentOverride = fragmentOverride,
       _pathOverride = pathOverride,
       _navigateOverride = navigateOverride;

  final TokenStorage? _tokenStorage;
  final SessionService? _sessionService;
  final String? _fragmentOverride;
  final String? _pathOverride;
  final void Function(String location)? _navigateOverride;

  final isWorking = true.obs;
  final errorMessage = RxnString();

  TokenStorage get _storage =>
      _tokenStorage ?? Get.find<TokenStorage>();

  SessionService get _session =>
      _sessionService ?? Get.find<SessionService>();

  @override
  void onReady() {
    super.onReady();
    _run();
  }

  @visibleForTesting
  Future<void> runForTest() => _run();

  Future<void> _run() async {
    isWorking.value = true;
    errorMessage.value = null;
    try {
      final path = _pathOverride ??
          (kIsWeb ? Uri.base.path : AppNavigator.currentLocation);
      final fragment =
          _fragmentOverride ?? (kIsWeb ? Uri.base.fragment : '');

      final handoff = parseLandingAuthHandoffFragment(fragment);
      if (handoff == null) {
        await _resumeWithoutHandoff(path);
        return;
      }

      // Strip secrets from the address bar before any further navigation.
      if (kIsWeb) {
        replaceBrowserUrl(path, const {});
      }

      await _session.clear();
      await _storage.clear();
      await _storage.persist(
        accessToken: handoff.accessToken,
        refreshToken: handoff.refreshToken,
      );
      await _session.applyAuthTokens(handoff.toAuthTokens());

      final tenantId = handoff.tenantId ?? _storage.jwtClaims?.tenantId;
      if (tenantId != null && tenantId.isNotEmpty) {
        await _storage.persistLastTenantSelection(tenantId: tenantId);
      }

      try {
        await _session.hydrateFromMeContext();
      } catch (_) {
        // JWT claims are enough to reach staff/contractor home; me/context
        // can retry on the next authenticated screen.
      }

      if (Get.isRegistered<PushNotificationService>()) {
        await Get.find<PushNotificationService>().registerCurrentDeviceToken();
      }

      final dest = _destinationFor(path: path, handoff: handoff);
      _go(dest);
    } catch (e) {
      errorMessage.value = 'Could not open your dashboard. Please sign in.';
      AppToast.error('Sign-in handoff failed', errorMessage.value!);
      _go(AppRoutes.login);
    } finally {
      isWorking.value = false;
    }
  }

  void _go(String location) {
    final override = _navigateOverride;
    if (override != null) {
      override(location);
      return;
    }
    AppNavigator.offAll(location);
  }

  Future<void> _resumeWithoutHandoff(String path) async {
    if (_storage.canAttemptAuth) {
      try {
        await _session.hydrateFromMeContext();
      } catch (_) {
        // Fall through to resolvePostLoginRoute / login.
      }
      final dest = path == AppRoutes.changePassword
          ? AppRoutes.firstLogin
          : _session.resolvePostLoginRoute();
      if (dest == AppRoutes.login || dest == AppRoutes.gateway) {
        _go(AppRoutes.login);
        return;
      }
      _go(dest);
      return;
    }

    errorMessage.value = 'Missing sign-in details. Please sign in.';
    _go(AppRoutes.login);
  }

  String _destinationFor({
    required String path,
    required LandingAuthHandoff handoff,
  }) {
    if (path == AppRoutes.changePassword ||
        handoff.adminMustChangePassword ||
        _session.mustChangePassword.value ||
        (_storage.jwtClaims?.mustChangePassword ?? false)) {
      return AppRoutes.firstLogin;
    }
    return _session.resolvePostLoginRoute();
  }
}
