import 'package:flutter/material.dart';

import 'feedback_sheet.dart';

/// AppBar action that opens the in-app feedback sheet.
class FeedbackButton extends StatelessWidget {
  const FeedbackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!canSubmitFeedback()) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'Send feedback',
      onPressed: () => showFeedbackSheet(context),
      icon: const Icon(Icons.feedback_outlined),
    );
  }
}
