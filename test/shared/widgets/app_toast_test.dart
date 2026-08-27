import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:rostiq/shared/widgets/app_toast.dart';

void main() {
  tearDown(Get.closeAllSnackbars);

  testWidgets('AppToast.error shows title and message', (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: Scaffold(body: Container())));
    AppToast.error('Error', 'NDIS number is required.');
    await tester.pump();
    expect(find.text('Error'), findsWidgets);
    expect(find.text('NDIS number is required.'), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pump();
  });
}
