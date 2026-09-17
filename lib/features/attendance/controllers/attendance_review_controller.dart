import 'package:get/get.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/attendance_review_models.dart';
import '../data/repositories/attendance_repository.dart';

/// Staff inbox: merge GPS exceptions + sync conflicts (D6→A).
class AttendanceReviewController extends GetxController {
  AttendanceReviewController({
    required AttendanceRepository repository,
    this.visitIdFilter,
    void Function(String title, String message)? showSnack,
  }) : _repository = repository,
       _showSnack = showSnack ?? AppToast.error;

  static const forceAcceptNoteMinLength = 8;

  final AttendanceRepository _repository;
  final String? visitIdFilter;
  final void Function(String title, String message) _showSnack;

  final isLoading = false.obs;
  final isActing = false.obs;
  final errorMessage = RxnString();
  final actionError = RxnString();
  final filter = AttendanceReviewFilter.all.obs;
  final items = <AttendanceReviewItem>[].obs;

  List<AttendanceReviewItem> get visibleItems {
    final visitFilter = visitIdFilter?.trim();
    Iterable<AttendanceReviewItem> list = items;
    if (visitFilter != null && visitFilter.isNotEmpty) {
      list = list.where((i) => i.visitId == visitFilter);
    }
    switch (filter.value) {
      case AttendanceReviewFilter.all:
        return list.toList(growable: false);
      case AttendanceReviewFilter.gps:
        return list
            .where((i) => i.kind == AttendanceReviewKind.exception)
            .toList(growable: false);
      case AttendanceReviewFilter.sync:
        return list
            .where((i) => i.kind == AttendanceReviewKind.syncConflict)
            .toList(growable: false);
    }
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void setFilter(AttendanceReviewFilter value) {
    filter.value = value;
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final results = await Future.wait([
        _repository.listExceptions(status: 'pending_ack'),
        _repository.listSyncConflicts(status: 'open'),
      ]);
      final exceptions = results[0] as List<AttendanceExceptionOut>;
      final conflicts = results[1] as List<AttendanceSyncConflictOut>;
      final merged = <AttendanceReviewItem>[
        for (final e in exceptions) AttendanceReviewItem.fromException(e),
        for (final c in conflicts) AttendanceReviewItem.fromSyncConflict(c),
      ]..sort((a, b) => b.sortAt.compareTo(a.sortAt));
      items.assignAll(merged);
    } on AppFailure catch (e) {
      errorMessage.value = e.message;
      _showSnack('Attendance review', e.message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> approveException(
    AttendanceReviewItem item, {
    String? note,
  }) => _ackException(item, decision: 'approved', note: note);

  Future<bool> rejectException(
    AttendanceReviewItem item, {
    String? note,
  }) => _ackException(item, decision: 'rejected', note: note);

  Future<bool> _ackException(
    AttendanceReviewItem item, {
    required String decision,
    String? note,
  }) async {
    if (item.kind != AttendanceReviewKind.exception) return false;
    isActing.value = true;
    actionError.value = null;
    try {
      await _repository.ackException(
        item.id,
        decision: decision,
        note: note,
      );
      await load();
      return true;
    } on AppFailure catch (e) {
      actionError.value = e.message;
      _showSnack('Attendance review', e.message);
      return false;
    } finally {
      isActing.value = false;
    }
  }

  Future<bool> forceAcceptConflict(
    AttendanceReviewItem item, {
    required String note,
  }) async {
    if (item.kind != AttendanceReviewKind.syncConflict) return false;
    final cleaned = note.trim();
    if (cleaned.length < forceAcceptNoteMinLength) {
      actionError.value =
          'Note must be at least $forceAcceptNoteMinLength characters.';
      return false;
    }
    isActing.value = true;
    actionError.value = null;
    try {
      await _repository.forceAcceptSyncConflict(item.id, note: cleaned);
      await load();
      return true;
    } on AppFailure catch (e) {
      actionError.value = e.message;
      _showSnack('Attendance review', e.message);
      return false;
    } finally {
      isActing.value = false;
    }
  }

  Future<bool> discardConflict(
    AttendanceReviewItem item, {
    required String note,
  }) async {
    if (item.kind != AttendanceReviewKind.syncConflict) return false;
    final cleaned = note.trim();
    if (cleaned.isEmpty) {
      actionError.value = 'Note is required to discard.';
      return false;
    }
    isActing.value = true;
    actionError.value = null;
    try {
      await _repository.discardSyncConflict(item.id, note: cleaned);
      await load();
      return true;
    } on AppFailure catch (e) {
      actionError.value = e.message;
      _showSnack('Attendance review', e.message);
      return false;
    } finally {
      isActing.value = false;
    }
  }
}
