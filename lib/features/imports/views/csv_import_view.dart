import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/themes/app_colors.dart';
import '../../../app/views/widgets/app_back_button.dart';
import '../../../core/responsive/page_content.dart';
import '../../../shared/widgets/async_action.dart';
import '../controllers/csv_import_controller.dart';
import '../data/models/import_models.dart';

class CsvImportView extends GetView<CsvImportController> {
  const CsvImportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: AppBackButton(
          fallbackRoute:
              controller.kind == ImportKind.participants
                  ? AppRoutes.staffClients
                  : AppRoutes.staffWorkforce,
        ),
        title: Text(controller.kind.title),
      ),
      body: Obx(() {
        final report = controller.commitResult.value ?? controller.preview.value;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageContent(
              width: PageContentWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    controller.kind.sampleHint,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Max 100 data rows per file. Preview writes nothing; '
                    'commit skips invalid rows.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (controller.errorMessage.value != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        controller.errorMessage.value!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: controller.pickCsvFile,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                      controller.fileName.value == null
                          ? 'Choose CSV file'
                          : 'Replace: ${controller.fileName.value}',
                    ),
                  ),
                  if (controller.hasCsv) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: controller.clearCsv,
                      child: const Text('Clear file'),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 160),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.slate200.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          controller.csvText.value,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AsyncElevatedButton(
                    onPressed:
                        controller.hasCsv && !controller.isPreviewing.value
                            ? controller.runPreview
                            : null,
                    isLoading: controller.isPreviewing.value,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Preview'),
                  ),
                  const SizedBox(height: 12),
                  AsyncElevatedButton(
                    onPressed:
                        controller.canCommit ? controller.runCommit : null,
                    isLoading: controller.isCommitting.value,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cta,
                      foregroundColor: AppColors.onCta,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Commit import'),
                  ),
                  if (report != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Report · ${report.rowCount} rows · '
                      '${report.validCount} valid · '
                      '${report.errorCount} errors'
                      '${report.createdCount != null ? ' · ${report.createdCount} created' : ''}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    // API row_number is CSV line (header = 1); show 1-based data rows.
                    ...List.generate(report.rows.length, (i) {
                      final row = report.rows[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            row.ok ? Icons.check_circle : Icons.error_outline,
                            color:
                                row.ok ? AppColors.success : AppColors.error,
                          ),
                          title: Text('Row ${i + 1}'),
                          subtitle: Text(
                            row.ok
                                ? [
                                  if (row.preview != null)
                                    row.preview!.entries
                                        .map((e) => '${e.key}: ${e.value}')
                                        .join(', '),
                                  if (row.entityId != null)
                                    'id: ${row.entityId}',
                                ].where((s) => s.isNotEmpty).join('\n')
                                : row.errors.join('\n'),
                          ),
                          isThreeLine:
                              !row.ok || (row.preview?.length ?? 0) > 1,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}
