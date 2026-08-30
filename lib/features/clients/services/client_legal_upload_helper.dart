import '../../../app/data/models/document/document_models.dart';
import '../../../core/errors/app_failure.dart';
import '../../documents/data/document_pipeline.dart';
import '../data/models/client_profile_models.dart';
import '../data/repositories/clients_repository.dart';
import '../utils/onboarding_keys.dart';

/// Shared Consent / Service Agreement / Acknowledgement PDF upload + persist.
///
/// Used by onboard wizard and Care plan Consent section (Task 10 / D15).
class ClientLegalUploadHelper {
  ClientLegalUploadHelper({
    required ClientsRepository repository,
    required DocumentPipeline? pipeline,
    required Future<({String name, List<int> bytes})?> Function() pickPdfBytes,
    bool Function()? canUploadDocs,
  }) : _repository = repository,
       _pipeline = pipeline,
       _pickPdfBytes = pickPdfBytes,
       _canUploadDocs = canUploadDocs ?? (() => true);

  final ClientsRepository _repository;
  final DocumentPipeline? _pipeline;
  final Future<({String name, List<int> bytes})?> Function() _pickPdfBytes;
  final bool Function() _canUploadDocs;

  static const consentLegalUnavailableMessage =
      'Consent legal text is not published for this tenant — contact support.';

  static bool isConsentLegalUnavailable(AppFailure e) =>
      e.statusCode == 404 ||
      e.code == 'legal_version_unavailable' ||
      e.code == 'legal_document_unavailable';

  Future<void> completeConsent({
    required String clientId,
    required String participantOrRepName,
  }) async {
    final signer = participantOrRepName.trim();
    if (signer.isEmpty) {
      throw const AppFailure(
        code: 'validation',
        message: 'Enter the participant or representative name.',
        presentation: AppFailurePresentation.inline,
      );
    }
    final bytes = await _pickPdfBytes();
    if (bytes == null) {
      throw const AppFailure(
        code: 'validation',
        message: 'Select a Consent PDF to upload.',
        presentation: AppFailurePresentation.inline,
      );
    }
    final docId = await _uploadClientFile(
      clientId: clientId,
      category: 'consent',
      name: bytes.name,
      contentType: 'application/pdf',
      fileBytes: bytes.bytes,
    );
    final legalDoc = await _repository.getLegalDocumentCurrent(
      OnboardingKeys.consentAgreementDocKey,
    );
    await _repository.acceptClientLegal(
      clientId,
      OnboardingKeys.consentAgreement,
      ClientLegalAcceptRequest(
        eventType: 'consented',
        legalDocumentVersionId: legalDoc.id,
        participantOrRepName: signer,
        method: 'uploaded_scan',
        documentId: docId,
      ),
    );
  }

  Future<void> completeServiceAgreement({required String clientId}) async {
    final bytes = await _pickPdfBytes();
    if (bytes == null) {
      throw const AppFailure(
        code: 'validation',
        message: 'Select a Service Agreement PDF to upload.',
        presentation: AppFailurePresentation.inline,
      );
    }
    final docId = await _uploadClientFile(
      clientId: clientId,
      category: 'service_agreement',
      name: bytes.name,
      contentType: 'application/pdf',
      fileBytes: bytes.bytes,
    );
    await _repository.upsertProfileFact(
      clientId,
      OnboardingKeys.serviceAgreement,
      ProfileFactUpsert(documentId: docId),
    );
  }

  Future<void> completeAcknowledgement({required String clientId}) async {
    final bytes = await _pickPdfBytes();
    if (bytes == null) {
      throw const AppFailure(
        code: 'validation',
        message: 'Select an Acknowledgement PDF to upload.',
        presentation: AppFailurePresentation.inline,
      );
    }
    final docId = await _uploadClientFile(
      clientId: clientId,
      category: 'acknowledgement',
      name: bytes.name,
      contentType: 'application/pdf',
      fileBytes: bytes.bytes,
    );
    await _repository.upsertProfileFact(
      clientId,
      OnboardingKeys.acknowledgement,
      ProfileFactUpsert(documentId: docId),
    );
  }

  Future<String> _uploadClientFile({
    required String clientId,
    required String category,
    required String name,
    required String contentType,
    required List<int> fileBytes,
  }) async {
    final pipeline = _pipeline;
    if (pipeline == null) {
      throw const AppFailure(
        code: 'unknown',
        message: 'Document upload is not configured.',
        presentation: AppFailurePresentation.inline,
      );
    }
    if (!_canUploadDocs()) {
      throw const AppFailure(
        code: 'forbidden',
        message: 'Missing documents.upload / clients.docs.manage permission.',
        presentation: AppFailurePresentation.inline,
      );
    }
    final doc = await pipeline.uploadEvidence(
      request: UploadUrlRequest(
        ownerType: 'client',
        ownerId: clientId,
        filename: name,
        contentType: contentType,
        sizeBytes: fileBytes.length,
        category: category,
      ),
      bytes: fileBytes,
    );
    return doc.id;
  }
}
