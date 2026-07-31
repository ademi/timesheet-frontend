import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

/// Human-readable label for [CredentialOut.status] and review decisions.
String credentialStatusLabel(String status) {
  return switch (status) {
    'active' => 'Active',
    'superseded' => 'Superseded',
    'withdrawn' => 'Withdrawn',
    'draft' => 'Draft',
    'accepted' => 'Accepted',
    'rejected' => 'Rejected',
    'pending' => 'Pending review',
    're_review_required' => 'Re-review required',
    _ => status.replaceAll('_', ' '),
  };
}

class CredentialStatusChip extends StatelessWidget {
  const CredentialStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' || 'accepted' => AppColors.success,
      'superseded' || 'withdrawn' || 'rejected' => AppColors.error,
      'pending' || 're_review_required' => const Color(0xFFEA580C),
      'draft' => AppColors.slate600,
      _ => AppColors.slate600,
    };
    return Chip(
      label: Text(
        credentialStatusLabel(status),
        style: TextStyle(color: color, fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}
