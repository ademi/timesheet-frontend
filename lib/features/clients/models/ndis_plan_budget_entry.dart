import 'ndis_budget_types.dart';

/// One NDIS plan budget line (dollar amount + ndis_budget_type).
class NdisPlanBudgetEntry {
  const NdisPlanBudgetEntry({
    required this.type,
    required this.amountDollars,
    this.label,
  });

  final String type;
  final double amountDollars;

  /// Required when [type] is [NdisBudgetType.other].
  final String? label;

  Map<String, dynamic> toJson() => {
        'type': type,
        'amount_dollars': amountDollars,
        if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
      };

  factory NdisPlanBudgetEntry.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    if (!NdisBudgetType.isValid(type)) {
      throw FormatException('Invalid ndis_budget_type: $type');
    }
    final rawAmount = json['amount_dollars'];
    final amount = switch (rawAmount) {
      num n => n.toDouble(),
      String s => double.tryParse(s.trim()),
      _ => null,
    };
    if (amount == null) {
      throw FormatException('Invalid amount_dollars for $type');
    }
    return NdisPlanBudgetEntry(
      type: type,
      amountDollars: amount,
      label: json['label']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NdisPlanBudgetEntry &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          amountDollars == other.amountDollars &&
          label == other.label;

  @override
  int get hashCode => Object.hash(type, amountDollars, label);
}
