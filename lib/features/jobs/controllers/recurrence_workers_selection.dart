import 'package:get/get.dart';

/// Workers pre-filled on a recurrence pattern (D2: at most one id per slot).
///
/// Null entries are Unfilled holes. Submit paths send [filledContractorIds]
/// (nulls dropped) so length can be less than `required_slots`.
mixin RecurrenceWorkersSelection {
  final selectedContractorIds = <String?>[].obs;

  List<String> get filledContractorIds => [
        for (final id in selectedContractorIds)
          if (id != null && id.isNotEmpty) id,
      ];

  String? get soleContractorId {
    for (final id in selectedContractorIds) {
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  void selectSoleContractor(String? contractorId) {
    final id = contractorId?.trim();
    selectedContractorIds.assignAll(
      id == null || id.isEmpty ? const <String?>[] : <String?>[id],
    );
  }

  void clearSelectedContractors() => selectedContractorIds.clear();
}
