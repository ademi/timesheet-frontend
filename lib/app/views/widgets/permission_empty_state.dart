import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/auth/permission_helpers.dart';
import '../../../core/services/token_storage.dart';
import '../../themes/app_colors.dart';

/// Empty / blocked state when the user lacks a permission.
class PermissionEmptyState extends StatelessWidget {
  const PermissionEmptyState({
    super.key,
    required this.permission,
    this.message,
  });

  final String permission;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message ?? 'You don’t have permission for this action.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              permission,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textDark.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns [child] if [storage] has [permission], else [PermissionEmptyState].
  static Widget gate({
    required String permission,
    required Widget child,
    String? message,
  }) {
    if (!Get.isRegistered<TokenStorage>()) {
      return PermissionEmptyState(permission: permission, message: message);
    }
    final storage = Get.find<TokenStorage>();
    if (PermissionHelpers.hasPermission(storage, permission)) {
      return child;
    }
    return PermissionEmptyState(permission: permission, message: message);
  }
}
