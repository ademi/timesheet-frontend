import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/controllers/auth_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../controllers/credentials_controller.dart';
import '../data/models/credential_models.dart';

class CredentialsListView extends GetView<CredentialsController> {
  const CredentialsListView({super.key, this.embedded = false});

  /// When true (onboarding), omit shell AppBar chrome handled by parent.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Obx(() {
      if (controller.isLoading.value && controller.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      final err = controller.errorMessage.value;
      return RefreshIndicator(
        onRefresh: controller.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (err != null) ...[
              _Banner(message: err, error: true),
              const SizedBox(height: 12),
            ],
            if (controller.lastScanStatus.value != null) ...[
              _Banner(
                message:
                    'Last evidence scan: ${controller.lastScanStatus.value}',
                error: controller.lastScanStatus.value == 'blocked',
              ),
              const SizedBox(height: 12),
            ],
            Text(
              embedded
                  ? 'Add required credentials and attach evidence. '
                      'Scan must be clean before staff review.'
                  : 'Your credentials and evidence files.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (controller.canManage)
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => Get.toNamed(AppRoutes.contractorCredentialCreate),
                  icon: const Icon(Icons.add),
                  label: const Text('Add credential'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (controller.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No credentials yet.'),
              ),
            for (final c in controller.items) _CredentialTile(credential: c),
          ],
        ),
      );
    });

    if (embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Credentials'),
        actions: [
          if (Get.isRegistered<AuthController>())
            IconButton(
              tooltip: 'Log out',
              onPressed: () => Get.find<AuthController>().logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: body,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? AppColors.errorBackground : AppColors.slate200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: error ? AppColors.error : AppColors.textDark,
        ),
      ),
    );
  }
}

class _CredentialTile extends StatelessWidget {
  const _CredentialTile({required this.credential});

  final CredentialOut credential;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CredentialsController>();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(credentialTypeLabel(credential.credentialType)),
        subtitle: Text(
          'Status: ${credential.status} · Evidence: ${credential.evidencePresence}\n'
          'Provenance: ${credential.provenanceState}'
          '${credential.identifierMasked != null ? '\nID: ${credential.identifierMasked}' : ''}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'detail':
                Get.toNamed(
                  AppRoutes.contractorCredentialDetail,
                  arguments: credential,
                );
              case 'upload':
                await c.attachEvidence(credential);
              case 'supersede':
                await c.supersede(credential);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'detail', child: Text('Details')),
            if (c.canManage)
              const PopupMenuItem(
                value: 'upload',
                child: Text('Attach evidence'),
              ),
            if (c.canManage)
              const PopupMenuItem(
                value: 'supersede',
                child: Text('Supersede'),
              ),
          ],
        ),
        onTap: () => Get.toNamed(
          AppRoutes.contractorCredentialDetail,
          arguments: credential,
        ),
      ),
    );
  }
}
