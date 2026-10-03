import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/responsive/page_content.dart';
import '../../../../shared/widgets/async_action.dart';
import '../../domain/occurrence_draft.dart';
import '../../domain/roster_composer_args.dart';
import 'roster_composer_controller.dart';
import 'sections/forms_section.dart';
import 'sections/people_section.dart';
import 'sections/place_section.dart';
import 'sections/publish_section.dart';
import 'sections/repeat_section.dart';
import 'sections/support_section.dart';
import 'sections/travel_section.dart';
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
                        const _PresetControl(),
                        const SizedBox(height: 8),
                        _JobOrClientLabel(controller: controller),
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
                        const ComposerWhenSection(),
                        const _SectionGap(),
                        const ComposerPlaceSection(),
                        const _SectionGap(),
                        const ComposerPeopleSection(),
                        const _SectionGap(),
                        const ComposerSupportSection(),
                        const _SectionGap(),
                        const ComposerFormsSection(),
                        const _SectionGap(),
                        const ComposerWorkersSection(),
                        const _SectionGap(),
                        const ComposerTravelSection(),
                        const _SectionGap(),
                        const ComposerRepeatSection(),
                        const _SectionGap(),
                        const ComposerPublishSection(),
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

class _PresetControl extends GetView<RosterComposerController> {
  const _PresetControl();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final preset = controller.draft.value.preset;
      return SegmentedButton<ComposerPreset>(
        key: const Key('composer-preset'),
        segments: const [
          ButtonSegment(
            value: ComposerPreset.oneSession,
            label: Text('One session'),
          ),
          ButtonSegment(
            value: ComposerPreset.group,
            label: Text('Group'),
          ),
        ],
        selected: {preset},
        onSelectionChanged: (next) {
          if (next.isNotEmpty) controller.setPreset(next.first);
        },
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
      return Material(
        color: AppColors.composerFooter,
        elevation: 4,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: PageContent(
              width: PageContentWidth.narrow,
              child: Row(
                children: [
                  Expanded(
                    child: AsyncOutlinedButton(
                      key: const Key('composer-save-draft'),
                      onPressed: saving ? null : controller.saveDraft,
                      isLoading: controller.isSaving.value,
                      child: const Text('Save draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 28);
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
