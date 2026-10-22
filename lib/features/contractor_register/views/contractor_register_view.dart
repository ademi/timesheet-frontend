import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/views/widgets/app_back_button.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../controllers/contractor_register_controller.dart';
import '../widgets/register_step_widgets.dart';

class ContractorRegisterView extends GetView<ContractorRegisterController> {
  const ContractorRegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme AppBar uses light text for teal chrome — override fully so the
    // light register surface keeps readable title + back control.
    final titleStyle = Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
          color: AppColors.textDark,
        ) ??
        const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.login),
        title: const Text('Register'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actionsIconTheme: const IconThemeData(color: AppColors.textDark),
        titleTextStyle: titleStyle,
      ),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Create your support worker profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'After registering you will sign in and complete '
                          'profile, legal, and documents.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        RegisterIdentityStep(controller: controller),
                      ],
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: PageContent(
                  width: PageContentWidth.narrow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextButton(
                        onPressed: controller.goToLogin,
                        child: const Text('Already have an account? Sign in'),
                      ),
                      AsyncElevatedButton(
                        onPressed: controller.submit,
                        isLoading:
                            controller.isLoading.value ||
                            controller.isInviteLoading.value,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cta,
                          foregroundColor: AppColors.onPrimary,
                        ),
                        child: const Text('Create account'),
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
