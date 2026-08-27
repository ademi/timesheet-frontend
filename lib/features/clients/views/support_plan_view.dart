import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../controllers/support_plan_controller.dart';
import '../widgets/support_plan_form_body.dart';

class SupportPlanView extends GetView<SupportPlanController> {
  const SupportPlanView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Support plan')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: SupportPlanFormBody(controller: controller),
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
            FormStickyActions(
              onCancel: controller.isSaving.value ? null : () => Get.back(),
              secondaryLabel: 'Save draft',
              onSecondary:
                  controller.isSaving.value
                      ? null
                      : () => controller.saveDraft(),
              primaryLabel: 'Activate',
              onPrimary:
                  !controller.canActivate || controller.isSaving.value
                      ? null
                      : () => controller.activate(),
              isLoading: controller.isSaving.value,
            ),
          ],
        );
      }),
    );
  }
}
