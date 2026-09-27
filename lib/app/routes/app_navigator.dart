import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

/// Platform-aware navigation facade.
///
/// - **Web:** delegates to [GoRouter] (bound via [bindWebRouter]).
/// - **Mobile:** delegates to GetX named routes.
///
/// Feature code should prefer this over raw `Get.toNamed` / `context.go` so
/// both platforms stay aligned on the same path strings ([AppRoutes]).
class AppNavigator {
  AppNavigator._();

  static GoRouter? _webRouter;

  /// Called once from web bootstrap after [GoRouter] is created.
  static void bindWebRouter(GoRouter router) {
    _webRouter = router;
  }

  @visibleForTesting
  static void debugUnbindWebRouter() {
    _webRouter = null;
  }

  static bool get usesGoRouter => _webRouter != null;

  static GoRouter get _router {
    final r = _webRouter;
    if (r == null) {
      throw StateError('AppNavigator.bindWebRouter was not called on web.');
    }
    return r;
  }

  /// Replaces the stack with [location] (login, logout, post-auth home).
  static void offAll(String location, {Object? extra}) {
    final uri = _uri(location);
    if (usesGoRouter) {
      _router.go(uri.toString(), extra: extra);
      return;
    }
    Get.offAllNamed(
      uri.path,
      arguments: extra,
      parameters: _params(uri),
    );
  }

  /// Navigates to [location], replacing the current entry when possible.
  static void go(String location, {Object? extra}) {
    final uri = _uri(location);
    if (usesGoRouter) {
      _router.go(uri.toString(), extra: extra);
      return;
    }
    Get.offNamed(
      uri.path,
      arguments: extra,
      parameters: _params(uri),
    );
  }

  /// Pushes [location] onto the stack.
  static Future<T?> push<T extends Object?>(
    String location, {
    Object? extra,
  }) async {
    final uri = _uri(location);
    if (usesGoRouter) {
      return _router.push<T>(uri.toString(), extra: extra);
    }
    final result = await Get.toNamed(
      uri.path,
      arguments: extra,
      parameters: _params(uri),
    );
    return result is T ? result : null;
  }

  /// Replaces the current route with [location].
  static void replace(String location, {Object? extra}) {
    final uri = _uri(location);
    if (usesGoRouter) {
      _router.replace(uri.toString(), extra: extra);
      return;
    }
    Get.offNamed(
      uri.path,
      arguments: extra,
      parameters: _params(uri),
    );
  }

  static void pop<T extends Object?>([T? result]) {
    if (usesGoRouter) {
      if (_router.canPop()) {
        _router.pop(result);
      }
      return;
    }
    Get.back(result: result);
  }

  /// Pops when possible; otherwise navigates to [parentLocation].
  static void backOrToParent(String parentLocation) {
    if (usesGoRouter) {
      if (_router.canPop()) {
        _router.pop();
      } else {
        _router.go(_uri(parentLocation).toString());
      }
      return;
    }
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
    } else {
      final uri = _uri(parentLocation);
      Get.offNamed(uri.path, parameters: _params(uri));
    }
  }

  static String get currentLocation {
    if (usesGoRouter) {
      return _router.routerDelegate.currentConfiguration.uri.toString();
    }
    return Get.currentRoute;
  }

  static Map<String, String> get queryParameters {
    if (usesGoRouter) {
      return Map<String, String>.from(
        _router.routerDelegate.currentConfiguration.uri.queryParameters,
      );
    }
    return Map<String, String>.from(Get.parameters);
  }

  static Uri _uri(String location) {
    final raw = location.startsWith('/') ? location : '/$location';
    return Uri.parse(raw);
  }

  static Map<String, String>? _params(Uri uri) =>
      uri.queryParameters.isEmpty
          ? null
          : Map<String, String>.from(uri.queryParameters);
}
