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

  /// Pads or truncates [selectedContractorIds] to [requiredSlots] (null = Unfilled).
  void syncAssignSlots(int requiredSlots) {
    final n = requiredSlots;
    if (n < 1) return;
    final current = List<String?>.from(selectedContractorIds);
    if (current.length == n) return;
    if (current.length < n) {
      selectedContractorIds.assignAll([
        ...current,
        ...List<String?>.filled(n - current.length, null),
      ]);
      return;
    }
    selectedContractorIds.assignAll(current.sublist(0, n));
  }

  /// Sets one slot. Rejects the same contractor in two slots (no side effects).
  bool setContractorAt(int index, String? contractorId) {
    if (index < 0 || index >= selectedContractorIds.length) return false;
    final trimmed = contractorId?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (value != null) {
      for (var i = 0; i < selectedContractorIds.length; i++) {
        if (i != index && selectedContractorIds[i] == value) {
          return false;
        }
      }
    }
    final next = List<String?>.from(selectedContractorIds);
    next[index] = value;
    selectedContractorIds.assignAll(next);
    return true;
  }
}
