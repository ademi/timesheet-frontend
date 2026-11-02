import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/constants/app_permissions.dart';
import '../../../../app/routes/app_navigator.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../app/routes/middlewares/auth_route_utils.dart';
import '../../../../app/themes/app_colors.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/session_service.dart';
import '../../../../shared/utils/external_url.dart';
import '../../../../shared/utils/humanize_label.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../data/models/xero_models.dart';
import '../data/repositories/xero_repository.dart';

class XeroSettingsController extends GetxController {
  XeroSettingsController({
    required XeroRepository xero,
    required SessionService session,
  }) : _xero = xero,
       _session = session;

  final XeroRepository _xero;
  final SessionService _session;

  final isLoading = false.obs;
  final isConnecting = false.obs;
  final isDisconnecting = false.obs;
  final errorMessage = RxnString();
  final status = Rxn<XeroConnectionStatus>();

  bool get canManageXero =>
      _session.hasPermission(AppPermissions.integrationsXeroManage);

  bool get featureEnabled => status.value?.featureEnabled ?? true;

  bool get isConnected => status.value?.connected ?? false;

  @override
  void onInit() {
    super.onInit();
    // ignore: discarded_futures
    _bootstrap();
  }

  void onScreenReenter() {
    // ignore: discarded_futures
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await loadStatus();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      _consumeOAuthReturnQuery();
    });
  }

  Future<void> loadStatus() async {
    if (!canManageXero) {
      errorMessage.value = 'You don’t have permission to manage Xero.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      status.value = await _xero.getStatus();
    } on AppFailure catch (e) {
      if (e.code == 'xero_feature_disabled') {
        status.value = const XeroConnectionStatus(
          featureEnabled: false,
          connected: false,
          status: 'disconnected',
        );
      } else {
        errorMessage.value = e.message;
        AppToast.error('Xero', e.message);
      }
    } catch (_) {
      errorMessage.value = 'Could not load Xero connection status.';
      AppToast.error('Xero', errorMessage.value!);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> connect() async {
    if (!canManageXero || !featureEnabled || isConnecting.value) return;
    isConnecting.value = true;
    try {
      final auth = await _xero.getAuthUrl();
      if (auth.authorizeUrl.isEmpty) {
        AppToast.error('Xero', 'No authorize URL returned.');
        return;
      }
      final opened = await _openAuthorizeUrl(auth.authorizeUrl);
      if (!opened) {
        AppToast.error('Xero', 'Could not open the Xero consent page.');
      }
    } on AppFailure catch (e) {
      AppToast.error('Xero', _friendlyError(e));
    } catch (_) {
      AppToast.error('Xero', 'Could not start Xero connection.');
    } finally {
      isConnecting.value = false;
    }
  }

  Future<void> disconnect() async {
    if (!canManageXero || !isConnected || isDisconnecting.value) return;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Disconnect Xero?'),
        content: const Text(
          'This clears the connection for this organisation. '
          'Employee and pay-item mappings are kept. '
          'Payment batches in Rostiq are unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    isDisconnecting.value = true;
    try {
      await _xero.disconnect();
      await loadStatus();
      AppToast.success(
        'Xero disconnected',
        'Mappings were kept. You can reconnect anytime.',
      );
    } on AppFailure catch (e) {
      AppToast.error('Xero', _friendlyError(e));
    } catch (_) {
      AppToast.error('Xero', 'Could not disconnect Xero.');
    } finally {
      isDisconnecting.value = false;
    }
  }

  void _consumeOAuthReturnQuery() {
    final xero =
        routeParam('xero') ??
        AppNavigator.queryParameters['xero'] ??
        Get.parameters['xero'];
    if (xero == null || xero.isEmpty) return;

    final code =
        routeParam('code') ??
        AppNavigator.queryParameters['code'] ??
        Get.parameters['code'];

    if (xero == 'connected') {
      AppToast.success(
        'Xero connected',
        'You can map workers and pay items, then Send to Xero from Payments.',
      );
    } else if (xero == 'error') {
      AppToast.error(
        'Xero connection failed',
        _friendlyOAuthCode(code),
      );
    }

    // Strip query so a refresh does not re-toast.
    AppNavigator.replace(AppRoutes.staffXeroSettings);
  }

  static Future<bool> _openAuthorizeUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (kIsWeb) {
      try {
        return await launchUrl(uri, webOnlyWindowName: '_self');
      } catch (_) {
        return false;
      }
    }
    return openExternalUrl(url);
  }

  static String _friendlyError(AppFailure e) {
    switch (e.code) {
      case 'xero_not_configured':
        return 'Xero is not configured on this environment yet.';
      case 'xero_feature_disabled':
        return 'Xero integration is turned off for this environment.';
      case 'xero_oauth_denied':
        return 'Xero consent was denied.';
      case 'xero_token_exchange_failed':
        return 'Could not complete Xero sign-in. Try again.';
      case 'xero_no_organisation':
        return 'No Xero organisation was authorised.';
      default:
        return e.message.isNotEmpty ? e.message : humanizeLabel(e.code);
    }
  }

  static String _friendlyOAuthCode(String? code) {
    if (code == null || code.isEmpty) {
      return 'Something went wrong connecting to Xero. Try again.';
    }
    switch (code) {
      case 'xero_oauth_denied':
        return 'You denied access in Xero. No connection was saved.';
      case 'xero_oauth_state_invalid':
      case 'xero_oauth_state_expired':
      case 'xero_oauth_state_missing':
        return 'The connection link expired or was invalid. Try Connect again.';
      case 'xero_oauth_code_missing':
        return 'Xero did not return an authorisation code. Try again.';
      case 'xero_token_exchange_failed':
        return 'Could not complete Xero sign-in. Try again.';
      case 'xero_no_organisation':
        return 'No Xero organisation was authorised. Pick Demo Company (AU) for tests.';
      case 'xero_not_configured':
        return 'Xero is not configured on this environment yet.';
      case 'xero_feature_disabled':
        return 'Xero integration is turned off for this environment.';
      default:
        return humanizeLabel(code);
    }
  }
}
