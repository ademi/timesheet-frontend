import 'package:flutter/material.dart';

import '../../../app/data/models/document/document_models.dart';
import '../../../app/themes/app_colors.dart';

class EvidenceDocumentActions extends StatelessWidget {
  const EvidenceDocumentActions({
    super.key,
    required this.documents,
    required this.onView,
    required this.onDownload,
    this.isBusy = false,
    this.showWhenEmpty = false,
    this.emptyMessage = 'No evidence file attached.',
    this.showView = true,
  });

  final List<DocumentOut> documents;
  final ValueChanged<DocumentOut> onView;
  final ValueChanged<DocumentOut> onDownload;
  final bool isBusy;
  final bool showWhenEmpty;
  final String emptyMessage;
  final bool showView;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty && !showWhenEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidence files',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        if (documents.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          )
        else
          for (final document in documents)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.filename,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (showView)
                        OutlinedButton.icon(
                          onPressed: isBusy ? null : () => onView(document),
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: const Text('View'),
                        ),
                      OutlinedButton.icon(
                        onPressed: isBusy ? null : () => onDownload(document),
                        icon: const Icon(Icons.download_outlined, size: 18),
                        label: const Text('Download'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
