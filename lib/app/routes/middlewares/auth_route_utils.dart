import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../../features/shell/contractor_shell.dart';
import '../../../features/shell/staff_shell.dart';
import '../../../shared/widgets/app_toast.dart';
import '../app_routes.dart';

/// Redirects to gateway only when there are no credentials to recover with.
///
/// Expired or missing access tokens are allowed through when a refresh token
/// exists; [AuthInterceptor] refreshes on the next API 401.
RouteSettings? redirectWhenUnauthenticated() {
  if (!Get.isRegistered<TokenStorage>()) {
    return const RouteSettings(name: AppRoutes.gateway);
  }
  if (!Get.find<TokenStorage>().canAttemptAuth) {
    return const RouteSettings(name: AppRoutes.gateway);
  }
  return null;
}

/// Forces first-login when JWT claims require a password change.
RouteSettings? redirectWhenMustChangePassword(String? route) {
  if (!Get.isRegistered<TokenStorage>()) return null;
  final claims = Get.find<TokenStorage>().jwtClaims;
  if (claims?.mustChangePassword == true && route != AppRoutes.firstLogin) {
    return const RouteSettings(name: AppRoutes.firstLogin);
  }
  return null;
}

/// Staff vs contractor shell mismatch → wrong-actor screen.
///
/// [actorType] is typically `tenant_member` or `contractor`.
RouteSettings? redirectWrongActor({
  required String? route,
  required String? actorType,
}) {
  if (route == null || actorType == null) return null;

  if (isStaffRoute(route) && actorType != 'tenant_member') {
    return const RouteSettings(name: AppRoutes.wrongActor);
  }

  final contractorProtected =
      isContractorShellRoute(route) ||
      (route.startsWith(AppRoutes.contractorOnboarding) ||
          route == AppRoutes.contractorCompleteAccount);
  if (contractorProtected && actorType != 'contractor') {
    return const RouteSettings(name: AppRoutes.wrongActor);
  }

  return null;
}

/// Permission check (`anyOf` / `allOf`). On failure → shell home (+ optional toast).
RouteSettings? redirectMissingPermission({
  required String? route,
  List<String> anyOf = const [],
  List<String> allOf = const [],
  bool showToast = true,
}) {
  if (anyOf.isEmpty && allOf.isEmpty) return null;

  final allowed = _permissionAllowed(anyOf: anyOf, allOf: allOf);
  if (allowed == null) {
    // Session not ready but credentials exist — allow; API/AuthInterceptor will gate.
    return null;
  }
  if (allowed) return null;

  if (showToast) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppToast.error(
        'Permission required',
        'You don’t have access to that area.',
        duration: const Duration(seconds: 3),
      );
    });
  }
  final home =
      isStaffRoute(route) ? AppRoutes.staffHome : AppRoutes.contractorHome;
  return RouteSettings(name: home);
}

/// `true` / `false` when a decision can be made; `null` when auth is recoverable
/// but permissions are not loaded yet (allow through).
bool? _permissionAllowed({
  required List<String> anyOf,
  required List<String> allOf,
}) {
  if (!Get.isRegistered<SessionService>()) {
    if (!Get.isRegistered<TokenStorage>()) return false;
    final storage = Get.find<TokenStorage>();
    if (!storage.canAttemptAuth) return false;
    final claims = storage.jwtClaims;
    if (claims == null) return null;
    return _checkClaims(claims.hasPermission, anyOf: anyOf, allOf: allOf);
  }

  final session = Get.find<SessionService>();
  return allOf.isNotEmpty ? session.hasAll(allOf) : session.hasAny(anyOf);
}

bool _checkClaims(
  bool Function(String) has, {
  required List<String> anyOf,
  required List<String> allOf,
}) {
  bool isSuper() => has('*') || has('platform.admin');
  if (allOf.isNotEmpty) {
    for (final p in allOf) {
      if (!has(p) && !isSuper()) return false;
    }
    return true;
  }
  for (final p in anyOf) {
    if (has(p) || isSuper()) return true;
  }
  return anyOf.isEmpty;
}

/// Path-only form of a location (`/staff/clients/detail?id=x` → `/staff/clients/detail`).
String locationPath(String location) {
  final trimmed = location.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.path.isNotEmpty) return uri.path;
  final q = trimmed.indexOf('?');
  return q < 0 ? trimmed : trimmed.substring(0, q);
}

/// Entry locations where an authenticated session resume should navigate away
/// (gateway / empty). Deep links must not be overridden after hydrate.
bool isUnauthenticatedEntryLocation(String? location) {
  final path = locationPath(location ?? '');
  return path.isEmpty || path == '/' || path == AppRoutes.gateway;
}

/// Current app entry location for session-resume decisions.
///
/// On web, [Uri.base] is the source of truth after a browser refresh (GetX
/// routing may not have settled when [GatewayController] runs). On mobile the
/// cold-start path is the GetX current route (normally gateway).
String currentEntryLocation({String? override}) {
  if (override != null) return override;
  if (kIsWeb) {
    final path = Uri.base.path;
    if (path.isEmpty || path == '/') return AppRoutes.gateway;
    return path;
  }
  final current = Get.currentRoute;
  if (current.isEmpty || current == '/') return AppRoutes.gateway;
  return locationPath(current);
}

/// Whether [GatewayController] may `offAllNamed` to the post-login home.
bool shouldNavigateAfterSessionResume({String? entryLocation}) {
  return isUnauthenticatedEntryLocation(
    currentEntryLocation(override: entryLocation),
  );
}

/// Non-empty query/path parameter helper shared by hydrate-from-route call sites.
String? routeParam(String key) {
  final value = Get.parameters[key];
  if (value == null || value.isEmpty) return null;
  return value;
}
