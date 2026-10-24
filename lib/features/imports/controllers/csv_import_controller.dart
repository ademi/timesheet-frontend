import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_navigator.dart';
import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/models/import_models.dart';
import '../data/repositories/imports_repository.dart';

class CsvImportController extends GetxController {
  CsvImportController({
    required ImportsRepository repository,
    required this.kind,
  }) : _repository = repository;

  final ImportsRepository _repository;
  final ImportKind kind;

  final csvText = ''.obs;
  final fileName = RxnString();
  final preview = Rxn<ImportReportOut>();
  final commitResult = Rxn<ImportReportOut>();
  final isPreviewing = false.obs;
  final isCommitting = false.obs;
  final errorMessage = RxnString();

  bool get hasCsv => csvText.value.trim().isNotEmpty;
  bool get canCommit =>
      hasCsv &&
      preview.value != null &&
      (preview.value!.validCount > 0) &&
      !isCommitting.value &&
      !isPreviewing.value;

  Future<void> pickCsvFile() async {
    errorMessage.value = null;
    commitResult.value = null;
    preview.value = null;
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      errorMessage.value = 'Could not read file bytes.';
      return;
    }
    fileName.value = file.name;
    csvText.value = utf8.decode(bytes, allowMalformed: true);
  }

  void clearCsv() {
    csvText.value = '';
    fileName.value = null;
    preview.value = null;
    commitResult.value = null;
    errorMessage.value = null;
  }

  Future<void> runPreview() async {
    if (!hasCsv) {
      errorMessage.value = 'Pick a CSV file first.';
      return;
    }
    isPreviewing.value = true;
    errorMessage.value = null;
    commitResult.value = null;
    try {
      preview.value = await _repository.preview(kind, csvText.value);
    } on AppFailure catch (e) {
      preview.value = null;
      errorMessage.value = e.message;
      AppToast.error('Preview failed', e.message);
    } catch (_) {
      preview.value = null;
      errorMessage.value = 'Could not preview this CSV.';
    } finally {
      isPreviewing.value = false;
    }
  }

  Future<void> runCommit() async {
    if (!canCommit) return;
    isCommitting.value = true;
    errorMessage.value = null;
    try {
      final report = await _repository.commit(kind, csvText.value);
      commitResult.value = report;
      preview.value = report;
      final created = report.createdCount ?? report.validCount;
      AppToast.success(
        'Import finished',
        '$created created · ${report.errorCount} skipped with errors',
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      AppToast.error('Import failed', e.message);
    } catch (_) {
      errorMessage.value = 'Could not commit this CSV.';
    } finally {
      isCommitting.value = false;
    }
  }

  void close() => AppNavigator.pop();
}
