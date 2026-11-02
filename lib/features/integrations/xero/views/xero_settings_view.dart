import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/responsive/page_content.dart';
import '../controllers/xero_settings_controller.dart';

/// Settings → Integrations → Xero (FE-0 placeholder; FE-1 adds connect UI).
class XeroSettingsView extends GetView<XeroSettingsController> {
  const XeroSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Xero')),
      body: PageContent(
        width: PageContentWidth.narrow,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Integrations', style: Get.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Connect Xero to optionally send posted payment batches as draft '
              'timesheets. Hours stay in Rostiq until you choose Send to Xero.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 24),
            Text('Connection', style: Get.textTheme.titleSmall),
            const SizedBox(height: 8),
            const Text(
              'Connect and disconnect controls will appear here once wired '
              'to the live Xero APIs.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
