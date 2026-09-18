import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/floating_error_notice.dart';
import '../../../shared/widgets/form_sticky_actions.dart';
import '../controllers/strengths_needs_controller.dart';
import '../utils/strengths_needs_keys.dart';

class StrengthsNeedsView extends GetView<StrengthsNeedsController> {
  const StrengthsNeedsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Strengths & Needs')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = controller.errorMessage.value;
        final busy = controller.isBusy;
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
                        if (controller.isSubmitted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.openSlotBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.openSlot),
                            ),
                            child: Text(
                              controller.isCurrent.value
                                  ? 'Submitted — current assessment'
                                  : 'Submitted — read only',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.openSlot,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const _SectionTitle('Header'),
                        const SizedBox(height: 12),
                        _field(
                          controller.completedByCtrl,
                          'Completed by',
                          readOnly: !controller.canEdit,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller.participantNameCtrl,
                          'Participant name',
                          readOnly: !controller.canEdit,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller.supportersNamesCtrl,
                          'Supporters names',
                          readOnly: !controller.canEdit,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller.interviewDateCtrl,
                          'Interview date (YYYY-MM-DD)',
                          readOnly: !controller.canEdit,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller.preferencesNotesCtrl,
                          'Preferences notes',
                          maxLines: 3,
                          readOnly: !controller.canEdit,
                        ),
                        for (final group in StrengthsNeedsKeys.sectionGroups) ...[
                          const SizedBox(height: 24),
                          _SectionTitle(group.title),
                          const SizedBox(height: 12),
                          for (final key in group.keys) ...[
                            _field(
                              controller.sectionCtrls[key]!,
                              StrengthsNeedsKeys.labelFor(key),
                              maxLines: 4,
                              readOnly: !controller.canEdit,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                        const SizedBox(height: 12),
                        const _SectionTitle('Additional notes'),
                        const SizedBox(height: 12),
                        _field(
                          controller.additionalNotesCtrl,
                          'Additional notes',
                          maxLines: 4,
                          readOnly: !controller.canEdit,
                        ),
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
            if (controller.canEdit)
              FormStickyActions(
                onCancel: busy ? null : () => Get.back(result: true),
                secondaryLabel: 'Save draft',
                onSecondary: busy ? null : () => controller.saveDraft(),
                primaryLabel: 'Submit',
                onPrimary: busy ? null : () => _submit(context),
                isLoading: busy,
              )
            else
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: busy ? null : () => Get.back(result: true),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final ok = await controller.submit();
    if (ok && context.mounted) {
      Get.back(result: true);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
    );
  }
}

Widget _field(
  TextEditingController ctrl,
  String label, {
  int maxLines = 1,
  bool readOnly = false,
}) {
  return TextField(
    controller: ctrl,
    readOnly: readOnly,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      alignLabelWithHint: maxLines > 1,
    ),
  );
}
