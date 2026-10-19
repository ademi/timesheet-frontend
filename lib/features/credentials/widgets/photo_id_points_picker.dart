import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/themes/app_colors.dart';

/// Points picker for Photo ID / 100 Points of ID credentials.
class PhotoIdPointsPicker extends StatelessWidget {
  const PhotoIdPointsPicker({super.key, required this.points});

  final RxInt points;

  static const presets = <int>[25, 40, 70, 100];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final value = points.value.clamp(0, 100);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ID points (0–100)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Photo ID is satisfied when your documents total at least 100 points. '
            'You can upload multiple ID documents.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in presets)
                ChoiceChip(
                  label: Text('$p'),
                  selected: value == p,
                  onSelected: (_) => points.value = p,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '$value',
                  onChanged: (v) => points.value = v.round(),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$value',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}
