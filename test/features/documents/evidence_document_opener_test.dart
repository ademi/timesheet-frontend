import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';
import 'package:rostiq/features/documents/data/evidence_document_opener.dart';

class _MockDocumentPipeline extends Mock implements DocumentPipeline {}

void main() {
  late _MockDocumentPipeline pipeline;
  late EvidenceDocumentOpener opener;

  setUp(() {
    Get.testMode = true;
    pipeline = _MockDocumentPipeline();
    opener = EvidenceDocumentOpener(documentPipeline: pipeline);
  });

  tearDown(Get.reset);

  test('download uses content bytes and does not open signed URL', () async {
    when(() => pipeline.fetchContentBytes('doc-1')).thenAnswer(
      (_) async => Uint8List.fromList([1, 2, 3]),
    );

    await opener.open(
      const DocumentOut(
        id: 'doc-1',
        ownerType: 'contractor',
        ownerId: 'c1',
        filename: 'drivers_licence.pdf',
        contentType: 'application/pdf',
        sizeBytes: 3,
        scanStatus: 'clean',
      ),
      download: true,
    );

    verify(() => pipeline.fetchContentBytes('doc-1')).called(1);
    verifyNever(() => pipeline.openDocument(any()));
  });
}
