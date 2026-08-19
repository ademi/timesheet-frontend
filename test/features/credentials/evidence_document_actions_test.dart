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

  testWidgets('View and Download share the row equally', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 400));
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: EvidenceDocumentActions(
              documents: [_doc()],
              onView: (_) {},
              onDownload: (_) {},
            ),
          ),
        ),
      ),
    );
    final view = tester.getSize(find.widgetWithText(OutlinedButton, 'View'));
    final download =
        tester.getSize(find.widgetWithText(OutlinedButton, 'Download'));
    expect((view.width - download.width).abs() < 1, true);
    expect(view.width > 140, true);
  });
}
