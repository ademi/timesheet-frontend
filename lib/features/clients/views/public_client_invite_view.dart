import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../controllers/public_client_invite_controller.dart';

class PublicClientInviteView extends GetView<PublicClientInviteController> {
  const PublicClientInviteView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Client invite')),
      body: Obx(() {
        if (controller.isLoading.value && controller.invite.value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
        final done = controller.doneMessage.value;
        final invite = controller.invite.value;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (err != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(err, style: const TextStyle(color: AppColors.error)),
              ),
              const SizedBox(height: 16),
            ],
            if (done != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(done),
              ),
              const SizedBox(height: 16),
            ],
            if (invite != null) ...[
              Text(
                invite.tenantName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hello ${invite.clientFirstName},\n\n'
                'Please acknowledge this invite from your care provider.',
                style: const TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 12),
              Text(
                'Expires: ${invite.expiresAt.toLocal()}',
                style: const TextStyle(fontSize: 13),
              ),
              if (invite.consentAcknowledged) ...[
                const SizedBox(height: 12),
                const Text(
                  'Already acknowledged.',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: controller.isSaving.value
                      ? null
                      : () => controller.acknowledge(accept: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Acknowledge'),
                ),
              ],
            ] else if (err == null)
              const Text('Invite not found.'),
          ],
        );
      }),
    );
  }
}
