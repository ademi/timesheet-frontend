import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:rostiq/features/contractor_onboarding/data/onboarding_progress_store.dart';

void main() {
  late OnboardingProgressStore store;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp(
      'rostiq_onboarding_progress_',
    );
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return storageDirectory.path;
          }
          return null;
        });
    await GetStorage.init();
  });

  tearDownAll(() async {
    await storageDirectory.delete(recursive: true);
  });

  setUp(() {
    store = OnboardingProgressStore();
  });

  test(
    'legacy global flag does not complete a new contractor platform',
    () async {
      await GetStorage().write('onboarding_funnel_v1_done', true);

      expect(store.isPlatformComplete('new-contractor'), isFalse);
    },
  );

  test('platform completion is scoped to the contractor', () async {
    await store.markPlatformComplete('contractor-a');

    expect(store.isPlatformComplete('contractor-a'), isTrue);
    expect(store.isPlatformComplete('contractor-b'), isFalse);
  });

  test('marking credentials step done preserves accepted progress', () async {
    await store.save(
      'contractor-a',
      const OnboardingProgressSnapshot(
        acceptedDocVersions: {'platform_terms': 'v1'},
      ),
    );

    await store.markCredentialsStepDone('contractor-a');

    final snapshot = store.load('contractor-a');
    expect(snapshot.acceptedDocVersions, {'platform_terms': 'v1'});
    expect(snapshot.platformComplete, isTrue);
  });
}
