import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/models/ndis_budget_types.dart';
import 'package:rostiq/features/clients/models/ndis_plan_budget_entry.dart';
import 'package:rostiq/features/clients/utils/ndis_plan_budgets_codec.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';

void main() {
  group('NdisPlanBudgetEntry', () {
    test('toJson / fromJson round-trip', () {
      const entry = NdisPlanBudgetEntry(
        type: NdisBudgetType.core,
        amountDollars: 45000.5,
      );
      final decoded = NdisPlanBudgetEntry.fromJson(entry.toJson());
      expect(decoded, entry);
    });

    test('other budget keeps label', () {
      const entry = NdisPlanBudgetEntry(
        type: NdisBudgetType.other,
        amountDollars: 500,
        label: 'Transport top-up',
      );
      final json = entry.toJson();
      expect(json['label'], 'Transport top-up');
      expect(
        NdisPlanBudgetEntry.fromJson(json).label,
        'Transport top-up',
      );
    });
  });

  group('NdisPlanBudgetsCodec', () {
    test('resolveFromFacts prefers JSON over legacy flat keys', () {
      final facts = [
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.budgetCore,
          valueJson: 100,
        ),
        ClientProfileFactOut(
          requirementKey: OnboardingKeys.ndisPlanBudgets,
          valueJson: {
            'budgets': [
              {
                'type': NdisBudgetType.core,
                'amount_dollars': 200,
              },
            ],
          },
        ),
      ];
      final entries = NdisPlanBudgetsCodec.resolveFromFacts(facts);
      expect(entries, hasLength(1));
      expect(entries.first.type, NdisBudgetType.core);
      expect(entries.first.amountDollars, 200);
    });

    test('fromLegacyFacts maps cb to capacity_building', () {
      final facts = [
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.budgetCb,
          valueJson: 12000,
        ),
      ];
      final entries = NdisPlanBudgetsCodec.fromLegacyFacts(facts);
      expect(entries.single.type, NdisBudgetType.capacityBuilding);
      expect(entries.single.amountDollars, 12000);
    });

    test('toFactValue builds budgets array', () {
      final value = NdisPlanBudgetsCodec.toFactValue([
        const NdisPlanBudgetEntry(
          type: NdisBudgetType.capital,
          amountDollars: 8000,
        ),
      ]);
      expect(value, isNotNull);
      final budgets = value!['budgets'] as List;
      expect(budgets.single['type'], NdisBudgetType.capital);
    });

    test('validateDollarText rejects abc', () {
      expect(
        NdisPlanBudgetsCodec.validateDollarText('abc'),
        isNotNull,
      );
    });

    test('validateDollarText rejects negative amounts', () {
      expect(
        NdisPlanBudgetsCodec.validateDollarText('-100'),
        contains('negative'),
      );
    });
  });
}
