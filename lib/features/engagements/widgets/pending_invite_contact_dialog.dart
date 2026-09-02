import 'package:flutter/material.dart';

import 'package:rostiq/app/utils/email_utils.dart';
import '../data/models/engagement_models.dart';

class PendingInviteContactDialog extends StatefulWidget {
  const PendingInviteContactDialog({super.key, required this.invite});

  final ContractorRegistrationInviteOut invite;

  @override
  State<PendingInviteContactDialog> createState() =>
      _PendingInviteContactDialogState();
}

class _PendingInviteContactDialogState extends State<PendingInviteContactDialog> {
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.invite.email);
    _phoneCtrl = TextEditingController(text: widget.invite.phone ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final email = EmailUtils.normalize(_emailCtrl.text);
    final phoneRaw = _phoneCtrl.text.trim();
    final phone = phoneRaw.isEmpty ? '' : phoneRaw;
    Navigator.of(context).pop(<String, String?>{
      'email': email,
      'phone': phone,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update contact details'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: EmailUtils.validationError,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Changing the email sends a new invitation to the updated address.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
