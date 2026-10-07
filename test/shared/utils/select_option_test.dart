import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/shared/utils/select_option.dart';

void main() {
  group('parseSelectOptionList', () {
    test('keeps plain human strings as value and label', () {
      final opts = parseSelectOptionList(['Male', 'Female', 'Friend/Family']);
      expect(opts.map((e) => e.value).toList(), [
        'Male',
        'Female',
        'Friend/Family',
      ]);
      expect(opts.map((e) => e.label).toList(), [
        'Male',
        'Female',
        'Friend/Family',
      ]);
    });

    test('parses value/label objects and persists value', () {
      final opts = parseSelectOptionList([
        {'value': 'plan_managed', 'label': 'Plan Managed'},
        {
          'value': 'provider_claim_ndia',
          'label': 'Provider Claims via NDIA',
        },
        {'value': 'self_managed', 'label': 'Self Managed'},
      ]);
      expect(opts.map((e) => e.value).toList(), [
        'plan_managed',
        'provider_claim_ndia',
        'self_managed',
      ]);
      expect(opts.map((e) => e.label).toList(), [
        'Plan Managed',
        'Provider Claims via NDIA',
        'Self Managed',
      ]);
    });

    test('humanizes legacy snake_case plain strings', () {
      final opts = parseSelectOptionList(['plan_managed']);
      expect(opts.single.value, 'plan_managed');
      expect(opts.single.label, 'Plan Managed');
    });

    test('falls back to humanize when object omits label', () {
      final opts = parseSelectOptionList([
        {'value': 'plan_managed'},
      ]);
      expect(opts.single.value, 'plan_managed');
      expect(opts.single.label, 'Plan Managed');
    });
  });

  group('ClientTypeRequirement select options', () {
    test('stores wire codes from enriched plan management options', () {
      const req = ClientTypeRequirement(
        requirementKey: 'plan_management',
        label: 'Plan management',
        sortOrder: 0,
        kind: 'field',
        captureModes: ['field'],
        fieldSchemaJson: {
          'options': [
            {'value': 'plan_managed', 'label': 'Plan Managed'},
            {'value': 'ndia', 'label': 'NDIA'},
            {'value': 'self_managed', 'label': 'Self Managed'},
          ],
        },
        isRequired: true,
        valueType: 'select',
      );

      expect(req.selectOptions, ['plan_managed', 'ndia', 'self_managed']);
      expect(req.labelForSelectValue('plan_managed'), 'Plan Managed');
      expect(req.labelForSelectValue('unknown_code'), 'Unknown Code');
    });

    test('plain string options still work', () {
      const req = ClientTypeRequirement(
        requirementKey: 'referral_source',
        label: 'Referred by',
        sortOrder: 0,
        kind: 'field',
        captureModes: ['field'],
        fieldSchemaJson: {
          'options': ['Friend/Family', 'Self Referred', 'Other'],
        },
        isRequired: false,
        valueType: 'select',
      );

      expect(req.selectOptions, ['Friend/Family', 'Self Referred', 'Other']);
      expect(req.labelForSelectValue('Friend/Family'), 'Friend/Family');
    });
  });

  group('VisitFormFieldSchema options', () {
    test('dropdown values are wire codes; labels are display text', () {
      final field = VisitFormFieldSchema.fromJson({
        'id': 'claiming_method',
        'type': 'text',
        'label': 'Claiming method',
        'required': true,
        'options': [
          {
            'value': 'provider_claim_ndia',
            'label': 'Provider Claims via NDIA',
          },
          'Male',
        ],
      });

      expect(field.options, ['provider_claim_ndia', 'Male']);
      expect(field.optionEntries.map((e) => e.label).toList(), [
        'Provider Claims via NDIA',
        'Male',
      ]);
    });
  });
}
