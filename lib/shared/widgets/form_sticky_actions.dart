import 'package:flutter/material.dart';

import '../../app/themes/app_colors.dart';
import 'async_action.dart';

/// Full-width sticky form footer: Cancel (outlined) + optional secondary +
/// primary (elevated). Place after [Expanded] scroll, below [FloatingErrorNotice].
class FormStickyActions extends StatelessWidget {
  const FormStickyActions({
    super.key,
    required this.onCancel,
    required this.primaryLabel,
    required this.onPrimary,
    this.cancelLabel = 'Cancel',
    this.secondaryLabel,
    this.onSecondary,
    this.isLoading = false,
  });

  final VoidCallback? onCancel;
  final String cancelLabel;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool isLoading;

  static const _minSize = Size.fromHeight(48);
  static const _gap = SizedBox(width: 12);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading ? null : onCancel,
                style: OutlinedButton.styleFrom(minimumSize: _minSize),
                child: Text(cancelLabel),
              ),
            ),
            if (secondaryLabel != null) ...[
              _gap,
              Expanded(
                child: AsyncOutlinedButton(
                  onPressed: onSecondary,
                  isLoading: isLoading,
                  style: OutlinedButton.styleFrom(minimumSize: _minSize),
                  child: Text(secondaryLabel!),
                ),
              ),
            ],
            _gap,
            Expanded(
              child: AsyncElevatedButton(
                onPressed: onPrimary,
                isLoading: isLoading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: _minSize,
                ),
                child: Text(primaryLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
