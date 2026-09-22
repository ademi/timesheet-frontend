import 'package:flutter/material.dart';

/// File picker control styled like a filled outlined [TextField].
///
/// Uses the app [InputDecorationTheme] (fill + border) so file uploads match
/// other form fields. Parent owns pick/upload/complete state via callbacks.
class AppFileField extends StatelessWidget {
  const AppFileField({
    super.key,
    required this.label,
    required this.fileName,
    required this.onPick,
    this.onClear,
    this.helperText,
    this.errorText,
    this.enabled = true,
    this.pickLabel = 'Choose file',
    this.emptyHint = '',
  });

  final String label;
  final String? fileName;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final String? helperText;
  final String? errorText;
  final bool enabled;
  final String pickLabel;
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFile = fileName != null && fileName!.trim().isNotEmpty;
    final display = hasFile ? fileName!.trim() : emptyHint;
    final hintStyle =
        theme.inputDecorationTheme.hintStyle ??
        theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor);

    return InputDecorator(
      isEmpty: !hasFile,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        enabled: enabled,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFile && onClear != null && enabled)
              IconButton(
                tooltip: 'Clear',
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            TextButton(
              onPressed: enabled ? onPick : null,
              child: Text(pickLabel),
            ),
          ],
        ),
        suffixIconConstraints: const BoxConstraints(minHeight: 48),
      ),
      child: Text(
        display,
        style: hasFile ? theme.textTheme.bodyLarge : hintStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
