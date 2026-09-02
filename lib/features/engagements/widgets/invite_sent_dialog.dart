import 'package:flutter/material.dart';

import '../../../app/themes/app_colors.dart';

/// Shown after a contractor registration invite email is sent.
class InviteSentDialog extends StatelessWidget {
  const InviteSentDialog({super.key, required this.expiresAt});

  final DateTime expiresAt;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite sent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'An invitation email was sent to the contractor. '
            'They can register using the link in that email.',
          ),
          const SizedBox(height: 12),
          Text(
            'Expires ${expiresAt.toLocal()}.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
