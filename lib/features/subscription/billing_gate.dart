import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/feature_flags.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/utils/external_url.dart';
import '../../../shared/widgets/app_toast.dart';

/// Shared billing deep-link helper (design §6.12).
abstract final class BillingGate {
  BillingGate._();

  static Future<void> openBillingUrl() async {
    final ok = await openExternalUrl(AppEnv.billingUrl);
    if (!ok) {
      AppToast.error('Billing', 'Could not open ${AppEnv.billingUrl}');
    }
  }

  static Future<void> showIfNeeded(Object error) async {
    if (error is! AppFailure || !error.isBillingGate) return;
    await showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('Subscription inactive'),
        content: const Text(
          'Your organisation subscription is inactive or expired. '
          'Open billing to renew. Checkout is not available in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openBillingUrl();
            },
            child: const Text('Open billing'),
          ),
        ],
      ),
    );
  }
}

/// Convenience for launching an arbitrary https URL.
Future<bool> launchHttps(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}
