import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/themes/app_colors.dart';

/// Read-only markdown viewer for legal docs / notices (design §3.2).
class MarkdownViewer extends StatelessWidget {
  const MarkdownViewer({
    super.key,
    required this.markdown,
    this.padding = const EdgeInsets.all(16),
  });

  final String markdown;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Markdown(
      data: markdown,
      selectable: true,
      padding: padding,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: const TextStyle(fontSize: 14, height: 1.45, color: AppColors.textDark),
        h1: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        h2: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
