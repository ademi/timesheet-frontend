import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../themes/app_colors.dart';

/// Four single-digit PIN boxes with auto-advance and obscured input.
class PinInputField extends StatefulWidget {
  const PinInputField({
    super.key,
    required this.controller,
    this.onCompleted,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final bool enabled;
  final bool autofocus;

  @override
  State<PinInputField> createState() => _PinInputFieldState();
}

class _PinInputFieldState extends State<PinInputField> {
  static const _length = 4;
  late final List<TextEditingController> _digitControllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _digitControllers = List.generate(_length, (_) => TextEditingController());
    _focusNodes = List.generate(_length, (_) => FocusNode());
    widget.controller.addListener(_syncFromParent);
    _syncFromParent();
  }

  void _syncFromParent() {
    final text = widget.controller.text;
    for (var i = 0; i < _length; i++) {
      final digit = i < text.length ? text[i] : '';
      if (_digitControllers[i].text != digit) {
        _digitControllers[i].text = digit;
      }
    }
  }

  void _updateParent() {
    final value = _digitControllers.map((c) => c.text).join();
    if (widget.controller.text != value) {
      widget.controller.text = value;
      widget.controller.selection = TextSelection.collapsed(offset: value.length);
    }
    if (value.length == _length) {
      widget.onCompleted?.call(value);
    }
  }

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      _fillFromPaste(index, value);
      return;
    }
    if (value.isNotEmpty && index < _length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    _updateParent();
  }

  void _fillFromPaste(int startIndex, String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    var idx = startIndex;
    for (var i = 0; i < digits.length && idx < _length; i++) {
      _digitControllers[idx].text = digits[i];
      idx++;
    }
    if (idx < _length) {
      _focusNodes[idx].requestFocus();
    } else {
      _focusNodes[_length - 1].unfocus();
    }
    _updateParent();
  }

  KeyEventResult _onKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _digitControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _digitControllers[index - 1].clear();
      _updateParent();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromParent);
    for (final c in _digitControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_length, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 6, right: index == _length - 1 ? 0 : 6),
            child: Focus(
              onKeyEvent: (node, event) => _onKeyEvent(index, event),
              child: TextField(
                controller: _digitControllers[index],
                focusNode: _focusNodes[index],
                enabled: widget.enabled,
                autofocus: widget.autofocus && index == 0,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 1,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                  ),
                ),
                onChanged: (value) => _onChanged(index, value),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Clears a [PinInputField]'s underlying controller and digit boxes.
void clearPinController(TextEditingController controller) {
  controller.clear();
}
