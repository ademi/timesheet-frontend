import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

/// Copies GoRouter path + query params into [Get.parameters] so existing
/// hydrate helpers ([routeParam], bindings) keep working on web.
void syncGetxFromGoRouterState(GoRouterState state) {
  for (final entry in state.pathParameters.entries) {
    if (entry.value.isNotEmpty) {
      Get.parameters[entry.key] = entry.value;
    }
  }
  for (final entry in state.uri.queryParameters.entries) {
    if (entry.value.isNotEmpty) {
      Get.parameters[entry.key] = entry.value;
    }
  }
}
