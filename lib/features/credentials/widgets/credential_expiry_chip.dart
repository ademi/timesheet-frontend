import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';
import '../utils/credential_expiry.dart';

/// Compact urgency chip when a credential is expired or within 90 days.
class CredentialExpiryChip extends StatelessWidget {
  const CredentialExpiryChip({super.key, required this.expiresOn});

  final DateTime? expiresOn;

  @override
  Widget build(BuildContext context) {
    final label = credentialExpiryLabel(expiresOn);
    final urgency = credentialExpiryUrgency(expiresOn);
    if (label == null || urgency == CredentialExpiryUrgency.none) {
      return const SizedBox.shrink();
    }

    final color = switch (urgency) {
      CredentialExpiryUrgency.expired ||
      CredentialExpiryUrgency.critical => AppColors.error,
      CredentialExpiryUrgency.soon => const Color(0xFFEA580C),
      CredentialExpiryUrgency.watch => AppColors.openSlot,
      CredentialExpiryUrgency.none => AppColors.slate600,
    };

    return Chip(
      avatar: Icon(Icons.event_busy_outlined, size: 14, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 11)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: 0.12),
    );
  }
}
