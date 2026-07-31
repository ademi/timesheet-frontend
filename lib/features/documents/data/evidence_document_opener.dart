import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/data/models/document/document_models.dart';
import 'document_pipeline.dart';

class EvidenceDocumentOpener {
  EvidenceDocumentOpener({required DocumentPipeline documentPipeline})
    : _pipeline = documentPipeline;

  final DocumentPipeline _pipeline;

  Future<void> open(DocumentOut document, {bool download = false}) async {
    final result = await _pipeline.openDocument(document.id);
    if (!result.usedProxy) return;

    final bytes = Uint8List.fromList(result.bytes!);
    if (!download && document.contentType.startsWith('image/')) {
      await _showImagePreview(document, bytes);
      return;
    }
    await _share(document, bytes);
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
                  onPressed: () => _share(document, bytes),
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

  Future<void> _share(DocumentOut document, Uint8List bytes) {
    return SharePlus.instance.share(
      ShareParams(
        title: document.filename,
        files: [XFile.fromData(bytes, mimeType: document.contentType)],
        fileNameOverrides: [document.filename],
      ),
    );
  }
}
