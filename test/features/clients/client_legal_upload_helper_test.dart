import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/app/data/models/document/document_models.dart';
import 'package:rostiq/core/errors/app_failure.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/services/client_legal_upload_helper.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/documents/data/document_pipeline.dart';

class _MockRepo extends Mock implements ClientsRepository {}

class _MockPipeline extends Mock implements DocumentPipeline {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const UploadUrlRequest(
        ownerType: 'client',
        ownerId: 'c1',
        filename: 'x.pdf',
        contentType: 'application/pdf',
        sizeBytes: 1,
        category: 'consent',
      ),
    );
    registerFallbackValue(
      const ClientLegalAcceptRequest(
        eventType: 'consented',
        legalDocumentVersionId: 'v1',
        participantOrRepName: 'x',
        method: 'uploaded_scan',
      ),
    );
    registerFallbackValue(const ProfileFactUpsert());
  });

  late _MockRepo repo;
  late _MockPipeline pipeline;

  setUp(() {
    repo = _MockRepo();
    pipeline = _MockPipeline();
  });

  test('completeConsent uploads then accepts with documentId', () async {
    when(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer(
      (_) async => const DocumentOut(
        id: 'doc-1',
        ownerType: 'client',
        ownerId: 'c1',
        filename: 'consent.pdf',
        contentType: 'application/pdf',
        sizeBytes: 3,
        scanStatus: 'clean',
      ),
    );
    when(() => repo.getLegalDocumentCurrent(any())).thenAnswer(
      (_) async => const ClientLegalDocumentCurrent(
        id: 'legal-v1',
        title: 'Consent',
        contentMd: '# Consent',
      ),
    );
    when(() => repo.acceptClientLegal(any(), any(), any()))
        .thenAnswer((_) async {});

    final helper = ClientLegalUploadHelper(
      repository: repo,
      pipeline: pipeline,
      pickPdfBytes: () async => (name: 'consent.pdf', bytes: [1, 2, 3]),
    );

    await helper.completeConsent(
      clientId: 'c1',
      participantOrRepName: 'Sam Parent',
    );

    final captured = verify(
      () => repo.acceptClientLegal(
        'c1',
        OnboardingKeys.consentAgreement,
        captureAny(),
      ),
    ).captured.single as ClientLegalAcceptRequest;
    expect(captured.documentId, 'doc-1');
    expect(captured.participantOrRepName, 'Sam Parent');
    verify(
      () => repo.getLegalDocumentCurrent(OnboardingKeys.consentAgreementDocKey),
    ).called(1);
  });

  test('completeConsent throws when signer empty', () async {
    final helper = ClientLegalUploadHelper(
      repository: repo,
      pipeline: pipeline,
      pickPdfBytes: () async => (name: 'consent.pdf', bytes: [1, 2, 3]),
    );

    expect(
      () => helper.completeConsent(clientId: 'c1', participantOrRepName: '  '),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          contains('participant or representative'),
        ),
      ),
    );
    verifyNever(() => pipeline.uploadEvidence(
          request: any(named: 'request'),
          bytes: any(named: 'bytes'),
        ));
  });

  test('completeServiceAgreement upserts document_id fact', () async {
    when(
      () => pipeline.uploadEvidence(
        request: any(named: 'request'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer(
      (_) async => const DocumentOut(
        id: 'doc-sa',
        ownerType: 'client',
        ownerId: 'c1',
        filename: 'sa.pdf',
        contentType: 'application/pdf',
        sizeBytes: 2,
        scanStatus: 'clean',
      ),
    );
    when(() => repo.upsertProfileFact(any(), any(), any()))
        .thenAnswer((_) async {});

    final helper = ClientLegalUploadHelper(
      repository: repo,
      pipeline: pipeline,
      pickPdfBytes: () async => (name: 'sa.pdf', bytes: [9, 9]),
    );

    await helper.completeServiceAgreement(clientId: 'c1');

    final upsert = verify(
      () => repo.upsertProfileFact(
        'c1',
        OnboardingKeys.serviceAgreement,
        captureAny(),
      ),
    ).captured.single as ProfileFactUpsert;
    expect(upsert.documentId, 'doc-sa');
  });
}
