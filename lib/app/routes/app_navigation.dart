import 'package:get/get.dart';

/// Pops the current route when possible, otherwise navigates to [parentRoute].
///
/// This is the navigation-stack analogue of [AppBackButton]. On web a browser
/// refresh rebuilds the GetX stack with only the current route, so a plain
/// `Get.back()` becomes a no-op (nothing to pop). Deep screens that carry their
/// state via in-memory `Get.arguments` also lose that state on refresh; rather
/// than stranding the user on a broken screen with a dead back action, this seeds
/// the logical parent route so the user lands somewhere valid with a working back
/// button. On mobile (and whenever a real stack exists) it behaves exactly like
/// `Get.back()`.
void backOrToParent(String parentRoute) {
  if (Get.key.currentState?.canPop() ?? false) {
    Get.back();
  } else {
    Get.offNamed(parentRoute);
  }
}

/// Coerces a route pop result to [bool].
bool readBoolResult(dynamic result) => result == true;

/// Coerces a route pop result to [T] when the runtime type matches.
T? readTypedResult<T>(dynamic result) => result is T ? result : null;

/// Pushes a named route. Do not use [Get.toNamed] with a type argument on web —
/// it can throw because [GetPageRoute] is not a subtype of [Route<T>].
Future<dynamic>? pushNamed(String route, {dynamic arguments}) {
  return Get.toNamed(route, arguments: arguments);
}

/// Returns whether the pushed route completed with `true`.
Future<bool> pushNamedBool(String route, {dynamic arguments}) async {
  final result = await Get.toNamed(route, arguments: arguments);
  return readBoolResult(result);
}

/// Returns the result of a pushed route when it matches [T].
Future<T?> pushNamedResult<T>(String route, {dynamic arguments}) async {
  final result = await Get.toNamed(route, arguments: arguments);
  return readTypedResult<T>(result);
}
