import 'package:flutter/material.dart';

/// Free-text companion shown when a preset dropdown selects "Other".
class OtherTextField extends StatelessWidget {
  const OtherTextField({
    super.key,
    required this.isOther,
    required this.controller,
    this.label = 'Please specify',
  });

  final bool isOther;
  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!isOther) return const SizedBox.shrink();
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
