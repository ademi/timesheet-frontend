import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/models/client_profile_models.dart';
import '../utils/onboarding_keys.dart';
import '../models/ndis_budget_types.dart';
import '../models/ndis_plan_budget_entry.dart';

/// Encode/decode [OnboardingKeys.ndisPlanBudgets] JSON and legacy flat budget facts.
abstract final class NdisPlanBudgetsCodec {
  static const budgetsKey = 'budgets';

  static String formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  static String? validateDollarText(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (double.tryParse(t) == null) {
      return 'Budget values must be valid dollar amounts.';
    }
    return null;
  }

  static String? validateAll({
    required String core,
    required String capacityBuilding,
    required String capital,
    required String otherAmount,
  }) {
    for (final raw in [core, capacityBuilding, capital, otherAmount]) {
      final err = validateDollarText(raw);
      if (err != null) return err;
    }
    return null;
  }

  static List<NdisPlanBudgetEntry> fromFactValue(Object? valueJson) {
    if (valueJson == null) return const [];
    Map<String, dynamic>? map;
    if (valueJson is Map<String, dynamic>) {
      map = valueJson;
    } else if (valueJson is Map) {
      map = Map<String, dynamic>.from(valueJson);
    } else if (valueJson is String) {
      final decoded = jsonDecode(valueJson);
      if (decoded is Map<String, dynamic>) {
        map = decoded;
      } else if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
    }
    if (map == null) return const [];
    final rawList = map[budgetsKey];
    if (rawList is! List) return const [];
    final out = <NdisPlanBudgetEntry>[];
    for (final item in rawList) {
      if (item is! Map) continue;
      try {
        out.add(
          NdisPlanBudgetEntry.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        // skip corrupt row
      }
    }
    return out;
  }

  static List<NdisPlanBudgetEntry> fromLegacyFacts(
    Iterable<ClientProfileFactOut> facts,
  ) {
    String? read(String key) {
      for (final f in facts) {
        if (f.requirementKey == key) {
          final v = f.valueJson;
          if (v == null) return null;
          final s = v.toString().trim();
          return s.isEmpty ? null : s;
        }
      }
      return null;
    }

    NdisPlanBudgetEntry? entry(String type, String? raw, {String? label}) {
      if (raw == null) return null;
      final amount = double.tryParse(raw);
      if (amount == null) return null;
      return NdisPlanBudgetEntry(
        type: type,
        amountDollars: amount,
        label: label,
      );
    }

    final out = <NdisPlanBudgetEntry>[];
    void addEntry(NdisPlanBudgetEntry? e) {
      if (e != null) out.add(e);
    }

    addEntry(entry(NdisBudgetType.core, read(OnboardingKeys.budgetCore)));
    addEntry(
      entry(NdisBudgetType.capacityBuilding, read(OnboardingKeys.budgetCb)),
    );
    addEntry(entry(NdisBudgetType.capital, read(OnboardingKeys.budgetCapital)));
    final otherAmount = read(OnboardingKeys.budgetOther);
    if (otherAmount != null) {
      addEntry(
        entry(
          NdisBudgetType.other,
          otherAmount,
          label: read(OnboardingKeys.budgetOtherLabel),
        ),
      );
    }
    return out;
  }

  static List<NdisPlanBudgetEntry> resolveFromFacts(
    Iterable<ClientProfileFactOut> facts,
  ) {
    Object? jsonValue;
    for (final f in facts) {
      if (f.requirementKey == OnboardingKeys.ndisPlanBudgets) {
        jsonValue = f.valueJson;
        break;
      }
    }
    final fromJson = fromFactValue(jsonValue);
    if (fromJson.isNotEmpty) return fromJson;
    return fromLegacyFacts(facts);
  }

  static void applyToControllers({
    required List<NdisPlanBudgetEntry> entries,
    required TextEditingController core,
    required TextEditingController capacityBuilding,
    required TextEditingController capital,
    required TextEditingController otherLabel,
    required TextEditingController otherAmount,
  }) {
    core.clear();
    capacityBuilding.clear();
    capital.clear();
    otherLabel.clear();
    otherAmount.clear();
    for (final e in entries) {
      final text = formatAmount(e.amountDollars);
      switch (e.type) {
        case NdisBudgetType.core:
          core.text = text;
        case NdisBudgetType.capacityBuilding:
          capacityBuilding.text = text;
        case NdisBudgetType.capital:
          capital.text = text;
        case NdisBudgetType.other:
          otherLabel.text = e.label ?? '';
          otherAmount.text = text;
      }
    }
  }

  static List<NdisPlanBudgetEntry> readFromControllers({
    required TextEditingController core,
    required TextEditingController capacityBuilding,
    required TextEditingController capital,
    required TextEditingController otherLabel,
    required TextEditingController otherAmount,
  }) {
    final out = <NdisPlanBudgetEntry>[];
    void add(String type, String raw, {String? label}) {
      final t = raw.trim();
      if (t.isEmpty) return;
      final amount = double.parse(t);
      out.add(
        NdisPlanBudgetEntry(type: type, amountDollars: amount, label: label),
      );
    }

    add(NdisBudgetType.core, core.text);
    add(NdisBudgetType.capacityBuilding, capacityBuilding.text);
    add(NdisBudgetType.capital, capital.text);
    add(
      NdisBudgetType.other,
      otherAmount.text,
      label: otherLabel.text.trim().isEmpty ? null : otherLabel.text.trim(),
    );
    return out;
  }

  static Map<String, dynamic>? toFactValue(List<NdisPlanBudgetEntry> entries) {
    if (entries.isEmpty) return null;
    return {
      budgetsKey: entries.map((e) => e.toJson()).toList(),
    };
  }
}
