import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../themes/app_colors.dart';
import 'app_back_button.dart';

/// Shown when the user lacks `scheduling.read` or the API returns 403.
class ShiftScheduleNoAccess extends StatelessWidget {
  const ShiftScheduleNoAccess({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No access',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You do not have permission to view the shift schedule.\n'
              'Contact your administrator if you need access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textMuted.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App bar used on the shift schedule screen (reused when view is added in Phase 4).
class ShiftScheduleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShiftScheduleAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: const AppBackButton(fallbackRoute: AppRoutes.adminPanel),
      title: const Text('Shift Schedule'),
      backgroundColor: AppColors.darkBrown,
    );
  }
}
