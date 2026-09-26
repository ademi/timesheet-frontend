import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:rostiq/features/visits/sync/form_draft_models.dart';
import 'package:rostiq/features/visits/sync/form_draft_store.dart';

void main() {
  late GetStorage box;
  late FormDraftStore store;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('form_draft_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return storageDirectory.path;
      }
      return null;
    });
  });

  tearDownAll(() async {
    try {
      await storageDirectory.delete(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await GetStorage.init('form_draft_test');
    box = GetStorage('form_draft_test');
    await box.erase();
    store = FormDraftStore(box);
  });

  FormDraftItem draft({
    String visitId = 'v1',
    String templateId = 't1',
    String? participantId,
    FormDraftStage stage = FormDraftStage.draft,
    String? clientEventId,
    Map<String, dynamic>? payload,
  }) {
    return FormDraftItem(
      draftKey: FormDraftItem.makeKey(
        visitId: visitId,
        formTemplateId: templateId,
        participantId: participantId,
      ),
      visitId: visitId,
      formTemplateId: templateId,
      participantId: participantId,
      supportItemCode: '01_010_0107_1_1',
      payloadJson: payload ?? {'notes': 'hello'},
      updatedAtIso: DateTime.utc(2026, 9, 26, 10).toIso8601String(),
      stage: stage,
      clientEventId: clientEventId,
    );
  }

  test('upsert persist / restore after process kill', () async {
    await store.upsert(draft());
    expect(store.pendingUnsent(), hasLength(1));

    final restored = FormDraftStore(box);
    final item = restored.get(visitId: 'v1', formTemplateId: 't1');
    expect(item?.payloadJson['notes'], 'hello');
    expect(item?.supportItemCode, '01_010_0107_1_1');
  });

  test('clear only on ACK', () async {
    await store.upsert(
      draft(stage: FormDraftStage.queued, clientEventId: 'evt-1'),
    );
    expect(store.pendingFlush(), hasLength(1));
    await store.ackByClientEventId('evt-1');
    expect(store.all(), isEmpty);
  });

  test('crash mid-note: draft survives without ACK', () async {
    await store.upsert(draft(payload: {'notes': 'partial'}));
    final afterCrash = FormDraftStore(box);
    expect(afterCrash.get(visitId: 'v1', formTemplateId: 't1')!.payloadJson['notes'],
        'partial');
  });

  test('per-participant key differs from group-level', () async {
    await store.upsert(draft());
    await store.upsert(draft(participantId: 'pax-2', payload: {'notes': 'p2'}));
    expect(store.all(), hasLength(2));
    expect(
      store.get(visitId: 'v1', formTemplateId: 't1', participantId: 'pax-2')!
          .payloadJson['notes'],
      'p2',
    );
  });

  test('clearDestructive blocked without confirm', () async {
    await store.upsert(draft());
    expect(
      () => store.clearDestructive(confirmDiscard: false),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          'form_draft_not_empty',
        ),
      ),
    );
    store.clearDestructive(confirmDiscard: true);
    expect(store.all(), isEmpty);
  });

  test('airplane queue then markAttempt / flush path', () async {
    await store.upsert(
      draft(stage: FormDraftStage.queued, clientEventId: 'evt-2'),
    );
    await store.markAttempt(
      FormDraftItem.makeKey(visitId: 'v1', formTemplateId: 't1'),
      'network',
    );
    final failed = store.pendingFlush().single;
    expect(failed.stage, FormDraftStage.failed);
    expect(failed.attempts, 1);
    expect(failed.payloadJson['notes'], 'hello');
  });
}
