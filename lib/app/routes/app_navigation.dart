import 'package:get/get.dart';

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
