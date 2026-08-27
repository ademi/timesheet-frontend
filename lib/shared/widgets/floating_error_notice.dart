import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';

/// Persistent form error, placed between the scrolling body and sticky footer.
///
/// [SemanticsRole.alert] is omitted because Flutter forbids combining it with
/// liveRegion; this widget uses liveRegion only.
class FloatingErrorNotice extends StatelessWidget {
  const FloatingErrorNotice({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.errorBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: AppColors.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
