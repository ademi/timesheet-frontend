import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

/// Copies GoRouter path + query params into [Get.parameters] so existing
/// hydrate helpers ([routeParam], bindings) keep working on web.
///
/// Replaces prior keys rather than merging — otherwise sticky `id` /
/// `clientId` from a previous route rehydrate the wrong entity on the next
/// push (e.g. roster FAB → composer still opens the last shift).
void syncGetxFromGoRouterState(GoRouterState state) {
  final next = <String, String>{};
  for (final entry in state.pathParameters.entries) {
    if (entry.value.isNotEmpty) {
      next[entry.key] = entry.value;
    }
  }
  for (final entry in state.uri.queryParameters.entries) {
    if (entry.value.isNotEmpty) {
      next[entry.key] = entry.value;
    }
  }
  final stale =
      Get.parameters.keys.where((key) => !next.containsKey(key)).toList();
  for (final key in stale) {
    Get.parameters.remove(key);
  }
  for (final entry in next.entries) {
    Get.parameters[entry.key] = entry.value;
  }
}
