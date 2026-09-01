import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/models/support_plan_specialist_entry.dart';
import 'package:rostiq/features/clients/models/support_plan_specialist_types.dart';
import 'package:rostiq/features/clients/utils/onboarding_keys.dart';
import 'package:rostiq/features/clients/utils/support_plan_specialists_codec.dart';

void main() {
  group('SupportPlanSpecialistEntry', () {
    test('create assigns unique ids', () {
      final a = SupportPlanSpecialistEntry.create(
        SupportPlanSpecialistTypes.speechTherapist,
      );
      final b = SupportPlanSpecialistEntry.create(
        SupportPlanSpecialistTypes.speechTherapist,
      );
      expect(a.id, isNot(equals(b.id)));
      a.dispose();
      b.dispose();
    });

    test('toJson / fromJson round-trip', () {
      final entry = SupportPlanSpecialistEntry.create(
        SupportPlanSpecialistTypes.speechTherapist,
      );
      entry.fields.nameCtrl.text = 'Alex Lee';
      entry.fields.phoneCtrl.text = '0400000000';

      final decoded = SupportPlanSpecialistEntry.fromJson(entry.toJson());
      expect(decoded.type, SupportPlanSpecialistTypes.speechTherapist);
      expect(decoded.fields.nameCtrl.text, 'Alex Lee');
      expect(decoded.fields.phoneCtrl.text, '0400000000');
      entry.dispose();
      decoded.dispose();
    });

    test('other type keeps custom label', () {
      final entry = SupportPlanSpecialistEntry.create(
        SupportPlanSpecialistTypes.other,
        customLabel: 'Dietitian',
      );
      entry.fields.nameCtrl.text = 'Sam';

      final json = entry.toJson();
      expect(json['custom_label'], 'Dietitian');
      expect(json['type'], SupportPlanSpecialistTypes.other);
      entry.dispose();
    });
  });

  group('SupportPlanSpecialistsCodec', () {
    test('resolveFromFacts prefers JSON over legacy flat keys', () {
      final facts = [
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.supportCoordinatorName,
          valueJson: 'Legacy Name',
        ),
        ClientProfileFactOut(
          requirementKey: OnboardingKeys.supportPlanSpecialists,
          valueJson: [
            {
              'type': SupportPlanSpecialistTypes.speechTherapist,
              'name': 'JSON Name',
            },
          ],
        ),
      ];
      final entries = SupportPlanSpecialistsCodec.resolveFromFacts(facts);
      expect(entries, hasLength(1));
      expect(entries.first.type, SupportPlanSpecialistTypes.speechTherapist);
      expect(entries.first.fields.nameCtrl.text, 'JSON Name');
      for (final e in entries) {
        e.dispose();
      }
    });

    test('fromLegacyFacts builds one entry per populated block', () {
      final facts = [
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.supportCoordinatorName,
          valueJson: 'Jane SC',
        ),
        const ClientProfileFactOut(
          requirementKey: OnboardingKeys.physiotherapistName,
          valueJson: 'Bob PT',
        ),
      ];
      final entries = SupportPlanSpecialistsCodec.fromLegacyFacts(facts);
      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e.type).toSet(),
        {
          SupportPlanSpecialistTypes.supportCoordinator,
          SupportPlanSpecialistTypes.physiotherapist,
        },
      );
      for (final e in entries) {
        e.dispose();
      }
    });

    test('fromFactValue decodes stringified JSON array', () {
      const json = '[{"type":"physiotherapist","name":"Bob PT"}]';
      final entries = SupportPlanSpecialistsCodec.fromFactValue(json);
      expect(entries, hasLength(1));
      expect(entries.first.type, SupportPlanSpecialistTypes.physiotherapist);
      expect(entries.first.fields.nameCtrl.text, 'Bob PT');
      for (final e in entries) {
        e.dispose();
      }
    });

    test('toFactValue skips empty rows', () {
      final empty = SupportPlanSpecialistEntry.create(
        SupportPlanSpecialistTypes.occupationalTherapist,
      );
      final filled = SupportPlanSpecialistEntry.create(
        SupportPlanSpecialistTypes.behaviouralTherapist,
      )..fields.emailCtrl.text = 'a@b.com';

      final json = SupportPlanSpecialistsCodec.toFactValue([empty, filled]);
      expect(json, hasLength(1));
      expect(json.single['type'], SupportPlanSpecialistTypes.behaviouralTherapist);

      empty.dispose();
      filled.dispose();
    });
  });
}
