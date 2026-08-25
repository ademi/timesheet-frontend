import 'package:flutter/material.dart';

/// Formats [time] as zero-padded `HH:mm`.
String formatHhMm(TimeOfDay time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}';
}

/// Parses `H:mm`, `HH:mm`, or compact `HHmm`. Returns null when invalid.
TimeOfDay? parseHhMm(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  final colonMatch = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
  if (colonMatch != null) {
    final hour = int.parse(colonMatch.group(1)!);
    final minute = int.parse(colonMatch.group(2)!);
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  final compactMatch = RegExp(r'^(\d{4})$').firstMatch(trimmed);
  if (compactMatch != null) {
    final hour = int.parse(trimmed.substring(0, 2));
    final minute = int.parse(trimmed.substring(2, 4));
    if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
      return TimeOfDay(hour: hour, minute: minute);
    }
    return null;
  }

  return null;
}

/// Keyboard-first time entry with optional dial picker via trailing icon.
class KeyboardTimeField extends StatefulWidget {
  const KeyboardTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
  });

  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  final String? label;
  final bool enabled;

  @override
  State<KeyboardTimeField> createState() => _KeyboardTimeFieldState();
}

class _KeyboardTimeFieldState extends State<KeyboardTimeField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: formatHhMm(widget.value));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(KeyboardTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      final text = formatHhMm(widget.value);
      if (_controller.text != text) {
        _controller.text = text;
      }
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final parsed = parseHhMm(_controller.text);
    if (parsed == null) {
      setState(() {
        _errorText = 'Enter time as HH:mm';
        _controller.text = formatHhMm(widget.value);
      });
      return;
    }

    setState(() => _errorText = null);
    _controller.text = formatHhMm(parsed);
    if (parsed != widget.value) {
      widget.onChanged(parsed);
    }
  }

  Future<void> _openDialPicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.value,
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _controller.text = formatHhMm(picked);
        _errorText = null;
      });
      if (picked != widget.value) {
        widget.onChanged(picked);
      }
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: 'HH:mm',
        errorText: _errorText,
        suffixIcon: IconButton(
          icon: const Icon(Icons.access_time),
          tooltip: 'Pick time',
          onPressed: widget.enabled ? _openDialPicker : null,
        ),
      ),
      keyboardType: TextInputType.datetime,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _commit(),
    );
  }
}
