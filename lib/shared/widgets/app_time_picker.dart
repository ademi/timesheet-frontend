import 'package:flutter/material.dart';

/// App-wide [showTimePicker] — **text input only** on every platform.
///
/// Uses [TimePickerEntryMode.inputOnly] so the dial UI and mode toggle are
/// never shown (web, iOS, Android, desktop).
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String? helpText,
  String? cancelText,
  String? confirmText,
  String? errorInvalidText,
  String? hourLabelText,
  String? minuteLabelText,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    initialEntryMode: TimePickerEntryMode.inputOnly,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
    errorInvalidText: errorInvalidText,
    hourLabelText: hourLabelText,
    minuteLabelText: minuteLabelText,
  );
}
