const budgetEnvelopeKeys = <String>[
  'core',
  'capacity_building',
  'capital',
  'other',
];

class BudgetEnvelopeOut {
  const BudgetEnvelopeOut({
    required this.key,
    this.declared,
    required this.spent,
    this.remaining,
  });

  final String key;
  final double? declared;
  final double spent;
  final double? remaining;

  factory BudgetEnvelopeOut.fromJson(Map<String, dynamic> json) {
    return BudgetEnvelopeOut(
      key: json['key']?.toString() ?? '',
      declared: (json['declared'] as num?)?.toDouble(),
      spent: (json['spent'] as num?)?.toDouble() ?? 0,
      remaining: (json['remaining'] as num?)?.toDouble(),
    );
  }
}

class BudgetSummaryOut {
  const BudgetSummaryOut({required this.clientId, required this.envelopes});

  final String clientId;
  final List<BudgetEnvelopeOut> envelopes;

  factory BudgetSummaryOut.fromJson(Map<String, dynamic> json) {
    final byKey = <String, BudgetEnvelopeOut>{};
    for (final raw in json['envelopes'] as List? ?? const []) {
      if (raw is! Map) continue;
      final envelope = BudgetEnvelopeOut.fromJson(
        Map<String, dynamic>.from(raw),
      );
      if (budgetEnvelopeKeys.contains(envelope.key)) {
        byKey[envelope.key] = envelope;
      }
    }
    return BudgetSummaryOut(
      clientId: json['client_id']?.toString() ?? '',
      envelopes: [
        for (final key in budgetEnvelopeKeys)
          byKey[key] ?? BudgetEnvelopeOut(key: key, spent: 0),
      ],
    );
  }
}
