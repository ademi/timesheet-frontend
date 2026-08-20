import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/views/shell/nav_overflow_split.dart';
import 'package:rostiq/app/views/shell/responsive_scaffold.dart';

ResponsiveDestination dest(String label) =>
    ResponsiveDestination(icon: Icons.circle, label: label);

void main() {
  group('NavOverflowSplit', () {
    test('returns all visible when count <= maxVisible', () {
      final all = [dest('A'), dest('B'), dest('C')];
      final result = NavOverflowSplit.split(
        destinations: all,
        selectedIndex: 1,
        maxVisible: 4,
      );
      expect(result.visible.map((d) => d.label), ['A', 'B', 'C']);
      expect(result.overflow, isEmpty);
      expect(result.moreSelected, isFalse);
    });

    test('splits overflow when count > maxVisible', () {
      final all = List.generate(6, (i) => dest('D$i'));
      final result = NavOverflowSplit.split(
        destinations: all,
        selectedIndex: 0,
        maxVisible: 4,
      );
      expect(result.visible.length, 4);
      expect(result.overflow.length, 2);
      expect(result.moreSelected, isFalse);
    });

    test('moreSelected true when selected item is in overflow', () {
      final all = [dest('H'), dest('W'), dest('C'), dest('R'), dest('P'), dest('S')];
      final result = NavOverflowSplit.split(
        destinations: all,
        selectedIndex: 4, // Payments — in overflow
        maxVisible: 4,
      );
      expect(result.visible.map((d) => d.label), ['H', 'W', 'C', 'R']);
      expect(result.overflow.map((d) => d.label), ['P', 'S']);
      expect(result.moreSelected, isTrue);
      expect(result.visibleSelectedIndex, 4); // More slot
    });

    test('moreSelected false when selected item is in visible set', () {
      final all = [dest('H'), dest('W'), dest('C'), dest('R'), dest('P'), dest('S')];
      final result = NavOverflowSplit.split(
        destinations: all,
        selectedIndex: 1, // Workforce
        maxVisible: 4,
      );
      expect(result.moreSelected, isFalse);
      expect(result.visibleSelectedIndex, 1);
    });
  });
}
