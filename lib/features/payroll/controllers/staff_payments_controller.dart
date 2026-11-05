import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/constants/app_permissions.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/utils/humanize_label.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../integrations/xero/data/repositories/xero_repository.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../data/models/payroll_models.dart';
import '../data/repositories/payroll_repository.dart';

class ContractorBatchCandidate {
  const ContractorBatchCandidate({
    required this.contractorId,
    required this.contractorName,
    required this.visits,
    required this.totalHours,
    required this.firstVisitAt,
    required this.lastVisitAt,
  });

  final String contractorId;
  final String contractorName;
  final List<VisitOut> visits;
  final double totalHours;
  final DateTime firstVisitAt;
  final DateTime lastVisitAt;

  int get visitCount => visits.length;
  List<String> get visitIds =>
      visits.map((visit) => visit.id).toList(growable: false);
}

class StaffPaymentsController extends GetxController {
  StaffPaymentsController({
    required PayrollRepository payroll,
    required VisitsRepository visits,
    required SessionService session,
    XeroRepository? xero,
  }) : _payroll = payroll,
       _visits = visits,
       _session = session,
       _xero = xero;

  final PayrollRepository _payroll;
  final VisitsRepository _visits;
  final SessionService _session;
  final XeroRepository? _xero;

  final tabIndex = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final isExportingXero = false.obs;
  final errorMessage = RxnString();

  final batches = <PaymentBatchOut>[].obs;
  final selectedBatch = Rxn<PaymentBatchOut>();
  final batchStatusFilter = ''.obs;

  final unpaidVisits = <VisitOut>[].obs;
  final selectedContractorIds = <String>{}.obs;

  final periodLabelCtrl = TextEditingController();
  final contractorFilterCtrl = TextEditingController();
  final contractorFilter = ''.obs;
  late final Rx<DateTimeRange> periodRange;

  /// Optional Xero — UI hidden unless connected + feature enabled.
  final xeroFeatureEnabled = true.obs;
  final xeroConnected = false.obs;
  final xeroMappingComplete = false.obs;

  bool get canView =>
      _session.hasPermission(AppPermissions.paymentsView) ||
      _session.hasPermission(AppPermissions.paymentsManage);
  bool get canManage => _session.hasPermission(AppPermissions.paymentsManage);

  bool get showXeroUi =>
      xeroFeatureEnabled.value && xeroConnected.value;

  /// Send only for posted, connected, mapping complete, not already sent.
  bool get canSendSelectedToXero {
    final batch = selectedBatch.value;
    if (!showXeroUi || !canManage || batch == null) return false;
    if (!batch.isPosted) return false;
    if (!xeroMappingComplete.value) return false;
    if (batch.xeroSent) return false;
    return true;
  }

  String? get sendToXeroBlockedReason {
    final batch = selectedBatch.value;
    if (!showXeroUi || batch == null) return null;
    if (!batch.isPosted) return 'Post the batch before sending to Xero.';
    if (!xeroMappingComplete.value) {
      return 'Finish worker and pay-item mappings in Settings → Xero.';
    }
    if (batch.xeroSent) return 'Already sent to Xero.';
    if (!canManage) return 'Missing payments.manage permission.';
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    periodRange = DateTimeRange(start: today, end: today).obs;
    periodLabelCtrl.text = _periodLabelFor(periodRange.value);
    contractorFilterCtrl.addListener(() {
      contractorFilter.value = contractorFilterCtrl.text.trim();
    });
    loadAll();
  }

  /// Tier-2 shell re-enter: soft reload; clear batch create selection drafts.
  void onScreenReenter() {
    errorMessage.value = null;
    selectedContractorIds.clear();
    selectedBatch.value = null;
    // ignore: discarded_futures
    loadAll();
  }

  @override
  void onClose() {
    periodLabelCtrl.dispose();
    contractorFilterCtrl.dispose();
    super.onClose();
  }

  Future<void> loadAll() async {
    if (!canView) {
      errorMessage.value = 'Missing payments.view permission.';
      return;
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadBatches();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
    try {
      await _loadUnpaidVisits();
    } on AppFailure catch (e) {
      errorMessage.value ??= e.message;
    }
    await _loadXeroConnection();
    isLoading.value = false;
  }

  Future<void> _loadXeroConnection() async {
    final xero = _xero;
    if (xero == null) {
      xeroConnected.value = false;
      return;
    }
    if (!_session.hasPermission(AppPermissions.integrationsXeroManage) &&
        !canManage) {
      xeroConnected.value = false;
      return;
    }
    try {
      final status = await xero.getStatus();
      xeroFeatureEnabled.value = status.featureEnabled;
      xeroConnected.value = status.connected && status.featureEnabled;
      xeroMappingComplete.value = status.mappingComplete == true;
    } on AppFailure catch (e) {
      if (e.code == 'xero_feature_disabled') {
        xeroFeatureEnabled.value = false;
        xeroConnected.value = false;
      } else {
        // Missing permission / not configured → hide Xero UI (unchanged Payments).
        xeroConnected.value = false;
      }
    } catch (_) {
      xeroConnected.value = false;
    }
  }

  Future<void> _loadBatches() async {
    final status = batchStatusFilter.value.trim();
    batches.assignAll(
      await _payroll.listBatches(status: status.isEmpty ? null : status),
    );
  }

  String _ymd(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  String _periodLabelFor(DateTimeRange range) =>
      '${_ymd(range.start)}..${_ymd(range.end)}';

  Future<void> pickPeriod(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: periodRange.value,
    );
    if (picked == null) return;
    periodRange.value = picked;
    periodLabelCtrl.text = _periodLabelFor(picked);
    selectedContractorIds.clear();
    try {
      await _loadUnpaidVisits();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    }
  }

  Future<void> _loadUnpaidVisits() async {
    final range = periodRange.value;
    final from = DateTime.utc(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final to = DateTime.utc(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));
    final list = await _visits.listVisits(
      from: from,
      to: to,
      status: 'completed',
      paymentStatus: 'unpaid',
    );
    unpaidVisits.assignAll(list);
  }

  List<ContractorBatchCandidate> get contractorCandidates {
    final grouped = <String, List<VisitOut>>{};
    for (final visit in unpaidVisits) {
      grouped.putIfAbsent(visit.contractorId, () => <VisitOut>[]).add(visit);
    }

    final result =
        grouped.entries.map((entry) {
            final visits = [...entry.value]
              ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
            final firstVisitAt = visits.first.scheduledStart;
            final lastVisitAt = visits.last.scheduledEnd;
            final totalHours = visits.fold<double>(0, (sum, visit) {
              final hours =
                  visit.scheduledEnd
                      .difference(visit.scheduledStart)
                      .inMinutes /
                  60;
              return sum + hours;
            });

            return ContractorBatchCandidate(
              contractorId: entry.key,
              contractorName:
                  visits.first.contractorName?.trim().isNotEmpty == true
                      ? visits.first.contractorName!.trim()
                      : entry.key,
              visits: visits,
              totalHours: totalHours,
              firstVisitAt: firstVisitAt,
              lastVisitAt: lastVisitAt,
            );
          }).toList()
          ..sort(
            (a, b) => a.contractorName.toLowerCase().compareTo(
              b.contractorName.toLowerCase(),
            ),
          );

    return result;
  }

  List<ContractorBatchCandidate> get filteredContractorCandidates {
    final query = contractorFilter.value.trim().toLowerCase();
    if (query.isEmpty) return contractorCandidates;

    return contractorCandidates
        .where((candidate) {
          return candidate.contractorName.toLowerCase().contains(query) ||
              candidate.contractorId.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  int get selectedVisitCount {
    var count = 0;
    for (final candidate in contractorCandidates) {
      if (selectedContractorIds.contains(candidate.contractorId)) {
        count += candidate.visitCount;
      }
    }
    return count;
  }

  double get selectedTotalHours {
    var total = 0.0;
    for (final candidate in contractorCandidates) {
      if (selectedContractorIds.contains(candidate.contractorId)) {
        total += candidate.totalHours;
      }
    }
    return total;
  }

  Future<void> setBatchStatusFilter(String? status) async {
    batchStatusFilter.value = status ?? '';
    selectedBatch.value = null;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      await _loadBatches();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  void toggleContractor(String contractorId) {
    if (selectedContractorIds.contains(contractorId)) {
      selectedContractorIds.remove(contractorId);
    } else {
      selectedContractorIds.add(contractorId);
    }
  }

  Future<void> createBatch() async {
    if (!canManage) return;
    final visitIds = <String>[];
    for (final candidate in contractorCandidates) {
      if (selectedContractorIds.contains(candidate.contractorId)) {
        visitIds.addAll(candidate.visitIds);
      }
    }

    if (visitIds.isEmpty) {
      errorMessage.value = 'Visit must be completed to add to payment batch.';
      return;
    }
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final key = 'fe-batch-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final created = await _payroll.createBatch(
        PaymentBatchCreateRequest(
          visitIds: visitIds,
          periodLabel: periodLabelCtrl.text.trim(),
        ),
        idempotencyKey: key,
      );
      selectedContractorIds.clear();
      await _loadBatches();
      await _loadUnpaidVisits();
      await _selectAndEnrichBatch(created);
      AppToast.success(
        'Batch created',
        'Draft ${created.id} · ${created.totalAmount} ${created.currencyCode}',
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> postBatch(PaymentBatchOut batch) async {
    if (!canManage) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _payroll.postBatch(batch.id);
      await _selectAndEnrichBatch(updated);
      await _loadBatches();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> voidBatch(PaymentBatchOut batch) async {
    if (!canManage) return;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final updated = await _payroll.voidBatch(batch.id);
      await _selectAndEnrichBatch(updated);
      await _loadBatches();
      await _loadUnpaidVisits();
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> openBatch(PaymentBatchOut batch) async {
    // Refresh Xero mapping status so Send enables after Settings maps are saved.
    await Future.wait([
      _selectAndEnrichBatch(batch),
      _loadXeroConnection(),
    ]);
  }

  Future<void> exportSelectedToXero() async {
    final xero = _xero;
    final batch = selectedBatch.value;
    if (xero == null || batch == null || !canSendSelectedToXero) return;
    if (isExportingXero.value) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Send to Xero?'),
        content: const Text(
          'Hours go as drafts; finish pay in Xero. '
          'Rostiq keeps the record of what was worked. '
          'This does not change Post or Void in Rostiq.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Send to Xero'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    isExportingXero.value = true;
    errorMessage.value = null;
    try {
      final key =
          'fe-xero-${batch.id}-${DateTime.now().toUtc().microsecondsSinceEpoch}';
      final result = await xero.exportPaymentBatch(
        batch.id,
        idempotencyKey: key,
      );
      final updated = batch.copyWith(
        xeroExportStatus: result.xeroExportStatus,
        xeroExportedAt: result.xeroExportedAt,
        xeroExternalIds:
            result.xeroExternalIds
                .map(
                  (e) => <String, dynamic>{
                    'timesheet_id': e.timesheetId,
                    'employee_id': e.employeeId,
                    'contractor_id': e.contractorId,
                    if (e.status != null) 'status': e.status,
                  },
                )
                .toList(growable: false),
        xeroLastError: result.xeroLastError,
        clearXeroLastError: result.xeroLastError == null,
      );
      await _selectAndEnrichBatch(updated);
      await _loadBatches();
      await _loadXeroConnection();
      if (updated.xeroSent) {
        AppToast.success(
          'Sent to Xero',
          'Draft timesheets created. Finish pay in Xero.',
        );
      } else if (updated.xeroFailed) {
        AppToast.error(
          'Xero export failed',
          updated.xeroLastError?.trim().isNotEmpty == true
              ? updated.xeroLastError!
              : 'Export failed. Fix mapping or retry.',
        );
      }
    } on AppFailure catch (e) {
      final msg = _friendlyXeroExportError(e);
      errorMessage.value = msg;
      AppToast.error('Xero export', msg);
      await _loadBatches();
      final refreshed = batches.firstWhereOrNull((b) => b.id == batch.id);
      if (refreshed != null) await _selectAndEnrichBatch(refreshed);
    } catch (_) {
      errorMessage.value = 'Could not send batch to Xero.';
      AppToast.error('Xero export', errorMessage.value!);
    } finally {
      isExportingXero.value = false;
    }
  }

  static String _friendlyXeroExportError(AppFailure e) {
    switch (e.code) {
      case 'idempotency_key_required':
        return 'Export needs an Idempotency-Key. Try again.';
      case 'xero_export_batch_not_posted':
        return 'Only posted batches can be sent to Xero.';
      case 'xero_export_currency_unsupported':
        return 'Only AUD batches can be sent to Xero.';
      case 'xero_export_empty_batch':
        return 'This batch has no lines to export.';
      case 'xero_export_mapping_incomplete':
        return 'Mapping incomplete — map workers and pay items in Settings → Xero.';
      case 'xero_not_connected':
        return 'Connect Xero in Settings before sending.';
      case 'xero_timesheets_failed':
      case 'xero_export_partial':
        final raw = e.message.trim();
        if (raw.contains('JSON') ||
            raw.contains('deserialize') ||
            raw.contains('<Message>')) {
          return 'Xero rejected the timesheet format. Restart the API and retry Send.';
        }
        if (raw.toLowerCase().contains('pay period')) {
          return 'Timesheet dates must match the employee pay calendar in Xero. Retry after API update.';
        }
        return raw.isNotEmpty
            ? raw
            : 'Xero could not create all timesheets. Retry if needed.';
      case 'xero_export_calendar_missing':
        return 'Assign a pay calendar to the Xero employee, then retry.';
      case 'xero_export_calendar_unsupported':
        return e.message.isNotEmpty
            ? e.message
            : 'Use a Weekly or Fortnightly Xero pay calendar for export.';
      case 'xero_rate_limited':
        return 'Xero rate limit — wait a minute, then retry.';
      default:
        return e.message.isNotEmpty ? e.message : humanizeLabel(e.code);
    }
  }

  Future<void> _selectAndEnrichBatch(PaymentBatchOut batch) async {
    selectedBatch.value = batch;
    final enriched = await _enrichBatchLines(batch);
    if (selectedBatch.value?.id != batch.id) return;
    selectedBatch.value = enriched;
  }

  /// Resolve contractor names for batch lines.
  ///
  /// Uses names from the batch payload when present; otherwise loads visit
  /// details so staff are not shown raw visit UUIDs.
  Future<PaymentBatchOut> _enrichBatchLines(PaymentBatchOut batch) async {
    if (batch.lines.isEmpty) return batch;
    if (batch.lines.every(_lineHasContractorName)) return batch;

    final enrichedLines = await Future.wait(
      batch.lines.map((line) async {
        if (_lineHasContractorName(line)) return line;
        try {
          final visit = await _visits.getVisit(line.visitId);
          return line.copyWith(
            contractorName: line.contractorName ?? visit.contractorName,
          );
        } catch (_) {
          return line;
        }
      }),
    );

    return batch.copyWith(lines: enrichedLines);
  }

  bool _lineHasContractorName(PaymentBatchLineOut line) {
    return line.contractorName?.trim().isNotEmpty == true;
  }
}
