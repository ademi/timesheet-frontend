import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../data/staff_preset_catalog.dart';

/// Shows can/cannot authorizations for a staff job title (create-form (i)).
Future<void> showStaffPresetInfoSheet(
  BuildContext context, {
  required String presetKey,
  String? displayName,
}) {
  final info = staffPresetInfo(presetKey);
  final title =
      info?.displayName ??
      displayName ??
      staffPresetDisplayName(presetKey);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'What this job title can and cannot do',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              _AuthBlock(
                label: 'Can have authority to…',
                body: info?.can ?? 'See organisation policy for this role.',
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _AuthBlock(
                label: 'Cannot have authority to…',
                body:
                    info?.cannot ??
                    'Elevated actions outside this role’s pack.',
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AuthBlock extends StatelessWidget {
  const _AuthBlock({
    required this.label,
    required this.body,
    required this.color,
  });

  final String label;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
