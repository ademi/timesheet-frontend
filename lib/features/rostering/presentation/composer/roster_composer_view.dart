import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/responsive/page_content.dart';
import '../../../../shared/widgets/async_action.dart';
import '../../domain/composer_steps.dart';
import '../../domain/roster_composer_args.dart';
import 'roster_composer_controller.dart';
import 'sections/forms_section.dart';
import 'sections/people_section.dart';
import 'sections/place_section.dart';
import 'sections/support_section.dart';
import 'sections/when_section.dart';
import 'sections/workers_section.dart';

class RosterComposerView extends GetView<RosterComposerController> {
  const RosterComposerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Roster'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() {
        if (controller.isHydrating.value) {
          return const _ComposerSkeleton();
        }
        final err = controller.errorMessage.value;
        final step = controller.currentStep.value;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  PageContent(
                    width: PageContentWidth.narrow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _JobOrClientLabel(controller: controller),
                        const SizedBox(height: 16),
                        const _StepIndicator(),
                        if (err != null) ...[
                          const SizedBox(height: 12),
                          _ErrorBox(
                            message: err,
                            onRetry: () async {
                              if (controller.saveErrorDetail.value != null) {
                                await controller.saveDraft();
                              } else {
                                await controller.retryHydrate();
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 20),
                        KeyedSubtree(
                          key: ValueKey(step),
                          child: switch (step) {
                            ComposerStep.clients =>
                              const ComposerPeopleSection(),
                            ComposerStep.when => const ComposerWhenSection(),
                            ComposerStep.place => const ComposerPlaceSection(),
                            ComposerStep.support =>
                              const ComposerSupportSection(),
                            ComposerStep.forms => const ComposerFormsSection(),
                            ComposerStep.workers =>
                              const ComposerWorkersSection(),
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _ComposerFooter(),
          ],
        );
      }),
    );
  }
}

class _StepIndicator extends GetView<RosterComposerController> {
  const _StepIndicator();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final current = controller.currentStep.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            current.shortLabel,
            key: const Key('composer-step-label'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final step in ComposerStep.values) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => controller.goToStep(step),
                    child: Container(
                      key: Key('composer-step-dot-${step.name}'),
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            step.index <= current.index
                                ? AppColors.brand
                                : AppColors.slate200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                if (step != ComposerStep.workers) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      );
    });
  }
}

class _JobOrClientLabel extends StatelessWidget {
  const _JobOrClientLabel({required this.controller});

  final RosterComposerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final d = controller.draft.value;
      final name =
          d.clientId != null
              ? controller.participantName(d.clientId!)
              : null;
      final label =
          name ??
          (d.jobId != null ? 'Job ${d.jobId}' : 'Pick a client or program job');
      return Text(
        label,
        style: const TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      );
    });
  }
}

class _ComposerFooter extends GetView<RosterComposerController> {
  const _ComposerFooter();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final saving = controller.isSaving.value || controller.isPublishing.value;
      final last = controller.isLastStep;
      final first = controller.isFirstStep;
      return Material(
        color: AppColors.composerFooter,
        elevation: 4,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('composer-back'),
                          onPressed:
                              first || saving
                                  ? null
                                  : controller.goPreviousStep,
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child:
                            last
                                ? AsyncOutlinedButton(
                                  key: const Key('composer-save-draft'),
                                  onPressed:
                                      saving ? null : controller.saveDraft,
                                  isLoading: controller.isSaving.value,
                                  child: const Text('Save draft'),
                                )
                                : ElevatedButton(
                                  key: const Key('composer-next'),
                                  onPressed:
                                      saving
                                          ? null
                                          : () => controller.goNextStep(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.cta,
                                    foregroundColor: AppColors.onCta,
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: const Text('Next'),
                                ),
                      ),
                    ],
                  ),
                  if (last) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: PopupMenuButton<ComposerPublishMode>(
                        key: const Key('composer-publish'),
                        enabled: !saving,
                        onSelected: controller.publish,
                        itemBuilder:
                            (context) => const [
                              PopupMenuItem(
                                value: ComposerPublishMode.assignAndPublish,
                                child: Text('Assign & publish'),
                              ),
                              PopupMenuItem(
                                value: ComposerPublishMode.openForClaim,
                                child: Text('Open for claim'),
                              ),
                            ],
                        child: AbsorbPointer(
                          child: ElevatedButton(
                            onPressed:
                                saving
                                    ? null
                                    : () => controller.openPublishMenu(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.cta,
                              foregroundColor: AppColors.onCta,
                              minimumSize: const Size.fromHeight(48),
                            ),
                            child:
                                controller.isPublishing.value
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.onCta,
                                      ),
                                    )
                                    : const Text('Publish'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ComposerSkeleton extends StatelessWidget {
  const _ComposerSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: AppColors.error)),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                onRetry!();
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// Scroll helper when opening with a focus section (people / publish).
extension ComposerFocusScroll on ComposerFocusSection {
  String get sectionKey => switch (this) {
    ComposerFocusSection.plan => 'plan',
    ComposerFocusSection.people => 'people',
    ComposerFocusSection.publish => 'publish',
  };
}
