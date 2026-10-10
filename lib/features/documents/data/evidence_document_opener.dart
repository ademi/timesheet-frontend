import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/data/models/document/document_models.dart';
import '../../../shared/utils/download_bytes.dart';
import '../../../shared/utils/open_bytes.dart';
import 'document_pipeline.dart';

/// Opens credential evidence for View (inline) vs Download (save locally).
///
/// View always uses authenticated `/content` bytes so signed URLs with
/// `Content-Disposition: attachment` cannot force a download. Download uses
/// the same bytes with an explicit save-to-disk path.
class EvidenceDocumentOpener {
  EvidenceDocumentOpener({required DocumentPipeline documentPipeline})
    : _pipeline = documentPipeline;

  final DocumentPipeline _pipeline;

  Future<void> open(DocumentOut document, {bool download = false}) async {
    final bytes = Uint8List.fromList(
      await _pipeline.fetchContentBytes(document.id),
    );
    if (download) {
      await _download(document, bytes);
      return;
    }
    await _view(document, bytes);
  }

  Future<void> _view(DocumentOut document, Uint8List bytes) async {
    if (document.contentType.startsWith('image/')) {
      await _showImagePreview(document, bytes);
      return;
    }
    if (Get.testMode) return;
    await openBytesInViewer(
      bytes: bytes,
      filename: document.filename,
      mimeType: document.contentType,
    );
  }

  Future<void> _showImagePreview(DocumentOut document, Uint8List bytes) {
    return Get.dialog<void>(
      Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        document.filename,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: Get.back,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _download(document, bytes),
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _download(DocumentOut document, Uint8List bytes) async {
    if (Get.testMode) return;
    await downloadBytesAsFile(
      bytes: bytes,
      filename: document.filename,
      mimeType: document.contentType,
    );
  }
}
