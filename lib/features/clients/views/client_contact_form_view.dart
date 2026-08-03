import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/clients_controller.dart';

class ClientContactFormView extends GetView<ClientsController> {
  const ClientContactFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.editingContact != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEdit ? 'Edit contact' : 'Add contact')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        return ListView(
          padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller.contactNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.contactEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller.contactPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.contactIsPrimary.value,
              onChanged: (v) => controller.contactIsPrimary.value = v,
              title: const Text('Primary contact'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.contactNotify.value,
              onChanged: (v) => controller.contactNotify.value = v,
              title: const Text('Notify on visit complete'),
            ),
            const SizedBox(height: 16),
            AsyncElevatedButton(
              onPressed: controller.saveContact,
              isLoading: controller.isSaving.value,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(isEdit ? 'Save contact' : 'Create contact'),
            ),
          ],
        );
      }),
    );
  }
}
