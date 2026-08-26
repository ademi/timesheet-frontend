import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/clients_controller.dart';
import '../widgets/contact_form_fields.dart';

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
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (err != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        err,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ContactFormFields(controller: controller),
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
              ),
            ),
          ],
        );
      }),
    );
  }
}
