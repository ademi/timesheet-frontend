import 'package:get/get.dart';

/// Workers pre-filled on a recurrence pattern (D2: at most one id per slot).
///
/// The composer still offers a single-worker dropdown; the assign step layers
/// multi-select on top of the same list.
mixin RecurrenceWorkersSelection {
  final selectedContractorIds = <String>[].obs;

  String? get soleContractorId =>
      selectedContractorIds.isEmpty ? null : selectedContractorIds.first;

  void selectSoleContractor(String? contractorId) {
    selectedContractorIds.assignAll(
      contractorId == null ? const <String>[] : <String>[contractorId],
    );
  }

  void clearSelectedContractors() => selectedContractorIds.clear();
}
