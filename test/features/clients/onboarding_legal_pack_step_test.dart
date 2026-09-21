import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/clients/controllers/client_onboarding_controller.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/models/legal_other_document.dart';
import 'package:rostiq/features/clients/widgets/onboarding/onboarding_legal_pack_step.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

class _MockSessionService extends Mock implements SessionService {}

void main() {
  late _MockClientsRepository mock;
  late _MockSessionService session;
  late ClientOnboardingController c;

  setUp(() {
    Get.testMode = true;
    mock = _MockClientsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => mock.listFormTemplates(tenantLevel: any(named: 'tenantLevel')),
    ).thenAnswer((_) async => []);
    c = ClientOnboardingController(repository: mock, session: session);
  });

  tearDown(() {
    c.dispose();
    Get.reset();
  });

  Future<void> pumpStep(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OnboardingLegalPackStep(controller: c),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows Add a document with no other rows', (tester) async {
    await pumpStep(tester);

    expect(find.text('Add a document'), findsOneWidget);
    expect(find.text('Document type'), findsNothing);
    expect(find.text('Consent agreement'), findsOneWidget);
    expect(find.text('Service agreement'), findsOneWidget);
  });

  testWidgets('Other type shows Name text field', (tester) async {
    c.addLegalOtherDoc();
    expect(c.legalOtherDocs.single.typeKey, 'other');

    await pumpStep(tester);

    expect(find.text('Document type'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
  });

  testWidgets('incomplete other row is removable', (tester) async {
    c.addLegalOtherDoc();
    final id = c.legalOtherDocs.single.id;

    await pumpStep(tester);

    expect(find.text('Remove'), findsOneWidget);
    await tester.ensureVisible(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(c.legalOtherDocs.where((e) => e.id == id), isEmpty);
    expect(find.text('Document type'), findsNothing);
    expect(find.text('Add a document'), findsOneWidget);
  });

  testWidgets('complete other row has no Remove', (tester) async {
    c.legalOtherDocs.add(
      LegalOtherDocumentDraft(
        id: 'legal-other-complete',
        typeKey: 'court_order',
        documentId: 'doc-1',
        complete: true,
      ),
    );

    await pumpStep(tester);

    expect(find.text('Court order'), findsWidgets);
    expect(find.text('Remove'), findsNothing);
    expect(find.text('Document type'), findsNothing);
  });
}
