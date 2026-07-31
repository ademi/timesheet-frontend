import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../credentials/data/models/credential_models.dart';
import '../data/models/engagement_models.dart';
import '../utils/missing_categories.dart';

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

  @override
  Widget build(BuildContext context) {
    final required =
        engagement.requiredDocCategories
            .where((category) => category.isRequired)
            .map((category) => category.category)
            .toSet()
            .toList()
          ..sort();
    final missing = missingCategories(engagement, credentials).toList()..sort();
    final have =
        required.where((category) => !missing.contains(category)).toList();

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
            const SizedBox(height: 12),
            _CategoryRow(label: 'Required', categories: required),
            _CategoryRow(
              label: 'Have',
              categories: have,
              color: AppColors.success,
            ),
            _CategoryRow(
              label: 'Missing',
              categories: missing,
              color: missing.isEmpty ? AppColors.success : AppColors.error,
            ),
            if (missing.isNotEmpty && onAddMissing != null) ...[
              const SizedBox(height: 8),
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.categories,
    this.color,
  });

  final String label;
  final List<String> categories;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(color: AppColors.textMuted),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            TextSpan(
              text:
                  categories.isEmpty
                      ? '—'
                      : categories.map(credentialTypeLabel).join(', '),
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
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
      'pending_docs' || 'invited' => const Color(0xFFEA580C),
      'suspended' || 'ended' => AppColors.error,
      _ => AppColors.slate600,
    };
    return Chip(
      label: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}
