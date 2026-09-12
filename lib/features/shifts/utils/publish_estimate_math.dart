import 'dart:math' as math;

import '../data/models/shift_models.dart';
import 'publish_draft.dart';

/// Mirrors backend `group_pricing.PricingMode`.
enum PublishPricingMode { ndisGroup, allocatedShare }

/// One allocation row for mode detection / minute split.
class PublishAllocationRow {
  const PublishAllocationRow({
    required this.participantId,
    required this.strategy,
    required this.value,
  });

  final String participantId;

  /// `percentage` or `time_based`.
  final String strategy;
  final double value;
}

/// Line price for one participant (mirrors `ParticipantLinePrice`).
class ParticipantLinePrice {
  const ParticipantLinePrice({
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.pricingMode,
  });

  final double quantity;
  final double unitPrice;
  final double amount;
  final PublishPricingMode pricingMode;
}

/// Per-participant claim estimate for Review (D7/D8).
class ParticipantPublishEstimate {
  const ParticipantPublishEstimate({
    required this.participantId,
    required this.supportAmount,
    required this.accommodationAmount,
    required this.pricingMode,
    required this.unitPrice,
    required this.quantity,
  });

  final String participantId;
  final double supportAmount;
  final double accommodationAmount;
  final PublishPricingMode pricingMode;
  final double unitPrice;
  final double quantity;

  double get total =>
      _roundMoney(supportAmount + accommodationAmount);
}

const _equalTolerance = 0.01;

/// True when every allocation is percentage, values equal within 0.01,
/// and percentages sum to ~100 (mirrors BE `is_equal_percentage_share`).
bool isEqualPercentageShare(List<PublishAllocationRow> allocations) {
  if (allocations.isEmpty) return false;
  if (allocations.any((r) => r.strategy != 'percentage')) return false;
  final values = [for (final r in allocations) r.value];
  if (values.any((v) => v <= 0)) return false;
  final total = values.fold<double>(0, (a, b) => a + b);
  if ((total - 100).abs() > 0.02) return false;
  final target = values.first;
  // Extra 1e-9 absorbs binary float noise (e.g. 33.34 vs 33.33).
  return values.every((v) => (v - target).abs() <= _equalTolerance + 1e-9);
}

/// Equal % → ndis_group; unequal or time_based → allocated_share.
PublishPricingMode detectPricingMode(List<PublishAllocationRow> allocations) {
  if (isEqualPercentageShare(allocations)) {
    return PublishPricingMode.ndisGroup;
  }
  return PublishPricingMode.allocatedShare;
}

/// ROUND_HALF_UP to [places] (positive amounts; mirrors Decimal quantize).
double roundHalfUp(double value, int places) {
  final factor = math.pow(10, places).toDouble();
  return (value * factor).round() / factor;
}

double _roundQty(double v) => roundHalfUp(v, 4);
double _roundMoney(double v) => roundHalfUp(v, 2);

/// Mirrors BE `price_participant_line`.
ParticipantLinePrice priceParticipantLine({
  required PublishPricingMode mode,
  required double tierUnitPrice,
  required int groupSize,
  required int visitMinutes,
  required num allocatedMinutes,
}) {
  if (groupSize < 1) {
    throw ArgumentError.value(groupSize, 'groupSize', 'must be >= 1');
  }
  if (visitMinutes < 0) {
    throw ArgumentError.value(visitMinutes, 'visitMinutes', 'must be >= 0');
  }

  late final double quantity;
  late final double unitPrice;

  if (mode == PublishPricingMode.ndisGroup) {
    quantity = _roundQty(visitMinutes / 60.0);
    unitPrice = _roundMoney(tierUnitPrice / groupSize);
  } else {
    final allocated = allocatedMinutes.toDouble();
    if (allocated < 0) {
      throw ArgumentError.value(
        allocatedMinutes,
        'allocatedMinutes',
        'must be >= 0',
      );
    }
    quantity = _roundQty(allocated / 60.0);
    unitPrice = _roundMoney(tierUnitPrice);
  }

  final amount = _roundMoney(quantity * unitPrice);
  return ParticipantLinePrice(
    quantity: quantity,
    unitPrice: unitPrice,
    amount: amount,
    pricingMode: mode,
  );
}

/// Largest-remainder floor split of [shiftMinutes] by percentage values
/// (mirrors BE `calculate_allocated_minutes` for percentage strategy).
Map<String, int> allocatePercentageMinutes({
  required List<PublishAllocationRow> allocations,
  required int shiftMinutes,
}) {
  final percentage = [
    for (final r in allocations)
      if (r.strategy == 'percentage') r,
  ];
  if (percentage.isEmpty) return {};

  final exact = [
    for (final r in percentage)
      shiftMinutes * r.value / 100.0,
  ];
  final allocated = [for (final m in exact) m.floor()];
  var residual = shiftMinutes - allocated.fold<int>(0, (a, b) => a + b);

  final remainders = <({int index, double frac})>[
    for (var i = 0; i < exact.length; i++)
      (index: i, frac: exact[i] - allocated[i]),
  ]..sort((a, b) {
    final cmp = b.frac.compareTo(a.frac);
    if (cmp != 0) return cmp;
    return a.index.compareTo(b.index);
  });

  for (final row in remainders) {
    if (residual <= 0) break;
    allocated[row.index] += 1;
    residual -= 1;
  }

  return {
    for (var i = 0; i < percentage.length; i++)
      percentage[i].participantId: allocated[i],
  };
}

/// Window minutes for a participant (sum of window durations).
int windowMinutesFor(ShiftParticipantOut participant) {
  final windows = participant.timeWindows;
  if (windows == null || windows.isEmpty) return 0;
  var total = 0;
  for (final w in windows) {
    final mins =
        w.participantEndTime.difference(w.participantStartTime).inMinutes;
    if (mins > 0) total += mins;
  }
  return total;
}

/// Time-based: share of visit minutes by window totals (export-aligned).
Map<String, double> allocateTimeBasedMinutes({
  required List<ShiftParticipantOut> participants,
  required int shiftMinutes,
}) {
  final windowTotals = <String, int>{
    for (final p in participants) p.participantId: windowMinutesFor(p),
  };
  final totalWindows = windowTotals.values.fold<int>(0, (a, b) => a + b);
  if (totalWindows <= 0) {
    return {for (final p in participants) p.participantId: 0.0};
  }
  return {
    for (final e in windowTotals.entries)
      e.key: shiftMinutes * e.value / totalWindows,
  };
}

/// Resolve catalogue P for a participant from draft + national limits.
double? resolveParticipantPrice({
  required String participantId,
  required PublishDraft draft,
  required Map<String, double> catalogueNationalByCode,
}) {
  final override = draft.overrideFor(participantId);
  if (override?.baseRate != null) return override!.baseRate;
  final code =
      (override?.supportItemCode?.trim().isNotEmpty == true
          ? override!.supportItemCode!.trim()
          : draft.supportItemCode?.trim()) ??
      '';
  if (code.isEmpty) return null;
  return catalogueNationalByCode[code];
}

/// Build Review estimates from cached catalogue prices + local hybrid math.
List<ParticipantPublishEstimate> estimatePublishClaims({
  required List<ShiftParticipantOut> activeParticipants,
  required DateTime scheduledStart,
  required DateTime scheduledEnd,
  required PublishDraft draft,
  required Map<String, double> catalogueNationalByCode,
}) {
  final n = activeParticipants.length;
  if (n == 0) return const [];

  final visitMinutes =
      scheduledEnd.difference(scheduledStart).inMinutes.clamp(0, 24 * 60 * 7);
  final rows = <PublishAllocationRow>[
    for (final p in activeParticipants)
      PublishAllocationRow(
        participantId: p.participantId,
        strategy: p.allocationStrategy ?? 'percentage',
        value: p.allocationValue ?? 0,
      ),
  ];
  final mode = detectPricingMode(rows);

  final pctMinutes = allocatePercentageMinutes(
    allocations: rows,
    shiftMinutes: visitMinutes,
  );
  final timeMinutes = mode == PublishPricingMode.allocatedShare
      ? allocateTimeBasedMinutes(
        participants: activeParticipants,
        shiftMinutes: visitMinutes,
      )
      : const <String, double>{};

  double stayUnit = 0;
  double stayQty = 0;
  if (draft.accommodationEnabled) {
    final stayCode = draft.accommodationSupportItemCode?.trim() ?? '';
    stayUnit = catalogueNationalByCode[stayCode] ?? 0;
    stayQty = double.tryParse(draft.accommodationQuantity?.trim() ?? '') ?? 0;
  }
  final stayLine =
      (stayUnit > 0 && stayQty > 0) ? _roundMoney(stayQty * stayUnit) : 0.0;

  return [
    for (final p in activeParticipants)
      () {
        final price = resolveParticipantPrice(
          participantId: p.participantId,
          draft: draft,
          catalogueNationalByCode: catalogueNationalByCode,
        );
        if (price == null) {
          return ParticipantPublishEstimate(
            participantId: p.participantId,
            supportAmount: 0,
            accommodationAmount: stayLine,
            pricingMode: mode,
            unitPrice: 0,
            quantity: 0,
          );
        }

        num allocated;
        if (mode == PublishPricingMode.ndisGroup) {
          allocated = visitMinutes;
        } else if ((p.allocationStrategy ?? 'percentage') == 'time_based') {
          allocated = timeMinutes[p.participantId] ?? 0;
        } else {
          allocated = pctMinutes[p.participantId] ?? 0;
        }

        final line = priceParticipantLine(
          mode: mode,
          tierUnitPrice: price,
          groupSize: n,
          visitMinutes: visitMinutes,
          allocatedMinutes: allocated,
        );

        return ParticipantPublishEstimate(
          participantId: p.participantId,
          supportAmount: line.amount,
          accommodationAmount: stayLine,
          pricingMode: line.pricingMode,
          unitPrice: line.unitPrice,
          quantity: line.quantity,
        );
      }(),
  ];
}

/// Format muted estimate caption (e.g. `est. $62.50`).
String formatEstimateMoney(double amount) {
  return 'est. \$${amount.toStringAsFixed(2)}';
}
