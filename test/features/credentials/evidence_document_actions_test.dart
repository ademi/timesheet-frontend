import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/features/credentials/widgets/evidence_document_actions.dart';

DocumentOut _doc() => const DocumentOut(
      id: 'doc-1',
      ownerType: 'contractor',
      ownerId: 'c1',
      filename: 'cert.pdf',
      contentType: 'application/pdf',
      sizeBytes: 10,
      scanStatus: 'clean',
    );

void main() {
  testWidgets('hides View when showView is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceDocumentActions(
            documents: [_doc()],
            showView: false,
            onView: (_) {},
            onDownload: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('View'), findsNothing);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('shows View by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EvidenceDocumentActions(
            documents: [_doc()],
            onView: (_) {},
            onDownload: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });
}
