import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/themes/app_colors.dart';
import '../models/profile_photo_models.dart';

/// Circle avatar with view / change / remove for profile photos.
class ProfilePhotoEditor extends StatelessWidget {
  const ProfilePhotoEditor({
    super.key,
    this.localBytes,
    this.networkUrl,
    this.isLoading = false,
    this.enabled = true,
    this.size = 112,
    this.label = 'Profile photo',
    this.onChanged,
    this.onRemove,
  });

  final List<int>? localBytes;
  final String? networkUrl;
  final bool isLoading;
  final bool enabled;
  final double size;
  final String label;
  final ValueChanged<PickedProfilePhoto>? onChanged;
  final VoidCallback? onRemove;

  bool get _hasImage =>
      (localBytes != null && localBytes!.isNotEmpty) ||
      (networkUrl != null && networkUrl!.trim().isNotEmpty);

  Future<void> _pick(BuildContext context) async {
    if (!enabled || isLoading || onChanged == null) return;
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
    onChanged!(
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
    final radius = size / 2;
    ImageProvider? provider;
    if (localBytes != null && localBytes!.isNotEmpty) {
      provider = MemoryImage(Uint8List.fromList(localBytes!));
    } else if (networkUrl != null && networkUrl!.trim().isNotEmpty) {
      provider = NetworkImage(networkUrl!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled && !isLoading ? () => _pick(context) : null,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: radius,
                  backgroundColor: AppColors.primaryLight,
                  backgroundImage: provider,
                  child: provider == null
                      ? Icon(
                          Icons.person,
                          size: size * 0.45,
                          color: AppColors.textMuted,
                        )
                      : null,
                ),
              ),
            ),
            if (isLoading)
              SizedBox(
                width: size,
                height: size,
                child: const CircularProgressIndicator(strokeWidth: 3),
              ),
            if (enabled && !isLoading)
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
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: enabled && !isLoading ? () => _pick(context) : null,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(_hasImage ? 'Change photo' : 'Add photo'),
            ),
            if (_hasImage && onRemove != null)
              TextButton.icon(
                onPressed: enabled && !isLoading ? onRemove : null,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}
