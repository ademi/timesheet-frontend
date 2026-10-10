import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

/// Common entity-id keys carried in GoRouter `extra` maps.
const _extraIdKeys = <String>{
  'id',
  'house_id',
  'clientId',
  'client_id',
  'visitId',
  'visit_id',
  'shiftId',
  'shift_id',
  'jobId',
  'job_id',
  'planId',
  'assessmentId',
  'engagementId',
};

/// Copies GoRouter path + query params into [Get.parameters] so existing
/// hydrate helpers ([routeParam], bindings) keep working on web.
///
/// Also mirrors [GoRouterState.extra] into [Get.routing.args]. During a route
/// `builder`, [GoRouterState] is authoritative — `routerDelegate.currentConfiguration`
/// (and therefore [AppNavigator.arguments]) can still point at the previous page.
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

  final extra = state.extra;
  // Keep GetX args aligned with the route being built (not the prior page).
  Get.routing.args = extra;
  if (extra is Map) {
    for (final key in _extraIdKeys) {
      if (next.containsKey(key)) continue;
      final raw = extra[key];
      if (raw == null) continue;
      final value = raw.toString();
      if (value.isNotEmpty) next[key] = value;
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
