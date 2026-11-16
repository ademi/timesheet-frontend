import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/widgets/app_toast.dart';
import '../models/tutorial_guide.dart';

/// Scrollable guide body: steps + optional external video link.
class TutorialGuideDetail extends StatelessWidget {
  const TutorialGuideDetail({
    super.key,
    required this.guide,
    required this.onBack,
  });

  final TutorialGuide guide;
  final VoidCallback onBack;

  Future<void> _openVideo() async {
    final url = guide.videoUrl;
    if (url == null || url.isEmpty) return;
    final ok = await openExternalUrl(url);
    if (!ok) {
      AppToast.error('Tutorials', 'Could not open the video link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Expanded(
                child: Text(
                  'Guide',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text(
                guide.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                guide.summary,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
              if (guide.videoUrl != null && guide.videoUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openVideo,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Watch video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    side: const BorderSide(color: AppColors.brand),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Steps',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < guide.steps.length; i++) ...[
                _StepRow(index: i + 1, text: guide.steps[i]),
                if (i < guide.steps.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.brandSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.brandDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
