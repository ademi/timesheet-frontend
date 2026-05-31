import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../themes/app_colors.dart';
import '../../data/models/auth/auth_error_model.dart';
import 'pin_input_field.dart';

/// Dialog for creating a 4-digit PIN (enter + confirm).
class SetPinDialog extends StatefulWidget {
  const SetPinDialog({
    super.key,
    required this.email,
    required this.onSubmit,
    this.title = 'Create your PIN',
    this.subtitle = 'Choose a 4-digit PIN to continue.',
    this.submitLabel = 'Save PIN',
  });

  final String email;
  final Future<bool> Function(String pin, String confirmPin) onSubmit;
  final String title;
  final String subtitle;
  final String submitLabel;

  @override
  State<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<SetPinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _error = ''.obs;
  final _busy = false.obs;

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (pin.length != 4) {
      _error.value = 'PIN must be 4 digits';
      return;
    }
    if (confirm.length != 4) {
      _error.value = 'Please confirm your 4-digit PIN';
      return;
    }
    if (pin != confirm) {
      _error.value = 'PINs do not match';
      return;
    }

    _busy.value = true;
    _error.value = '';
    try {
      final ok = await widget.onSubmit(pin, confirm);
      if (ok && mounted) {
        Get.back(result: pin);
      }
    } on AuthErrorModel catch (e) {
      _error.value = e.detail;
    } catch (e) {
      _error.value = e.toString();
    } finally {
      _busy.value = false;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBrown,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'New PIN',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              PinInputField(
                controller: _pinController,
                autofocus: true,
                enabled: !_busy.value,
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm PIN',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              PinInputField(
                controller: _confirmController,
                enabled: !_busy.value,
              ),
              Obx(() {
                if (_error.value.isEmpty) return const SizedBox(height: 12);
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error.value,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Obx(() {
                final busy = _busy.value;
                return Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy ? null : () => Get.back(result: false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(widget.submitLabel),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
