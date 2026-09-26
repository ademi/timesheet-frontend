import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';
import 'package:rostiq/features/visits/sync/form_draft_models.dart';
import 'package:rostiq/features/visits/sync/form_draft_store.dart';
import 'package:rostiq/features/visits/sync/form_sync_worker.dart';

class _MockRepo extends Mock implements VisitsRepository {}

void main() {
  late GetStorage box;
  late FormDraftStore store;
  late _MockRepo repo;
  late StreamController<List<ConnectivityResult>> connectivity;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('form_sync_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return storageDirectory.path;
      }
      return null;
    });
    registerFallbackValue(
      const VisitFormSubmitRequest(
        formTemplateId: 't',
        payloadJson: {},
      ),
    );
  });

  tearDownAll(() async {
    try {
      await storageDirectory.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await GetStorage.init('form_sync_worker_test');
    box = GetStorage('form_sync_worker_test');
    await box.erase();
    store = FormDraftStore(box);
    repo = _MockRepo();
    connectivity = StreamController<List<ConnectivityResult>>.broadcast();
  });

  tearDown(() async {
    await connectivity.close();
  });

  test('airplane write then online flush ACKs draft', () async {
    await store.upsert(
      FormDraftItem(
        draftKey: FormDraftItem.makeKey(visitId: 'v1', formTemplateId: 't1'),
        visitId: 'v1',
        formTemplateId: 't1',
        payloadJson: {'notes': 'offline'},
        updatedAtIso: DateTime.utc(2026, 9, 26).toIso8601String(),
        clientEventId: 'evt-chaos',
        stage: FormDraftStage.queued,
      ),
    );

    when(
      () => repo.submitForm(
        visitId: any(named: 'visitId'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async {});

    FormDraftItem? acked;
    final worker = FormSyncWorker(
      store: store,
      repository: repo,
      connectivityStream: connectivity.stream,
      observeLifecycle: false,
      onAcked: (item) => acked = item,
    );
    worker.start();

    connectivity.add([ConnectivityResult.wifi]);
    await worker.flush();

    expect(store.all(), isEmpty);
    expect(acked?.clientEventId, 'evt-chaos');
    verify(
      () => repo.submitForm(
        visitId: 'v1',
        body: any(
          named: 'body',
          that: isA<VisitFormSubmitRequest>().having(
            (b) => b.clientEventId,
            'clientEventId',
            'evt-chaos',
          ),
        ),
      ),
    ).called(1);

    worker.dispose();
  });

  test('transient failure keeps payload for retry', () async {
    await store.upsert(
      FormDraftItem(
        draftKey: FormDraftItem.makeKey(visitId: 'v1', formTemplateId: 't1'),
        visitId: 'v1',
        formTemplateId: 't1',
        payloadJson: {'notes': 'retry me'},
        updatedAtIso: DateTime.utc(2026, 9, 26).toIso8601String(),
        clientEventId: 'evt-fail',
        stage: FormDraftStage.queued,
      ),
    );

    when(
      () => repo.submitForm(
        visitId: any(named: 'visitId'),
        body: any(named: 'body'),
      ),
    ).thenThrow(
      const AppFailure(
        code: 'network',
        message: 'offline',
        presentation: AppFailurePresentation.toast,
        statusCode: 503,
      ),
    );

    final worker = FormSyncWorker(
      store: store,
      repository: repo,
      connectivityStream: connectivity.stream,
      observeLifecycle: false,
      backoffForAttempt: (_) => Duration.zero,
    );
    worker.start();
    await worker.flush();

    final left = store.all().single;
    expect(left.stage, FormDraftStage.failed);
    expect(left.payloadJson['notes'], 'retry me');
    expect(left.isTerminalFailure, isFalse);

    worker.dispose();
  });
}
