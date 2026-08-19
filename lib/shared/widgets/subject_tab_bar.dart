import 'package:flutter/material.dart';

class SubjectTabBar extends StatelessWidget {
  const SubjectTabBar({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
    this.keyPrefix = 'subject-tab',
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: ValueKey('$keyPrefix-$i'),
                label: Text(labels[i]),
                selected: index == i,
                onSelected: (_) => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}
