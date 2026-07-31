import 'package:url_launcher/url_launcher.dart';

import '../../../app/data/models/document/document_models.dart';
import '../../../core/errors/app_failure.dart';
import 'datasources/documents_remote_datasource.dart';

/// Upload → finalize → poll scan; signed URL vs `/content` proxy (design §6.4).
class DocumentPipeline {
  DocumentPipeline({required DocumentsRemoteDataSource remote})
    : _remote = remote;

  final DocumentsRemoteDataSource _remote;

  Future<DocumentOut> uploadEvidence({
    required UploadUrlRequest request,
    required List<int> bytes,
    String? credentialId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final upload = await _remote.createUploadUrl(request);
    await _remote.putToSignedUrl(
      uploadUrl: upload.uploadUrl,
      contentType: request.contentType,
      bytes: bytes,
      onSendProgress: onSendProgress,
    );
    return _remote.finalize(
      documentId: upload.documentId,
      credentialId: credentialId,
    );
  }

  /// Poll until scan is `clean` or `blocked` (or timeout).
  Future<DocumentOut> pollScanStatus({
    required String documentId,
    required String ownerType,
    required String ownerId,
    Duration interval = const Duration(seconds: 2),
    int maxAttempts = 30,
  }) async {
    DocumentOut? last;
    for (var i = 0; i < maxAttempts; i++) {
      final docs = await _remote.listForOwner(
        ownerType: ownerType,
        ownerId: ownerId,
      );
      last = null;
      for (final d in docs) {
        if (d.id == documentId) {
          last = d;
          break;
        }
      }
      if (last != null && (last.isScanClean || last.isScanBlocked)) {
        return last;
      }
      await Future<void>.delayed(interval);
    }
    throw const AppFailure(
      code: 'unknown',
      message: 'Document scan still pending. Refresh later.',
      presentation: AppFailurePresentation.toast,
    );
  }

  /// Prefer signed download URL; fall back to `/content` on `proxy_required`.
  Future<DocumentOpenResult> openDocument(String documentId) async {
    try {
      final url = await _remote.getDownloadUrl(documentId);
      final uri = Uri.parse(url.downloadUrl);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        throw const AppFailure(
          code: 'unknown',
          message: 'Could not open download URL',
          presentation: AppFailurePresentation.toast,
        );
      }
      return DocumentOpenResult.signedUrl(url.downloadUrl);
    } on AppFailure catch (e) {
      if (!e.isProxyRequired) rethrow;
      final bytes = await _remote.getContentBytes(documentId);
      return DocumentOpenResult.proxyBytes(bytes);
    }
  }
}

enum DocumentOpenMode { signedUrl, proxyBytes }

class DocumentOpenResult {
  const DocumentOpenResult._({required this.mode, this.signedUrl, this.bytes});

  factory DocumentOpenResult.signedUrl(String url) =>
      DocumentOpenResult._(mode: DocumentOpenMode.signedUrl, signedUrl: url);

  factory DocumentOpenResult.proxyBytes(List<int> bytes) =>
      DocumentOpenResult._(mode: DocumentOpenMode.proxyBytes, bytes: bytes);

  final DocumentOpenMode mode;
  final String? signedUrl;
  final List<int>? bytes;

  bool get usedProxy => mode == DocumentOpenMode.proxyBytes;
}
