export 'app_navigator.dart' show AppNavigator;

import 'app_navigator.dart';

/// Pops the current route when possible, otherwise navigates to [parentRoute].
///
/// This is the navigation-stack analogue of [AppBackButton]. On web a browser
/// refresh rebuilds the stack with only the current route, so a plain pop
/// becomes a no-op. Deep screens that carry state via in-memory arguments also
/// lose that state on refresh; rather than stranding the user on a broken
/// screen with a dead back action, this seeds the logical parent route.
///
/// Delegates to [AppNavigator] so web (go_router) and mobile (GetX) stay aligned.
void backOrToParent(String parentRoute) {
  AppNavigator.backOrToParent(parentRoute);
}

/// Coerces a route pop result to [bool].
bool readBoolResult(dynamic result) => result == true;

/// Coerces a route pop result to [T] when the runtime type matches.
T? readTypedResult<T>(dynamic result) => result is T ? result : null;

/// Pushes a named route. Do not use [Get.toNamed] with a type argument on web —
/// it can throw because [GetPageRoute] is not a subtype of [Route<T>].
Future<dynamic>? pushNamed(String route, {dynamic arguments}) {
  return AppNavigator.push(route, extra: arguments);
}

/// Returns whether the pushed route completed with `true`.
Future<bool> pushNamedBool(String route, {dynamic arguments}) async {
  final result = await AppNavigator.push(route, extra: arguments);
  return readBoolResult(result);
}

/// Returns the result of a pushed route when it matches [T].
Future<T?> pushNamedResult<T>(String route, {dynamic arguments}) async {
  final result = await AppNavigator.push(route, extra: arguments);
  return readTypedResult<T>(result);
}
