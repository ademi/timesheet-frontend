import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/floating_error_notice.dart';
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
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: ContactFormFields(controller: controller),
                  ),
                ],
              ),
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FloatingErrorNotice(
                  message: err,
                  onDismiss: () => controller.errorMessage.value = null,
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PageContent(
                  width: PageContentWidth.narrow,
                  child: AsyncElevatedButton(
                    onPressed: controller.saveContact,
                    isLoading: controller.isSaving.value,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(isEdit ? 'Save contact' : 'Create contact'),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
