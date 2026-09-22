import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';

/// Boolean switch styled like a filled outlined [TextField].
///
/// Uses the app [InputDecorationTheme] (fill + border) so toggles match other
/// form fields.
class AppSwitchField extends StatelessWidget {
  const AppSwitchField({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.subtitle,
    this.isDense = false,
    this.activeThumbColor,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final bool isDense;
  final Color? activeThumbColor;

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.bodyLarge;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.hintColor,
    );

    return InkWell(
      onTap: _enabled ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(isDense: isDense),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: titleStyle),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: subtitleStyle),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeThumbColor ?? AppColors.onCta,
              activeTrackColor: AppColors.cta,
            ),
          ],
        ),
      ),
    );
  }
}
