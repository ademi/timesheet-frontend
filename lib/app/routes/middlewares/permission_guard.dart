import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/services/session_service.dart';
import '../../../core/services/token_storage.dart';
import '../../../features/shell/staff_shell.dart';
import '../../../shared/widgets/app_toast.dart';
import '../app_routes.dart';

/// Route permission check (`anyOf` or `allOf`). On failure → shell home + snackbar.
class PermissionGuard extends GetMiddleware {
  PermissionGuard({
    this.anyOf = const [],
    this.allOf = const [],
  });

  final List<String> anyOf;
  final List<String> allOf;

  @override
  RouteSettings? redirect(String? route) {
    if (anyOf.isEmpty && allOf.isEmpty) return null;

    if (!Get.isRegistered<SessionService>()) {
      final storage = Get.find<TokenStorage>();
      if (!storage.canAttemptAuth) {
        return const RouteSettings(name: AppRoutes.gateway);
      }
      final claims = storage.jwtClaims;
      if (claims == null) {
        // Access token absent; refresh token will be used by AuthInterceptor.
        return null;
      }
      final ok = _checkClaims(claims.hasPermission);
      if (!ok) return _deny(route);
      return null;
    }

    final session = Get.find<SessionService>();
    final ok = allOf.isNotEmpty
        ? session.hasAll(allOf)
        : session.hasAny(anyOf);
    if (!ok) return _deny(route);
    return null;
  }

  bool _checkClaims(bool Function(String) has) {
    if (allOf.isNotEmpty) {
      for (final p in allOf) {
        if (!has(p) && !_isSuper(has)) return false;
      }
      return true;
    }
    for (final p in anyOf) {
      if (has(p) || _isSuper(has)) return true;
    }
    return anyOf.isEmpty;
  }

  bool _isSuper(bool Function(String) has) =>
      has('*') || has('platform.admin');

  RouteSettings _deny(String? route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppToast.error(
        'Permission required',
        'You don’t have access to that area.',
        duration: const Duration(seconds: 3),
      );
    });
    final home = isStaffRoute(route)
        ? AppRoutes.staffHome
        : AppRoutes.contractorHome;
    return RouteSettings(name: home);
  }
}
