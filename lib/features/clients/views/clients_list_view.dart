import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/models/profile_photo_models.dart';
import '../../../shared/utils/external_url.dart';
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
  });

  final ClientOut client;
  final VoidCallback onOpen;
  final ProfilePhotoOut? photo;

  @override
  Widget build(BuildContext context) {
    final address = client.primaryDisplayAddress;
    final site = client.primarySite;
    final contact = [
      if (client.email != null) client.email!,
      if (client.phone != null) client.phone!,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ProfilePhotoEditor(
          networkUrl: photo?.downloadUrl,
          documentId: photo?.documentId,
          readOnly: true,
          size: 48,
          showLabel: false,
        ),
        title: Text(client.fullName),
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
                  Get.snackbar(
                    'Copied',
                    address,
                    snackPosition: SnackPosition.BOTTOM,
                    margin: const EdgeInsets.all(16),
                  );
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
                Get.snackbar(
                  'Copied',
                  address,
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(16),
                );
              },
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
