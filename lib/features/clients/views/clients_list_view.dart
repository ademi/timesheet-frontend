import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/profile_photo_editor.dart';
import '../../compliance_ops/widgets/notification_bell_button.dart';
import '../controllers/clients_controller.dart';
import '../data/models/client_models.dart';

class ClientsListView extends GetView<ClientsController> {
  const ClientsListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clients'),
        actions: shellAppBarActions(),
      ),
      floatingActionButton: !controller.canManage
          ? null
          : FloatingActionButton.extended(
              onPressed: controller.openCreate,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add client'),
            ),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final visible = controller.visibleItems;
        if (controller.isLoading.value && controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PageContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (err != null) ...[
                      _ErrorBox(err),
                      const SizedBox(height: 12),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilterChip(
                        label: const Text('Show incomplete'),
                        selected: controller.showIncompleteOnboarding.value,
                        onSelected: (v) =>
                            controller.showIncompleteOnboarding.value = v,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('No clients yet.'),
                      ),
                    for (final c in visible)
                      _ClientCard(
                        client: c,
                        photo: controller.photosByClient[c.id],
                        onOpen: () => controller.openDetail(c),
                        onContinueOnboarding:
                            controller.canManage &&
                                    ClientsController.isOnboardingIncomplete(c)
                                ? () => controller.openResumeOnboarding(c)
                                : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onOpen,
    this.photo,
    this.onContinueOnboarding,
  });

  final ClientOut client;
  final VoidCallback onOpen;
  final ProfilePhotoOut? photo;
  final VoidCallback? onContinueOnboarding;

  @override
  Widget build(BuildContext context) {
    final address = client.primaryDisplayAddress;
    final site = client.primarySite;
    final contact = [
      if (client.email != null) client.email!,
      if (client.phone != null) client.phone!,
    ].join(' · ');
    final incomplete = ClientsController.isOnboardingIncomplete(client);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: ProfilePhotoEditor(
              networkUrl: photo?.downloadUrl,
              documentId: photo?.documentId,
              readOnly: true,
              size: 48,
              showLabel: false,
            ),
            title: Row(
              children: [
                Expanded(child: Text(client.fullName)),
                if (incomplete)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.openSlotBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.openSlot),
                    ),
                    child: const Text(
                      'Incomplete',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.openSlot,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.status + (contact.isEmpty ? '' : ' · $contact'),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => openMapLocation(
                      latitude: site?.latitude,
                      longitude: site?.longitude,
                      label: address,
                    ),
                    onLongPress: () async {
                      await Clipboard.setData(ClipboardData(text: address));
                      AppToast.info('Copied', address);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            isThreeLine: address.isNotEmpty,
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpen,
            onLongPress: address.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: address));
                    AppToast.info('Copied', address);
                  },
          ),
          if (onContinueOnboarding != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onContinueOnboarding,
                  child: const Text('Continue onboarding'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}
