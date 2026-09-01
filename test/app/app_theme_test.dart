import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/themes/app_colors.dart';
import 'package:rostiq/main.dart' show appTheme;

void main() {
  testWidgets('input decoration uses filled card background', (tester) async {
    // ScreenUtil must be initialized before appTheme() (uses .r extensions).
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => const SizedBox.shrink(),
      ),
    );

    final theme = appTheme();
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.inputDecorationTheme.fillColor, AppColors.cardBackground);
  });
}
