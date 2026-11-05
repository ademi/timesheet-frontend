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
import '../../../engagements/data/repositories/engagements_repository.dart';
import '../data/models/xero_models.dart';
import '../data/repositories/xero_repository.dart';

class XeroContractorMapRow {
  const XeroContractorMapRow({
    required this.contractorId,
    required this.displayName,
    this.needsMap = false,
  });

  final String contractorId;
  final String displayName;
  final bool needsMap;
}

class XeroSettingsController extends GetxController {
  XeroSettingsController({
    required XeroRepository xero,
    required SessionService session,
    required EngagementsRepository engagements,
  }) : _xero = xero,
       _session = session,
       _engagements = engagements;

  final XeroRepository _xero;
  final SessionService _session;
  final EngagementsRepository _engagements;

  final isLoading = false.obs;
  final isConnecting = false.obs;
  final isDisconnecting = false.obs;
  final isMappingLoading = false.obs;
  final isSavingEmployees = false.obs;
  final isSavingPayItems = false.obs;
  final errorMessage = RxnString();
  final status = Rxn<XeroConnectionStatus>();

  final xeroEmployees = <XeroEmployee>[].obs;
  final xeroEarningsRates = <XeroEarningsRate>[].obs;
  final contractorRows = <XeroContractorMapRow>[].obs;

  /// contractor_id → selected xero_employee_id (null = unmapped)
  final employeeSelection = <String, String?>{}.obs;

  /// band_key → selected xero_earnings_rate_id (null = unmapped)
  final payItemSelection = <String, String?>{}.obs;

  /// Last saved selections — used to show pending (unsaved) picks in the UI.
  final employeeBaseline = <String, String?>{}.obs;
  final payItemBaseline = <String, String?>{}.obs;

  bool get canManageXero =>
      _session.hasPermission(AppPermissions.integrationsXeroManage);

  bool get featureEnabled => status.value?.featureEnabled ?? true;

  bool get isConnected => status.value?.connected ?? false;

  bool get mappingIncomplete =>
      isConnected && status.value?.mappingComplete == false;

  List<String> get unmappedContractorIds =>
      status.value?.unmappedContractorIds ?? const [];

  List<String> get unmappedBandKeys =>
      status.value?.unmappedBandKeys ?? const [];

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
    if (isConnected) {
      await loadMappingData();
    } else {
      _clearMappingCatalogues();
    }
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

  Future<void> loadMappingData() async {
    if (!canManageXero || !isConnected) return;
    isMappingLoading.value = true;
    try {
      // Keep required unmapped ids in sync with batch activity (no full-page spinner).
      try {
        status.value = await _xero.getStatus();
      } catch (_) {
        // Keep prior status; mapping catalogues can still load.
      }
      final results = await Future.wait([
        _xero.listEmployees(),
        _xero.listEarningsRates(),
        _xero.getEmployeeMappings(),
        _xero.getPayItemMappings(),
        _safeListEngagements(),
      ]);

      final employees = results[0] as List<XeroEmployee>;
      final rates = results[1] as List<XeroEarningsRate>;
      final empMaps = results[2] as XeroEmployeeMappingsOut;
      final payMaps = results[3] as XeroPayItemMappingsOut;
      final nameByContractor = results[4] as Map<String, String>;

      xeroEmployees.assignAll(employees);
      xeroEarningsRates.assignAll(rates);

      final mappedIds = {
        for (final row in empMaps.employees) row.contractorId: row.xeroEmployeeId,
      };
      final ids = <String>{
        ...nameByContractor.keys,
        ...mappedIds.keys,
        ...unmappedContractorIds,
      };

      final rows =
          ids.map((id) {
            final name = nameByContractor[id];
            return XeroContractorMapRow(
              contractorId: id,
              displayName:
                  (name != null && name.isNotEmpty)
                      ? name
                      : 'Worker (${id.length > 8 ? id.substring(0, 8) : id})',
              needsMap: unmappedContractorIds.contains(id),
            );
          }).toList()..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );

      contractorRows.assignAll(rows);
      final empSel = {for (final id in ids) id: mappedIds[id]};
      employeeSelection
        ..clear()
        ..addAll(empSel);
      employeeBaseline
        ..clear()
        ..addAll(empSel);

      final paySel = <String, String?>{
        for (final key in XeroBandKeys.all) key: null,
      };
      for (final row in payMaps.payItems) {
        paySel[row.bandKey] = row.xeroEarningsRateId;
      }
      payItemSelection
        ..clear()
        ..addAll(paySel);
      payItemBaseline
        ..clear()
        ..addAll(paySel);
    } on AppFailure catch (e) {
      AppToast.error('Xero mapping', _friendlyError(e));
    } catch (_) {
      AppToast.error('Xero mapping', 'Could not load mapping data.');
    } finally {
      isMappingLoading.value = false;
    }
  }

  void setEmployeeMapping(String contractorId, String? xeroEmployeeId) {
    employeeSelection[contractorId] = xeroEmployeeId;
    employeeSelection.refresh();
  }

  void setPayItemMapping(String bandKey, String? earningsRateId) {
    payItemSelection[bandKey] = earningsRateId;
    payItemSelection.refresh();
  }

  bool isEmployeeMappingPending(String contractorId) =>
      employeeSelection[contractorId] != employeeBaseline[contractorId];

  bool isPayItemMappingPending(String bandKey) =>
      payItemSelection[bandKey] != payItemBaseline[bandKey];

  bool get hasPendingEmployeeMappings => employeeSelection.keys.any(
    isEmployeeMappingPending,
  );

  bool get hasPendingPayItemMappings =>
      XeroBandKeys.all.any(isPayItemMappingPending);

  Future<void> saveEmployeeMappings() async {
    if (!canManageXero || isSavingEmployees.value) return;
    isSavingEmployees.value = true;
    try {
      final body = XeroEmployeeMappingsOut(
        employees:
            employeeSelection.entries
                .where((e) => e.value != null && e.value!.isNotEmpty)
                .map(
                  (e) => XeroEmployeeMapRow(
                    contractorId: e.key,
                    xeroEmployeeId: e.value!,
                  ),
                )
                .toList(growable: false),
      );
      await _xero.putEmployeeMappings(body);
      await loadStatus();
      await loadMappingData();
      AppToast.success('Saved', 'Worker → Xero employee mappings updated.');
    } on AppFailure catch (e) {
      AppToast.error('Xero mapping', _friendlyError(e));
    } catch (_) {
      AppToast.error('Xero mapping', 'Could not save employee mappings.');
    } finally {
      isSavingEmployees.value = false;
    }
  }

  Future<void> savePayItemMappings() async {
    if (!canManageXero || isSavingPayItems.value) return;
    isSavingPayItems.value = true;
    try {
      final body = XeroPayItemMappingsOut(
        payItems:
            payItemSelection.entries
                .where((e) => e.value != null && e.value!.isNotEmpty)
                .map(
                  (e) => XeroPayItemMapRow(
                    bandKey: e.key,
                    xeroEarningsRateId: e.value!,
                  ),
                )
                .toList(growable: false),
      );
      await _xero.putPayItemMappings(body);
      await loadStatus();
      await loadMappingData();
      AppToast.success('Saved', 'Pay band → Xero earnings rate mappings updated.');
    } on AppFailure catch (e) {
      AppToast.error('Xero mapping', _friendlyError(e));
    } catch (_) {
      AppToast.error('Xero mapping', 'Could not save pay-item mappings.');
    } finally {
      isSavingPayItems.value = false;
    }
  }

  Future<void> openXeroInBrowser() =>
      openExternalUrl('https://go.xero.com/');

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
      _clearMappingCatalogues();
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

  void _clearMappingCatalogues() {
    xeroEmployees.clear();
    xeroEarningsRates.clear();
    contractorRows.clear();
    employeeSelection.clear();
    payItemSelection.clear();
    employeeBaseline.clear();
    payItemBaseline.clear();
  }

  Future<Map<String, String>> _safeListEngagements() async {
    try {
      final list = await _engagements.listTenantEngagements();
      final byId = <String, String>{};
      for (final e in list) {
        if (e.isEnded) continue;
        byId.putIfAbsent(e.contractorId, () => e.displayName);
      }
      return byId;
    } catch (_) {
      return {};
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
      AppToast.error('Xero connection failed', _friendlyOAuthCode(code));
    }

    AppNavigator.replace(AppRoutes.staffXeroSettings);
  }

  static Future<bool> _openAuthorizeUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (kIsWeb) {
      try {
        // New tab keeps the Flutter debug session intact; `_self` often freezes
        // Xero login when DWDS/debugger is attached to the same tab.
        return await launchUrl(uri, webOnlyWindowName: '_blank');
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
      case 'xero_not_connected':
        return 'Connect Xero before loading employees or earnings rates.';
      case 'xero_duplicate_contractor_map':
      case 'xero_duplicate_employee_map':
        return 'Each worker and each Xero employee can only be mapped once.';
      case 'xero_duplicate_band_map':
        return 'Each pay band can only be mapped once.';
      case 'xero_invalid_band_key':
        return 'One of the pay band keys is not allowed.';
      case 'xero_contractor_not_in_tenant':
        return 'A mapped worker is not on this organisation.';
      case 'xero_employees_failed':
        return 'Could not load Xero employees. Try again or check Payroll in Xero.';
      case 'xero_earnings_rates_failed':
        return 'Could not load Xero earnings rates. Try again or check Payroll in Xero.';
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
