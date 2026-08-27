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
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pump();
  });

  testWidgets('AppToast.success shows check_circle icon with success tokens',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: Scaffold(body: Container())));
    AppToast.success('Saved', 'Client updated.');
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pump();
  });

  testWidgets('AppToast.info shows info_outline icon with primary tokens',
      (tester) async {
    await tester.pumpWidget(GetMaterialApp(home: Scaffold(body: Container())));
    AppToast.info('Copied', 'Address copied to clipboard.');
    await tester.pump();
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    Get.closeAllSnackbars();
    await tester.pump();
  });
}
