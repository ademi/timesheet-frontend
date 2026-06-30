import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:rostiq/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
          return '.';
        default:
          return null;
      }
    });
    await GetStorage.init();
  });

  testWidgets('Rostiq app loads gateway screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RostiqApp());
    await tester.pumpAndSettle();

    expect(find.text('Select Your Portal'), findsOneWidget);
  });
}
