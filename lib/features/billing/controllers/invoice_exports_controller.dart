import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../clients/data/models/client_models.dart';
import '../../clients/data/repositories/clients_repository.dart';
import '../../jobs/data/models/job_models.dart';
import '../../jobs/data/repositories/jobs_repository.dart';
import '../../visits/data/models/visit_models.dart';
import '../../visits/data/repositories/visits_repository.dart';
import '../data/exported_visit_ids_store.dart';
import '../data/models/billing_models.dart';
import '../data/repositories/billing_repository.dart';
import '../utils/invoice_export_errors.dart';
import '../utils/visit_export_preflight.dart';

String invoiceExportStatusLabel(String status) {
  switch (status) {
    case 'finalized':
      return 'Finalized';
    case 'void':
      return 'Void';
    default:
      return status;
  }
}

class InvoiceExportsController extends GetxController {
  InvoiceExportsController({
    required BillingRepository repository,
    required VisitsRepository visitsRepository,
    required SessionService session,
    required ExportedVisitIdsStore exportedVisitIds,
    ClientsRepository? clientsRepository,
    JobsRepository? jobsRepository,
  }) : _repository = repository,
       _visitsRepository = visitsRepository,
       _session = session,
       _exportedVisitIds = exportedVisitIds,
       _clientsRepository = clientsRepository,
       _jobsRepository = jobsRepository;

  final BillingRepository _repository;
  final VisitsRepository _visitsRepository;
  final SessionService _session;
  final ExportedVisitIdsStore _exportedVisitIds;
  final ClientsRepository? _clientsRepository;
  final JobsRepository? _jobsRepository;

  final tabIndex = 0.obs;
  final exports = <InvoiceExportOut>[].obs;
  final exportableVisits = <VisitOut>[].obs;
  final unclaimedAgeing = <UnclaimedAgeingVisitOut>[].obs;
  final ageingApproaching90Only = false.obs;
  final burnAlerts = <BurnEnvelopeAlertOut>[].obs;
  final paymentEnquiries = <PaymentEnquiryOut>[].obs;
  final arAgeing = <ArAgeingExportOut>[].obs;
  final arManagementTypeFilter = ''.obs;
  final selectedVisitIds = <String>{}.obs;
  final lastVisitErrors = <InvoiceExportVisitError>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final clients = <ClientOut>[].obs;
  final jobs = <JobOut>[].obs;
  final clientIdFilter = ''.obs;
  final participantIdFilter = ''.obs;
  final jobIdFilter = ''.obs;

  /// In-flight count for [isLoading] so concurrent loads (exports + ageing + …)
  /// do not clear the spinner when the first request finishes (C5).
  int _loadingCount = 0;

  late final Rx<DateTimeRange> periodRange;


  bool get canView => _session.canViewBilling;
  bool get canManage => _session.canManageBilling;

  /// True when any unclaimed visit is ≥60 days (watch / high / critical).
  bool get hasAgeingRiskBadge =>
      unclaimedAgeing.any((v) => v.isWatchOrWorse);

  int get ageingRiskCount =>
      unclaimedAgeing.where((v) => v.isWatchOrWorse).length;

  bool get hasBurnAlertBadge => burnAlerts.isNotEmpty;

  int get burnAlertCount => burnAlerts.length;

  bool get hasArRiskBadge => arAgeing.any((e) => e.isWatchOrWorse);

  int get arRiskCount => arAgeing.where((e) => e.isWatchOrWorse).length;

  /// Test/read access to the shared export exclusion set.
  ExportedVisitIdsStore get exportedVisitIds => _exportedVisitIds;

  /// Active clients for the Create-tab filter dropdown.
  List<({String id, String name})> get clientFilterOptions {
    final list =
        clients
            .where((c) => c.status != 'inactive')
            .map((c) => (id: c.id, name: c.fullName.trim()))
            .where((c) => c.name.isNotEmpty)
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return list;
  }

  /// Participant filter reuses the client directory (participants are clients).
  List<({String id, String name})> get participantFilterOptions =>
      clientFilterOptions;

  /// Job/support filter options for Create-tab.
  List<({String id, String name})> get jobFilterOptions {
    final list =
        jobs
            .map(
              (j) => (
                id: j.id,
                name: (j.title.trim().isEmpty ? j.id : j.title.trim()),
              ),
            )
            .toList(growable: false)
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return list;
  }

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    periodRange =
        DateTimeRange(
          start: today.subtract(const Duration(days: 13)),
          end: today,
        ).obs;
    loadExports();
    loadUnclaimedAgeing();
    loadBurnAlerts();
    loadPaymentEnquiries();
    loadArAgeing();
    if (canManage) {
      loadClients();
      loadJobs();
    }
    _applyInitialTabFromArgs();
  }

  void _applyInitialTabFromArgs() {
    final raw = Get.arguments;
    String? tab;
    if (raw is Map) {
      tab = raw['tab']?.toString();
    } else if (raw is String) {
      tab = raw;
    }
    switch (tab) {
      case 'create':
        if (canManage) switchToCreateTab();
      case 'ageing' || '90d':
        switchToAgeingTab();
      case 'burn':
        switchToBurnTab();
      case 'pe':
        switchToPeTab();
      case 'ar':
        switchToArTab();
      default:
        break;
    }
  }

  void _beginLoading() {
    _loadingCount++;
    isLoading.value = true;
  }

  void _endLoading() {
    if (_loadingCount > 0) {
      _loadingCount--;
    }
    if (_loadingCount == 0) {
      isLoading.value = false;
    }
  }

  Future<void> loadBurnAlerts() async {
    if (!canView) return;
    try {
      burnAlerts.assignAll(await _repository.listBudgetAlerts());
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      // Non-blocking for other tabs.
    }
  }

  Future<void> loadPaymentEnquiries() async {
    if (!canView) return;
    try {
      paymentEnquiries.assignAll(await _repository.listPaymentEnquiries());
    } on AppFailure catch (_) {
      // Optional tower tab.
    }
  }

  Future<void> loadArAgeing() async {
    if (!canView) return;
    try {
      final mt = arManagementTypeFilter.value.trim();
      arAgeing.assignAll(
        await _repository.listArAgeing(
          managementType: mt.isEmpty ? null : mt,
        ),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      // Optional tower tab.
    }
  }

  Future<void> setArManagementTypeFilter(String? value) async {
    arManagementTypeFilter.value = value?.trim() ?? '';
    await loadArAgeing();
  }

  Future<void> setArDelayReason(ArAgeingExportOut row, String reason) async {
    if (!canManage) return;
    try {
      final updated = await _repository.patchArExport(
        row.exportId,
        delayReason: reason,
      );
      final idx = arAgeing.indexWhere((e) => e.exportId == row.exportId);
      if (idx >= 0) arAgeing[idx] = updated;
      AppToast.success('Saved', 'Delay reason saved');
    } on AppFailure catch (e) {
      AppToast.error('AR update failed', e.message);
    }
  }

  Future<void> markArPaid(ArAgeingExportOut row) async {
    if (!canManage) return;
    try {
      await _repository.patchArExport(
        row.exportId,
        arPaymentStatus: 'paid',
        clearDelayReason: true,
      );
      arAgeing.removeWhere((e) => e.exportId == row.exportId);
      AppToast.success('Paid', 'Marked paid');
    } on AppFailure catch (e) {
      AppToast.error('AR update failed', e.message);
    }
  }

  Future<void> loadUnclaimedAgeing() async {
    if (!canView) return;
    _beginLoading();
    errorMessage.value = null;
    try {
      final clientId = clientIdFilter.value.trim();
      final list = await _repository.listUnclaimedAgeing(
        clientId: clientId.isEmpty ? null : clientId,
        approaching90: ageingApproaching90Only.value,
      );
      // Oldest first from API; keep that order for claim urgency.
      unclaimedAgeing.assignAll(list);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      _endLoading();
    }
  }

  Future<void> setAgeingApproaching90Only(bool value) async {
    if (ageingApproaching90Only.value == value) return;
    ageingApproaching90Only.value = value;
    await loadUnclaimedAgeing();
  }

  Future<void> openUnclaimedVisitForFix(UnclaimedAgeingVisitOut row) async {
    isSaving.value = true;
    errorMessage.value = null;
    try {
      final visit = await _visitsRepository.getVisit(row.visitId);
      await openVisitForFix(visit);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      if (!Get.testMode) {
        AppToast.error('Could not open visit', e.message);
      }
    } finally {
      isSaving.value = false;
    }
  }

  /// Jump to Create tab and select this visit for export when present.
  Future<void> openUnclaimedForExport(UnclaimedAgeingVisitOut row) async {
    switchToCreateTab();
    selectedVisitIds.add(row.visitId);
    if (!exportableVisits.any((v) => v.id == row.visitId)) {
      // Outside current period — still open Fix so staff can correct codes.
      await openUnclaimedVisitForFix(row);
    }
  }

  void switchToAgeingTab() {
    tabIndex.value = 2;
    loadUnclaimedAgeing();
  }

  void switchToBurnTab() {
    tabIndex.value = 3;
    loadBurnAlerts();
  }

  void switchToPeTab() {
    tabIndex.value = 4;
    loadPaymentEnquiries();
  }

  void switchToArTab() {
    tabIndex.value = 5;
    loadArAgeing();
  }

  Future<void> loadClients() async {
    final repo = _clientsRepository;
    if (repo == null || !canManage) return;
    try {
      clients.assignAll(await repo.listClients());
      final selected = clientIdFilter.value;
      if (selected.isNotEmpty && !clients.any((c) => c.id == selected)) {
        clientIdFilter.value = '';
      }
      final participant = participantIdFilter.value;
      if (participant.isNotEmpty && !clients.any((c) => c.id == participant)) {
        participantIdFilter.value = '';
      }
    } catch (_) {
      // Client filter is optional; Create still works with "All clients".
    }
  }

  Future<void> loadJobs() async {
    final repo = _jobsRepository;
    if (repo == null || !canManage) return;
    try {
      jobs.assignAll(await repo.listJobs());
      final selected = jobIdFilter.value;
      if (selected.isNotEmpty && !jobs.any((j) => j.id == selected)) {
        jobIdFilter.value = '';
      }
    } catch (_) {
      // Job filter is optional.
    }
  }

  Future<void> loadExports() async {
    if (!canView) {
      errorMessage.value = 'Missing billing.view permission.';
      return;
    }
    _beginLoading();
    errorMessage.value = null;
    try {
      exports.assignAll(await _repository.listInvoiceExports());
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      _endLoading();
    }
  }

  Future<void> loadExportableVisits() async {
    if (!canManage) return;
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
    _beginLoading();
    errorMessage.value = null;
    try {
      final clientId = clientIdFilter.value.trim();
      final participantId = participantIdFilter.value.trim();
      final jobId = jobIdFilter.value.trim();
      final list = await _visitsRepository.listVisits(
        from: from,
        to: to,
        clientId: clientId.isEmpty ? null : clientId,
        participantId: participantId.isEmpty ? null : participantId,
        jobId: jobId.isEmpty ? null : jobId,
        status: 'completed',
        limit: 200,
      );
      exportableVisits.assignAll(
        list.where((v) => !_exportedVisitIds.contains(v.id)).toList(),
      );
      selectedVisitIds.removeWhere(
        (id) => !exportableVisits.any((v) => v.id == id),
      );
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      _endLoading();
    }
  }

  Future<void> loadAll() async {
    await loadExports();
    await loadUnclaimedAgeing();
    await loadBurnAlerts();
    await loadPaymentEnquiries();
    if (canManage) {
      await loadExportableVisits();
    }
  }

  Future<void> pickPeriod(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: periodRange.value,
    );
    if (picked == null) return;
    periodRange.value = picked;
    selectedVisitIds.clear();
    lastVisitErrors.clear();
    await loadExportableVisits();
  }

  Future<void> setClientFilter(String? clientId) async {
    final next = clientId?.trim() ?? '';
    if (clientIdFilter.value == next) return;
    clientIdFilter.value = next;
    selectedVisitIds.clear();
    lastVisitErrors.clear();
    await loadUnclaimedAgeing();
    if (tabIndex.value == 1 && canManage) {
      await loadExportableVisits();
    }
  }

  Future<void> setParticipantFilter(String? participantId) async {
    final next = participantId?.trim() ?? '';
    if (participantIdFilter.value == next) return;
    participantIdFilter.value = next;
    selectedVisitIds.clear();
    lastVisitErrors.clear();
    if (tabIndex.value == 1 && canManage) {
      await loadExportableVisits();
    }
  }

  Future<void> setJobFilter(String? jobId) async {
    final next = jobId?.trim() ?? '';
    if (jobIdFilter.value == next) return;
    jobIdFilter.value = next;
    selectedVisitIds.clear();
    lastVisitErrors.clear();
    if (tabIndex.value == 1 && canManage) {
      await loadExportableVisits();
    }
  }

  VisitExportPreflight preflightFor(VisitOut visit) =>
      buildVisitExportPreflight(visit);

  InvoiceExportVisitError? visitErrorFor(String visitId) {
    for (final err in lastVisitErrors) {
      if (err.visitId == visitId) return err;
    }
    return null;
  }

  /// Human label for export error rows (prefer visit title over UUID).
  String visitLabelForError(InvoiceExportVisitError err) {
    for (final visit in exportableVisits) {
      if (visit.id == err.visitId) {
        final title = visit.jobTitle?.trim();
        if (title != null && title.isNotEmpty) return title;
        break;
      }
    }
    final short =
        err.visitId.length <= 8 ? err.visitId : err.visitId.substring(0, 8);
    return 'Visit $short';
  }

  String? get createExportHint {
    if (!canManage) return null;
    if (selectedVisitIds.isEmpty) {
      return 'Select ready visits to create an export.';
    }
    if (!selectedVisitsReady) {
      return 'Fix blocked visits before creating an export.';
    }
    return null;
  }

  void switchToCreateTab() {
    tabIndex.value = 1;
    loadExportableVisits();
  }

  bool get selectedVisitsReady {
    final selected = exportableVisits
        .where((v) => selectedVisitIds.contains(v.id))
        .toList(growable: false);
    if (selected.isEmpty) return false;
    return selectedVisitsExportReady(selected, _exportedVisitIds.ids);
  }

  void toggleVisit(String visitId) {
    if (selectedVisitIds.contains(visitId)) {
      selectedVisitIds.remove(visitId);
    } else {
      selectedVisitIds.add(visitId);
    }
  }

  void _dropExportedFromList(Iterable<String> visitIds) {
    _exportedVisitIds.mark(visitIds);
    selectedVisitIds.removeWhere(_exportedVisitIds.contains);
    exportableVisits.removeWhere((v) => _exportedVisitIds.contains(v.id));
  }

  Future<void> createExport() async {
    if (!canManage) return;
    final visitIds = selectedVisitIds.toList(growable: false);
    if (visitIds.isEmpty) {
      errorMessage.value = 'Select at least one completed visit.';
      return;
    }
    final selected = exportableVisits
        .where((v) => visitIds.contains(v.id))
        .toList(growable: false);
    if (!selectedVisitsExportReady(selected, _exportedVisitIds.ids)) {
      errorMessage.value =
          'Fix blocked pre-flight items before creating an export.';
      return;
    }

    isSaving.value = true;
    errorMessage.value = null;
    lastVisitErrors.clear();
    try {
      final created = await _repository.createInvoiceExport(
        InvoiceExportCreateRequest(visitIds: visitIds),
      );
      _dropExportedFromList(visitIds);
      selectedVisitIds.clear();
      await loadAll();
      tabIndex.value = 0;
      if (!Get.testMode) {
        AppToast.success(
          'Export created',
          '${created.lineCount} line${created.lineCount == 1 ? '' : 's'} · '
              '${created.currencyCode} ${created.totalAmount.toStringAsFixed(2)}',
        );
      }
      openDetail(created);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      lastVisitErrors.assignAll(_mapVisitErrors(e));
      _applyExcludedFromVisitErrors(lastVisitErrors);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isSaving.value = false;
    }
  }

  List<InvoiceExportVisitError> _mapVisitErrors(AppFailure failure) {
    if (failure.visitErrors.isNotEmpty) {
      return failure.visitErrors
          .map(
            (row) => InvoiceExportVisitError(
              visitId: row['visit_id'] ?? '',
              code: row['code'] ?? 'unknown',
              message:
                  row['message'] ??
                  invoiceExportErrorMessage(row['code'] ?? 'unknown'),
            ),
          )
          .where((e) => e.visitId.isNotEmpty)
          .toList(growable: false);
    }
    if (failure.code == 'visit_already_exported') {
      return selectedVisitIds
          .map(
            (id) => InvoiceExportVisitError(
              visitId: id,
              code: failure.code,
              message: failure.message,
            ),
          )
          .toList(growable: false);
    }
    return const [];
  }

  void _applyExcludedFromVisitErrors(List<InvoiceExportVisitError> errors) {
    _dropExportedFromList([
      for (final err in errors)
        if (err.code == 'visit_already_exported') err.visitId,
    ]);
  }

  /// Opens visit detail for Fix-on-visit; reloads Create list when staff returns.
  Future<void> openVisitForFix(VisitOut visit) async {
    if (!Get.testMode) {
      await Get.toNamed(AppRoutes.staffVisitDetail, arguments: visit);
    }
    lastVisitErrors.clear();
    await loadExportableVisits();
  }

  void openDetail(InvoiceExportOut export) {
    Get.toNamed(
      AppRoutes.staffBillingExportDetail,
      parameters: {'id': export.id},
      arguments: export,
    );
  }
}
