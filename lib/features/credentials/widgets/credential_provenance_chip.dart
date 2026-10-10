import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../../../shared/utils/humanize_label.dart';
import '../data/models/credential_models.dart';

/// Wire key for the Review chip from provenance + optional engagement decision.
///
/// Reject / re_review leave BE provenance as contractor_asserted; staff and
/// contractor lists may include [CredentialOut.reviewDecision] for display.
String credentialReviewDisplayKey({
  required String provenanceState,
  String? reviewDecision,
}) {
  return switch (reviewDecision) {
    'rejected' => 'reviewer_rejected',
    're_review_required' => 'contractor_asserted',
    'accepted' => 'reviewer_sighted',
    _ => provenanceState,
  };
}

/// Human-readable label for [CredentialOut.provenanceState].
String credentialProvenanceLabel(String provenance) {
  return switch (provenance) {
    'reviewer_sighted' => 'Accepted by reviewer',
    'verified' => 'Verified',
    'contractor_asserted' => 'Awaiting review',
    'self_reported' || 'self_attested' => 'Self reported',
    'rejected' || 'reviewer_rejected' => 'Rejected by reviewer',
    _ => humanizeLabel(provenance),
  };
}

Color credentialProvenanceColor(String provenance) {
  return switch (provenance) {
    'reviewer_sighted' || 'verified' => AppColors.success,
    'rejected' || 'reviewer_rejected' => AppColors.error,
    'contractor_asserted' ||
    'self_reported' ||
    'self_attested' => const Color(0xFFEA580C),
    _ => AppColors.slate600,
  };
}

/// Compact provenance chip (green accepted / amber awaiting / red rejected).
class CredentialProvenanceChip extends StatelessWidget {
  const CredentialProvenanceChip({super.key, required this.provenance});

  final String provenance;

  @override
  Widget build(BuildContext context) {
    final color = credentialProvenanceColor(provenance);
    return Chip(
      label: Text(
        credentialProvenanceLabel(provenance),
        style: TextStyle(color: color, fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}
