import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
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
        final busy =
            controller.isSaving.value || controller.isGeocoding.value;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      SiteFormFields(controller: controller),
                      const SizedBox(height: 16),
                      AsyncElevatedButton(
                        onPressed: controller.saveSite,
                        isLoading: busy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: Text(
                          isEdit ? 'Save location' : 'Create location',
                        ),
                      ),
                    ],
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
