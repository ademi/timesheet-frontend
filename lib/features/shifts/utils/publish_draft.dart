import '../data/models/shift_models.dart';

/// Local draft for the Publish group shift wizard (Item · People · Stay · Review).
class PublishParticipantOverrideDraft {
  const PublishParticipantOverrideDraft({
    required this.participantId,
    this.supportItemCode,
    this.supportItemName,
    this.baseRate,
    this.saturdayRate,
    this.sundayRate,
    this.eveningRate,
    this.nightRate,
    this.publicHolidayRate,
    this.reason,
  });

  final String participantId;
  final String? supportItemCode;
  final String? supportItemName;
  final double? baseRate;
  final double? saturdayRate;
  final double? sundayRate;
  final double? eveningRate;
  final double? nightRate;
  final double? publicHolidayRate;
  final String? reason;

  bool get hasAnyRate =>
      baseRate != null ||
      saturdayRate != null ||
      sundayRate != null ||
      eveningRate != null ||
      nightRate != null ||
      publicHolidayRate != null;

  bool get isEmpty =>
      (supportItemCode == null || supportItemCode!.trim().isEmpty) &&
      !hasAnyRate &&
      (reason == null || reason!.trim().isEmpty);

  PublishParticipantOverrideDraft copyWith({
    String? participantId,
    String? supportItemCode,
    String? supportItemName,
    double? baseRate,
    double? saturdayRate,
    double? sundayRate,
    double? eveningRate,
    double? nightRate,
    double? publicHolidayRate,
    String? reason,
    bool clearSupportItem = false,
    bool clearBaseRate = false,
    bool clearSaturdayRate = false,
    bool clearSundayRate = false,
    bool clearEveningRate = false,
    bool clearNightRate = false,
    bool clearPublicHolidayRate = false,
    bool clearReason = false,
  }) {
    return PublishParticipantOverrideDraft(
      participantId: participantId ?? this.participantId,
      supportItemCode:
          clearSupportItem ? null : (supportItemCode ?? this.supportItemCode),
      supportItemName:
          clearSupportItem ? null : (supportItemName ?? this.supportItemName),
      baseRate: clearBaseRate ? null : (baseRate ?? this.baseRate),
      saturdayRate:
          clearSaturdayRate ? null : (saturdayRate ?? this.saturdayRate),
      sundayRate: clearSundayRate ? null : (sundayRate ?? this.sundayRate),
      eveningRate: clearEveningRate ? null : (eveningRate ?? this.eveningRate),
      nightRate: clearNightRate ? null : (nightRate ?? this.nightRate),
      publicHolidayRate:
          clearPublicHolidayRate
              ? null
              : (publicHolidayRate ?? this.publicHolidayRate),
      reason: clearReason ? null : (reason ?? this.reason),
    );
  }

  /// Returns an error when this override cannot be published, else `null`.
  String? validate() {
    final code = supportItemCode?.trim() ?? '';
    final hasItem = code.isNotEmpty;
    if (!hasItem && !hasAnyRate) {
      return 'Override needs a support item or rate';
    }
    if (hasAnyRate) {
      final r = reason?.trim() ?? '';
      if (r.isEmpty) {
        return 'Reason is required when a rate is set';
      }
    }
    return null;
  }

  ShiftParticipantPublishOverride toApi() {
    return ShiftParticipantPublishOverride(
      participantId: participantId,
      supportItemCode: supportItemCode?.trim().isEmpty == true
          ? null
          : supportItemCode?.trim(),
      baseRate: baseRate,
      saturdayRate: saturdayRate,
      sundayRate: sundayRate,
      eveningRate: eveningRate,
      nightRate: nightRate,
      publicHolidayRate: publicHolidayRate,
      reason: reason?.trim().isEmpty == true ? null : reason?.trim(),
    );
  }
}

/// Immutable publish wizard draft.
class PublishDraft {
  const PublishDraft({
    this.supportItemCode,
    this.supportItemName,
    this.overrides = const {},
    this.accommodationEnabled = false,
    this.accommodationSupportItemCode,
    this.accommodationSupportItemName,
    this.accommodationQuantity,
  });

  final String? supportItemCode;
  final String? supportItemName;

  /// participantId → override (absent / empty = use default).
  final Map<String, PublishParticipantOverrideDraft> overrides;

  final bool accommodationEnabled;
  final String? accommodationSupportItemCode;
  final String? accommodationSupportItemName;
  final String? accommodationQuantity;

  PublishDraft copyWith({
    String? supportItemCode,
    String? supportItemName,
    Map<String, PublishParticipantOverrideDraft>? overrides,
    bool? accommodationEnabled,
    String? accommodationSupportItemCode,
    String? accommodationSupportItemName,
    String? accommodationQuantity,
    bool clearSupportItem = false,
    bool clearAccommodationItem = false,
    bool clearAccommodationQuantity = false,
  }) {
    return PublishDraft(
      supportItemCode:
          clearSupportItem ? null : (supportItemCode ?? this.supportItemCode),
      supportItemName:
          clearSupportItem ? null : (supportItemName ?? this.supportItemName),
      overrides: overrides ?? this.overrides,
      accommodationEnabled: accommodationEnabled ?? this.accommodationEnabled,
      accommodationSupportItemCode:
          clearAccommodationItem
              ? null
              : (accommodationSupportItemCode ??
                  this.accommodationSupportItemCode),
      accommodationSupportItemName:
          clearAccommodationItem
              ? null
              : (accommodationSupportItemName ??
                  this.accommodationSupportItemName),
      accommodationQuantity:
          clearAccommodationQuantity
              ? null
              : (accommodationQuantity ?? this.accommodationQuantity),
    );
  }

  PublishParticipantOverrideDraft? overrideFor(String participantId) {
    final o = overrides[participantId];
    if (o == null || o.isEmpty) return null;
    return o;
  }

  bool hasCustom(String participantId) => overrideFor(participantId) != null;

  /// Step 1 Next — default support item required (D5).
  String? validateDefaultItem() {
    final code = supportItemCode?.trim() ?? '';
    if (code.isEmpty) return 'Choose a default support item';
    return null;
  }

  /// Step 2 — all custom overrides valid; no duplicate ids (map-enforced).
  String? validateOverrides() {
    for (final entry in overrides.entries) {
      final o = entry.value;
      if (o.isEmpty) continue;
      final err = o.validate();
      if (err != null) return err;
    }
    return null;
  }

  /// Step 3 — when Stay on, code ↔ qty both required.
  String? validateAccommodation() {
    if (!accommodationEnabled) return null;
    final code = accommodationSupportItemCode?.trim() ?? '';
    final qty = accommodationQuantity?.trim() ?? '';
    if (code.isEmpty && qty.isEmpty) {
      return 'Choose an accommodation item and quantity';
    }
    if (code.isEmpty) return 'Choose an accommodation support item';
    if (qty.isEmpty) return 'Enter accommodation quantity';
    final parsed = double.tryParse(qty);
    if (parsed == null || parsed <= 0) {
      return 'Accommodation quantity must be greater than 0';
    }
    return null;
  }

  /// Full draft before Publish.
  String? validateAll() {
    return validateDefaultItem() ??
        validateOverrides() ??
        validateAccommodation();
  }

  ShiftPublishRequest toRequest() {
    final overrideList = <ShiftParticipantPublishOverride>[
      for (final o in overrides.values)
        if (!o.isEmpty) o.toApi(),
    ];
    final stayOn = accommodationEnabled;
    return ShiftPublishRequest(
      supportItemCode: supportItemCode?.trim(),
      participantOverrides: overrideList.isEmpty ? null : overrideList,
      accommodationSupportItemCode:
          stayOn ? accommodationSupportItemCode?.trim() : null,
      accommodationQuantity: stayOn ? accommodationQuantity?.trim() : null,
    );
  }
}
