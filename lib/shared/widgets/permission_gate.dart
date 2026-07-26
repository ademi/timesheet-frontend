import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/session_service.dart';

/// Hides [child] when the signed-in user lacks [permission] / [anyOf] / [allOf].
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.child,
    this.permission,
    this.anyOf,
    this.allOf,
    this.fallback = const SizedBox.shrink(),
  });

  final Widget child;
  final String? permission;
  final List<String>? anyOf;
  final List<String>? allOf;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<SessionService>()) return fallback;
    final session = Get.find<SessionService>();
    if (permission != null && !session.hasPermission(permission!)) {
      return fallback;
    }
    if (anyOf != null && anyOf!.isNotEmpty && !session.hasAny(anyOf!)) {
      return fallback;
    }
    if (allOf != null && allOf!.isNotEmpty && !session.hasAll(allOf!)) {
      return fallback;
    }
    return child;
  }
}
