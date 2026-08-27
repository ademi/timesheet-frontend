import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/utils/abn_utils.dart';
import '../controllers/complete_account_controller.dart';

class CompleteAccountView extends GetView<CompleteAccountController> {
  const CompleteAccountView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complete your account'),
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Form(
                key: controller.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add your business details so providers can pay you '
                      'and verify your ABN.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    if (err != null) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            err,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: controller.abnCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ABN',
                        hintText: '11 digits',
                        prefixIcon: Icon(Icons.apartment_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: (v) => AbnUtils.formValidator(v),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Payment details (optional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.hasExistingPayment.value
                          ? 'Existing account ending '
                              '${controller.profile.value?.paymentDetails?.accountNumberMasked ?? ''}. '
                              'Enter a new account number to replace it.'
                          : 'Account name, BSB, and account number. Leave blank to skip.',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller.accountNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller.bsbCtrl,
                      decoration: const InputDecoration(
                        labelText: 'BSB',
                        hintText: '6 digits',
                        prefixIcon: Icon(Icons.account_balance_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) {
                        final name = controller.accountNameCtrl.text.trim();
                        final account =
                            AbnUtils.digitsOnly(controller.accountNumberCtrl.text);
                        final any = name.isNotEmpty ||
                            AbnUtils.digitsOnly(v).isNotEmpty ||
                            account.isNotEmpty;
                        if (!any) return null;
                        return AbnUtils.bsbValidator(v, required: true);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: controller.accountNumberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account number',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) {
                        final name = controller.accountNameCtrl.text.trim();
                        final bsb = AbnUtils.digitsOnly(controller.bsbCtrl.text);
                        final any = name.isNotEmpty ||
                            bsb.isNotEmpty ||
                            AbnUtils.digitsOnly(v).isNotEmpty;
                        if (!any && !controller.hasExistingPayment.value) {
                          return null;
                        }
                        if (!any) return null;
                        return AbnUtils.accountNumberValidator(v, required: true);
                      },
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: controller.isSaving.value
                          ? null
                          : () => controller.save(continueToApp: true),
                      child: controller.isSaving.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save and continue'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          controller.isSaving.value ? null : controller.skip,
                      child: const Text('Skip for now'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
