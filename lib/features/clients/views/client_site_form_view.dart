import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../controllers/clients_controller.dart';
import '../widgets/site_form_fields.dart';

class ClientSiteFormView extends GetView<ClientsController> {
  const ClientSiteFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final isEdit = controller.editingSite != null;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(isEdit ? 'Edit location' : 'Add location')),
      body: Obx(() {
        final err = controller.errorMessage.value;
        final busy = controller.isSaving.value || controller.isGeocoding.value;

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SiteFormFields(controller: controller),
                      ),
                    ),
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
                    onPressed: controller.saveSite,
                    isLoading: busy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(isEdit ? 'Save location' : 'Create location'),
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
