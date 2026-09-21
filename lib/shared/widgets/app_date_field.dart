import 'package:flutter/material.dart';

/// Formats a calendar date as `yyyy-MM-dd`.
String formatAppDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Date picker control styled like a filled outlined [TextField].
///
/// Uses the app [InputDecorationTheme] (fill + border) so date entry is as
/// obvious as other form fields.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.firstDate,
    this.lastDate,
    this.initialDate,
    this.helperText,
    this.hintText,
    this.enabled = true,
    this.errorText,
    this.isDense = false,
  });

  final String label;
  final DateTime? value;

  /// When null, the field is not tappable (same as [enabled] false).
  final ValueChanged<DateTime>? onChanged;

  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Used when [value] is null as the picker's starting month/day.
  final DateTime? initialDate;

  final String? helperText;
  final String? hintText;
  final bool enabled;
  final String? errorText;
  final bool isDense;

  bool get _canPick => enabled && onChanged != null;

  Future<void> _pick(BuildContext context) async {
    if (!_canPick) return;
    final now = DateTime.now();
    final first = firstDate ?? DateTime(1900);
    final last = lastDate ?? DateTime(2100);
    var initial = value ?? initialDate ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) onChanged!(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = value == null;
    final display =
        empty
            ? (hintText ?? 'Select date')
            : formatAppDate(value!);
    final hintStyle = theme.inputDecorationTheme.hintStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          color: theme.hintColor,
        );

    return InkWell(
      onTap: _canPick ? () => _pick(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: empty,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          errorText: errorText,
          isDense: isDense,
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            size: isDense ? 18 : 22,
          ),
        ),
        child: Text(
          display,
          style: empty ? hintStyle : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
