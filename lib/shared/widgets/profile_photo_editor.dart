import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/themes/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../features/documents/data/datasources/documents_remote_datasource.dart';
import '../models/profile_photo_models.dart';

/// Circle avatar with view / change / remove for profile photos.
///
/// Display strategy:
/// 1. Local picked bytes (if any)
/// 2. Signed GCS [networkUrl] via [NetworkImage] (native + web when CORS is set)
/// 3. On Flutter web, if signed URL fails (CORS / fake storage) or is missing,
///    load bytes via authenticated `GET /documents/{id}/content`
class ProfilePhotoEditor extends StatefulWidget {
  const ProfilePhotoEditor({
    super.key,
    this.localBytes,
    this.networkUrl,
    this.documentId,
    this.isLoading = false,
    this.enabled = true,
    this.readOnly = false,
    this.size = 112,
    this.label = 'Profile photo',
    this.showLabel = true,
    this.onChanged,
    this.onRemove,
  });

  final List<int>? localBytes;
  final String? networkUrl;
  /// Document id for web content-proxy fallback (avoids GCS CORS).
  final String? documentId;
  final bool isLoading;
  final bool enabled;
  /// When true, shows avatar only (no camera / change controls).
  final bool readOnly;
  final double size;
  final String label;
  final bool showLabel;
  final ValueChanged<PickedProfilePhoto>? onChanged;
  final VoidCallback? onRemove;

  @override
  State<ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends State<ProfilePhotoEditor> {
  static final Map<String, Uint8List> _webBytesCache = {};

  List<int>? _proxiedBytes;
  bool _proxyLoading = false;
  String? _proxyDocId;
  bool _signedUrlFailed = false;
  ImageStream? _networkStream;
  ImageStreamListener? _networkListener;

  bool get _hasLocalBytes =>
      widget.localBytes != null && widget.localBytes!.isNotEmpty;

  bool get _hasNetworkUrl =>
      widget.networkUrl != null && widget.networkUrl!.trim().isNotEmpty;

  bool get _hasDocumentId =>
      widget.documentId != null && widget.documentId!.trim().isNotEmpty;

  bool get _preferSignedUrl => _hasNetworkUrl && !_signedUrlFailed;

  bool get _useWebProxy =>
      kIsWeb && _hasDocumentId && !_hasLocalBytes && !_preferSignedUrl;

  bool get _hasImage =>
      _hasLocalBytes ||
      (_proxiedBytes != null && _proxiedBytes!.isNotEmpty) ||
      _preferSignedUrl;

  @override
  void initState() {
    super.initState();
    _syncDisplay();
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentId != widget.documentId ||
        oldWidget.localBytes != widget.localBytes ||
        oldWidget.networkUrl != widget.networkUrl) {
      _signedUrlFailed = false;
      _syncDisplay();
    }
  }

  @override
  void dispose() {
    _detachNetworkListener();
    super.dispose();
  }

  void _syncDisplay() {
    _detachNetworkListener();
    if (_hasLocalBytes) {
      _proxiedBytes = null;
      _proxyDocId = null;
      _proxyLoading = false;
      return;
    }
    if (_preferSignedUrl) {
      _proxiedBytes = null;
      _proxyDocId = null;
      _proxyLoading = false;
      if (kIsWeb && _hasDocumentId) {
        _attachNetworkListener(NetworkImage(widget.networkUrl!.trim()));
      }
      return;
    }
    if (_useWebProxy) {
      _syncProxy();
      return;
    }
    _proxiedBytes = null;
    _proxyDocId = null;
    _proxyLoading = false;
  }

  void _detachNetworkListener() {
    if (_networkStream != null && _networkListener != null) {
      _networkStream!.removeListener(_networkListener!);
    }
    _networkStream = null;
    _networkListener = null;
  }

  void _attachNetworkListener(NetworkImage image) {
    final stream = image.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        // Signed URL loaded successfully — keep NetworkImage path.
      },
      onError: (Object error, StackTrace? stackTrace) {
        if (!mounted || _signedUrlFailed) return;
        setState(() => _signedUrlFailed = true);
        _syncProxy();
      },
    );
    _networkStream = stream;
    _networkListener = listener;
    stream.addListener(listener);
  }

  void _syncProxy() {
    if (!_useWebProxy) {
      _proxiedBytes = null;
      _proxyDocId = null;
      _proxyLoading = false;
      return;
    }
    final docId = widget.documentId!.trim();
    final cached = _webBytesCache[docId];
    if (cached != null) {
      _proxiedBytes = cached;
      _proxyDocId = docId;
      _proxyLoading = false;
      return;
    }
    if (_proxyDocId == docId && (_proxyLoading || _proxiedBytes != null)) {
      return;
    }
    unawaited(_loadProxiedBytes(docId));
  }

  Future<void> _loadProxiedBytes(String documentId) async {
    setState(() {
      _proxyLoading = true;
      _proxyDocId = documentId;
      _proxiedBytes = null;
    });
    try {
      final bytes = await _fetchDocumentBytes(documentId);
      if (!mounted || _proxyDocId != documentId) return;
      if (bytes != null && bytes.isNotEmpty) {
        final copy = Uint8List.fromList(bytes);
        _webBytesCache[documentId] = copy;
        setState(() {
          _proxiedBytes = copy;
          _proxyLoading = false;
        });
      } else {
        setState(() => _proxyLoading = false);
      }
    } catch (_) {
      if (!mounted || _proxyDocId != documentId) return;
      setState(() => _proxyLoading = false);
    }
  }

  Future<List<int>?> _fetchDocumentBytes(String documentId) async {
    DocumentsRemoteDataSource? remote;
    if (Get.isRegistered<DocumentsRemoteDataSource>()) {
      remote = Get.find<DocumentsRemoteDataSource>();
    } else if (Get.isRegistered<ApiClient>()) {
      remote = DocumentsRemoteDataSource(
        authenticatedDio: Get.find<ApiClient>().dio,
      );
    }
    if (remote == null) return null;
    return remote.getContentBytes(documentId);
  }

  Future<void> _pick(BuildContext context) async {
    if (widget.readOnly ||
        !widget.enabled ||
        widget.isLoading ||
        widget.onChanged == null) {
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;
    final name = file.name.trim().isEmpty ? 'profile.jpg' : file.name;
    widget.onChanged!(
      PickedProfilePhoto(
        name: name,
        contentType: _guessContentType(name),
        bytes: bytes,
      ),
    );
  }

  static String _guessContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.size / 2;
    final showLoading = widget.isLoading || _proxyLoading;
    ImageProvider? provider;
    if (_hasLocalBytes) {
      provider = MemoryImage(Uint8List.fromList(widget.localBytes!));
    } else if (_proxiedBytes != null && _proxiedBytes!.isNotEmpty) {
      provider = MemoryImage(
        _proxiedBytes is Uint8List
            ? _proxiedBytes as Uint8List
            : Uint8List.fromList(_proxiedBytes!),
      );
    } else if (_preferSignedUrl) {
      provider = NetworkImage(widget.networkUrl!.trim());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.showLabel && !widget.readOnly) ...[
          Text(
            widget.label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
        ],
        Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: !widget.readOnly && widget.enabled && !showLoading
                    ? () => _pick(context)
                    : null,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: radius,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: provider,
                  child: provider == null
                      ? Icon(
                          Icons.person,
                          size: widget.size * 0.45,
                          color: AppColors.textMuted,
                        )
                      : null,
                ),
              ),
            ),
            if (showLoading)
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: const CircularProgressIndicator(strokeWidth: 3),
              ),
            if (!widget.readOnly && widget.enabled && !showLoading)
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _pick(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (!widget.readOnly) ...[
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed:
                    widget.enabled && !showLoading ? () => _pick(context) : null,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(_hasImage ? 'Change photo' : 'Add photo'),
              ),
              if (_hasImage && widget.onRemove != null)
                TextButton.icon(
                  onPressed: widget.enabled && !showLoading
                      ? widget.onRemove
                      : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
