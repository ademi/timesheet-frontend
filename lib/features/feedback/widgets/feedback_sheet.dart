import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../app/routes/app_navigator.dart';
import '../../../app/themes/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/datasources/feedback_remote_datasource.dart';
import '../data/models/feedback_models.dart';
import '../data/repositories/feedback_repository.dart';

void ensureFeedbackRepository() {
  if (!Get.isRegistered<ApiClient>()) return;
  if (!Get.isRegistered<FeedbackRemoteDataSource>()) {
    Get.lazyPut<FeedbackRemoteDataSource>(
      () => FeedbackRemoteDataSource(
        authenticatedDio: Get.find<ApiClient>().dio,
      ),
      fenix: true,
    );
  }
  if (!Get.isRegistered<FeedbackRepository>()) {
    Get.lazyPut<FeedbackRepository>(
      () => FeedbackRepository(remote: Get.find<FeedbackRemoteDataSource>()),
      fenix: true,
    );
  }
}

Future<void> showFeedbackSheet(BuildContext context) async {
  ensureFeedbackRepository();
  if (!Get.isRegistered<FeedbackRepository>()) {
    AppToast.error('Feedback', 'Session not ready. Sign in again.');
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _FeedbackSheetBody(),
  );
}

class _FeedbackSheetBody extends StatefulWidget {
  const _FeedbackSheetBody();

  @override
  State<_FeedbackSheetBody> createState() => _FeedbackSheetBodyState();
}

class _FeedbackSheetBodyState extends State<_FeedbackSheetBody> {
  final _messageCtrl = TextEditingController();
  String _severity = 'suggestion';
  var _submitting = false;

  static const _severities = <String, String>{
    'suggestion': 'Suggestion',
    'bug': 'Bug',
    'blocker': 'Blocker',
    'info': 'Info',
  };

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      AppToast.error('Feedback', 'Please write a short message.');
      return;
    }
    if (message.length > 4000) {
      AppToast.error('Feedback', 'Message is too long (max 4000 characters).');
      return;
    }

    setState(() => _submitting = true);
    try {
      final session =
          Get.isRegistered<SessionService>()
              ? Get.find<SessionService>()
              : null;
      final roleLabel =
          session?.isContractor == true
              ? 'Support worker'
              : session?.isStaff == true
              ? 'Staff'
              : null;
      await Get.find<FeedbackRepository>().submit(
        FeedbackCreateRequest(
          message: message,
          screenRoute: AppNavigator.currentLocation,
          severity: _severity,
          roleLabel: roleLabel,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.success('Thanks', 'Your feedback was sent.');
    } on AppFailure catch (e) {
      AppToast.error('Feedback', e.message);
    } catch (_) {
      AppToast.error('Feedback', 'Could not send feedback. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send feedback', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tell us what works or what annoys you. Pilots: tap anytime.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _severity,
            decoration: const InputDecoration(
              labelText: 'Type',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final e in _severities.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged:
                _submitting
                    ? null
                    : (v) {
                      if (v != null) setState(() => _severity = v);
                    },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            enabled: !_submitting,
            maxLines: 5,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'What should we know?',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cta,
              foregroundColor: AppColors.onCta,
              minimumSize: const Size.fromHeight(48),
            ),
            child:
                _submitting
                    ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Send'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

bool canSubmitFeedback() {
  if (!Get.isRegistered<SessionService>()) return false;
  return Get.find<SessionService>().hasPermission(AppPermissions.feedbackSubmit);
}

bool canReadFeedback() {
  if (!Get.isRegistered<SessionService>()) return false;
  return Get.find<SessionService>().hasPermission(AppPermissions.feedbackRead);
}
