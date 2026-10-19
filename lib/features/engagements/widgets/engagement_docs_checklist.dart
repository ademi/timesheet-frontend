import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../credentials/data/models/credential_models.dart';
import '../../credentials/utils/support_worker_pack.dart'
    show buildPackChecklistSections, ConditionalChecklistItem;
import '../data/models/engagement_models.dart';

/// Summarises the credential evidence required for one engagement.
class EngagementDocsChecklist extends StatelessWidget {
  const EngagementDocsChecklist({
    super.key,
    required this.engagement,
    required this.credentials,
    this.onAddMissing,
  });

  final EngagementOut engagement;
  final List<CredentialOut> credentials;
  final ValueChanged<List<String>>? onAddMissing;

  String _labelFor(String code) {
    for (final item in engagement.requiredDocCategories) {
      if (item.category == code) return item.displayLabel;
    }
    return credentialTypeLabel(code);
  }

  @override
  Widget build(BuildContext context) {
    final sections = buildPackChecklistSections(
      engagement: engagement,
      credentials: credentials,
    );
    final missing = sections.missingForCreate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    engagement.tenantName?.isNotEmpty == true
                        ? engagement.tenantName!
                        : 'Provider ${engagement.tenantId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                EngagementStatusChip(status: engagement.status),
              ],
            ),
            if (engagement.documentPack != null) ...[
              const SizedBox(height: 4),
              Text(
                'Pack: ${engagement.documentPack}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SectionHeader(title: 'Always required'),
            _CategoryChips(
              categories: sections.always,
              labelFor: _labelFor,
              missing: missing.toSet(),
            ),
            if (sections.photoIdRequired) ...[
              const SizedBox(height: 8),
              _PhotoIdPointsRow(
                total: sections.photoIdPointsTotal,
                satisfied: sections.photoIdSatisfied,
              ),
            ],
            const SizedBox(height: 12),
            _SectionHeader(title: 'Conditional'),
            if (sections.conditionals.isEmpty)
              const Text('—', style: TextStyle(color: AppColors.textMuted))
            else
              for (final item in sections.conditionals) ...[
                _ConditionalRow(item: item, labelFor: _labelFor),
              ],
            const SizedBox(height: 12),
            _SectionHeader(title: 'Optional'),
            _CategoryChips(
              categories: sections.optional,
              labelFor: _labelFor,
              missing: const {},
              muted: true,
            ),
            if (missing.isNotEmpty && onAddMissing != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => onAddMissing!(missing),
                  icon: const Icon(Icons.add),
                  label: const Text('Add missing credential'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _PhotoIdPointsRow extends StatelessWidget {
  const _PhotoIdPointsRow({required this.total, required this.satisfied});

  final int total;
  final bool satisfied;

  @override
  Widget build(BuildContext context) {
    final color = satisfied ? AppColors.success : AppColors.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Photo ID points: $total / 100'
        '${satisfied ? ' — satisfied' : ' — need ${100 - total} more'}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ConditionalRow extends StatelessWidget {
  const _ConditionalRow({required this.item, required this.labelFor});

  final ConditionalChecklistItem item;
  final String Function(String) labelFor;

  @override
  Widget build(BuildContext context) {
    final label = labelFor(item.category);
    if (item.isLocked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$label — answer on Profile to unlock',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    if (!item.isRequired) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$label — not required',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        item.isMissing ? '$label — missing' : '$label — have',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: item.isMissing ? AppColors.error : AppColors.success,
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.labelFor,
    required this.missing,
    this.muted = false,
  });

  final List<String> categories;
  final String Function(String) labelFor;
  final Set<String> missing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const Text('—', style: TextStyle(color: AppColors.textMuted));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final code in categories)
          Chip(
            label: Text(
              labelFor(code),
              style: TextStyle(
                fontSize: 12,
                color:
                    muted
                        ? AppColors.textMuted
                        : missing.contains(code) ||
                            (code == 'passport_id' &&
                                missing.contains('passport_id'))
                        ? AppColors.error
                        : AppColors.textDark,
              ),
            ),
            visualDensity: VisualDensity.compact,
            backgroundColor: AppColors.surface,
          ),
      ],
    );
  }
}

/// Compact, engagement-specific status display used by onboarding and docs.
class EngagementStatusChip extends StatelessWidget {
  const EngagementStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' || 'approved' => AppColors.success,
      'awaiting_approval' => const Color(0xFFCA8A04),
      'pending_docs' || 'invited' => const Color(0xFFEA580C),
      'suspended' || 'ended' => AppColors.error,
      _ => AppColors.slate600,
    };
    return Chip(
      label: Text(
        engagementStatusLabel(status),
        style: TextStyle(color: color, fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}
