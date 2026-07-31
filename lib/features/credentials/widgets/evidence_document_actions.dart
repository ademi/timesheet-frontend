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
  });

  final List<DocumentOut> documents;
  final ValueChanged<DocumentOut> onView;
  final ValueChanged<DocumentOut> onDownload;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidence files',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        for (final document in documents)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    document.filename,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isBusy ? null : () => onView(document),
                  child: const Text('View'),
                ),
                TextButton(
                  onPressed: isBusy ? null : () => onDownload(document),
                  child: const Text('Download'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
