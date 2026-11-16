import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';
import '../../feedback/widgets/feedback_sheet.dart';
import '../controllers/tutorials_controller.dart';
import '../models/tutorial_guide.dart';
import 'tutorial_guide_detail.dart';

/// Floating tutorials panel: home (search + list) or guide detail.
class TutorialsPanel extends StatelessWidget {
  const TutorialsPanel({super.key, required this.controller});

  final TutorialsController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 12,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Obx(() {
        final guide = controller.selectedGuide;
        if (guide != null) {
          return TutorialGuideDetail(
            guide: guide,
            onBack: controller.backToHome,
            onClose: controller.close,
          );
        }
        return _TutorialsHome(controller: controller);
      }),
    );
  }
}

class _TutorialsHome extends StatelessWidget {
  const _TutorialsHome({required this.controller});

  final TutorialsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.brandSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            size: 18,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Tutorials',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'How can we help you use Rostiq?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Browse articles with clear steps for rostering, people, '
                      'attendance, and billing.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: controller.close,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: controller.searchController,
            onChanged: controller.setSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search articles',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            final guides = controller.visibleGuides;
            if (guides.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No tutorials match your search.',
                    style: TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              itemCount: guides.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final guide = guides[index];
                return _GuideTile(
                  guide: guide,
                  suggested: controller.isSuggested(guide),
                  onTap: () => controller.openGuide(guide),
                );
              },
            );
          }),
        ),
        if (canSubmitFeedback())
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextButton(
              onPressed: () {
                controller.close();
                showFeedbackSheet(context);
              },
              child: const Text('Send feedback instead'),
            ),
          ),
      ],
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({
    required this.guide,
    required this.suggested,
    required this.onTap,
  });

  final TutorialGuide guide;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: suggested ? AppColors.brandSoft.withValues(alpha: 0.55) : AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (suggested)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text(
                          'Suggested for this page',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandDark,
                          ),
                        ),
                      ),
                    Text(
                      guide.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guide.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.slate500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
