import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rostiq/app/themes/app_colors.dart';
import 'package:rostiq/shared/widgets/eligibility_incomplete_panel.dart';

void main() {
  testWidgets('uses openSlot tokens for panel decoration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EligibilityIncompletePanel(reasons: ['Missing NDIS number']),
        ),
      ),
    );

    final box = tester.widget<Container>(find.byType(Container));
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.openSlotBackground);
    expect(
      (decoration.border as Border).top.color,
      AppColors.openSlot.withValues(alpha: 0.45),
    );
  });

  test('panel source must not hardcode legacy orange border', () {
    final panelPath = p.join(
      Directory.current.path,
      'lib/shared/widgets/eligibility_incomplete_panel.dart',
    );
    final source = File(panelPath).readAsStringSync();
    expect(source, isNot(contains('0xFFFDBA74')));
    expect(source, isNot(contains('0xFFFFF7ED')));
  });
}
