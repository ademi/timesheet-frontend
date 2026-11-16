import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/widgets/app_toast.dart';
import '../models/tutorial_guide.dart';

/// Article-style guide: header, TOC, prose sections, embedded steps.
class TutorialGuideDetail extends StatefulWidget {
  const TutorialGuideDetail({
    super.key,
    required this.guide,
    required this.onBack,
    this.onClose,
  });

  final TutorialGuide guide;
  final VoidCallback onBack;
  final VoidCallback? onClose;

  @override
  State<TutorialGuideDetail> createState() => _TutorialGuideDetailState();
}

class _TutorialGuideDetailState extends State<TutorialGuideDetail> {
  final _scrollController = ScrollController();
  final _sectionKeys = <String, GlobalKey>{};

  TutorialGuide get guide => widget.guide;

  @override
  void initState() {
    super.initState();
    for (final section in guide.sections) {
      _sectionKeys[section.id] = GlobalKey();
    }
  }

  @override
  void didUpdateWidget(covariant TutorialGuideDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide.id != guide.id) {
      _sectionKeys
        ..clear()
        ..addEntries(
          guide.sections.map((s) => MapEntry(s.id, GlobalKey())),
        );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openVideo() async {
    final url = guide.videoUrl;
    if (url == null || url.isEmpty) return;
    final ok = await openExternalUrl(url);
    if (!ok) {
      AppToast.error('Tutorials', 'Could not open the video link.');
    }
  }

  Future<void> _scrollToSection(String id) async {
    final key = _sectionKeys[id];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  guide.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
              if (guide.writtenBy != null || guide.updatedLabel != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.brandSoft,
                      child: Text(
                        _initial(guide.writtenBy),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        [
                          if (guide.writtenBy != null)
                            'Written by ${guide.writtenBy}',
                          if (guide.updatedLabel != null) guide.updatedLabel,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(
                guide.summary,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
              if (guide.videoUrl != null && guide.videoUrl!.isNotEmpty) ...[
                const SizedBox(height: 14),
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
              if (guide.sections.length > 1) ...[
                const SizedBox(height: 16),
                _TableOfContents(
                  sections: guide.sections,
                  onSelect: _scrollToSection,
                ),
              ],
              const SizedBox(height: 8),
              for (final section in guide.sections) ...[
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: _sectionKeys[section.id],
                  child: _ArticleSection(section: section),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _initial(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return 'R';
  return trimmed[0].toUpperCase();
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({
    required this.sections,
    required this.onSelect,
  });

  final List<TutorialSection> sections;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: const Text(
            'Table of contents',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          children: [
            for (final section in sections)
              ListTile(
                dense: true,
                title: Text(
                  section.heading,
                  style: const TextStyle(fontSize: 13, color: AppColors.textDark),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                onTap: () => onSelect(section.id),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArticleSection extends StatelessWidget {
  const _ArticleSection({required this.section});

  final TutorialSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          section.heading,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
            height: 1.3,
          ),
        ),
        if (section.body != null && section.body!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            section.body!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textDark,
              height: 1.5,
            ),
          ),
        ],
        if (section.steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < section.steps.length; i++) ...[
            _StepRow(index: i + 1, text: section.steps[i]),
            if (i < section.steps.length - 1) const SizedBox(height: 10),
          ],
        ],
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
