import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../jobs/controllers/jobs_controller.dart';
import 'composer_cutover.dart';

/// Soft-cutover: legacy compose routes → [AppRoutes.staffRosterCompose]
/// (or shift detail when the shift is already published).
class ComposerCutoverMiddleware extends GetMiddleware {
  ComposerCutoverMiddleware({required this.legacyRoute});

  final String legacyRoute;

  @override
  RouteSettings? redirect(String? route) {
    String? contextualJobId;
    if (Get.isRegistered<JobsController>()) {
      contextualJobId = Get.find<JobsController>().selected.value?.id;
    }
    final target = ComposerCutover.resolve(
      legacyRoute: legacyRoute,
      arguments: Get.arguments,
      contextualJobId: contextualJobId,
    );
    if (target.name == legacyRoute) return null;
    return target;
  }
}
