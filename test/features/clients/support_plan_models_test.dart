import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/support_plan_models.dart';

void main() {
  group('SupportPlanBody', () {
    test('SupportPlanBody fromJson roundtrip goals', () {
      final json = {
        'disability_health': {
          'primary_disability': 'ASD',
          'functional_limitations': ['mobility'],
        },
        'goals': [
          {
            'id': '1',
            'ndis_goal': 'G',
            'strategy': 'S',
            'measure': 'M',
            'worker_instructions': 'W',
            'sort_order': 0,
          }
        ],
      };
      final body = SupportPlanBody.fromJson(json);
      expect(body.goals.first.ndisGoal, 'G');
      expect(body.toJson()['goals'][0]['ndis_goal'], 'G');
    });

    test('toJson emits full nested maps for PATCH full-replace', () {
      final body = SupportPlanBody.fromJson({
        'disability_health': {'primary_disability': 'ASD'},
        'goals': [
          {
            'id': '1',
            'ndis_goal': 'G',
            'strategy': 'S',
            'measure': 'M',
            'worker_instructions': 'W',
            'sort_order': 0,
          }
        ],
      });
      final json = body.toJson();

      expect(json.keys.toSet(), {
        'disability_health',
        'living',
        'goals',
        'service_categories',
        'preferences',
        'risk',
        'schedule',
        'cat_other_detail',
      });
      expect(
        (json['disability_health'] as Map).keys.toSet(),
        {
          'primary_disability',
          'secondary_conditions',
          'functional_limitations',
          'functional_impact_summary',
          'communication_methods',
          'mobility_needs',
          'behaviour_support_plan',
          'medication_schedule',
          'gp_name',
          'gp_phone',
          'support_intensity',
          'limitation_other_detail',
          'comm_other_detail',
        },
      );
      expect(
        (json['living'] as Map).keys.toSet(),
        {
          'residence_type',
          'household_members',
          'informal_supports',
          'residence_other_detail',
        },
      );
      expect(json['disability_health']['primary_disability'], 'ASD');
      expect(json['living']['residence_type'], 'private_home');
      expect(json['living']['residence_other_detail'], '');
      expect(json['cat_other_detail'], '');
      expect(json['risk']['triggers'], '');
      expect(json['schedule']['service_days'], '');
      expect(json['preferences']['routines'], '');
      expect(json['service_categories'], isEmpty);
    });
  });

  group('SupportPlanDto', () {
    test('parses body_invalid flag (CR3)', () {
      final dto = SupportPlanDto.fromJson({
        'id': 'p1',
        'client_id': 'c1',
        'status': 'draft',
        'next_review_at': null,
        'body': <String, dynamic>{},
        'body_invalid': true,
        'review_overdue': false,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      });
      expect(dto.bodyInvalid, isTrue);
      expect(dto.body.goals, isEmpty);
    });
  });

  group('ShiftBriefDto', () {
    test('parses plan_body_invalid flag (CR1)', () {
      final dto = ShiftBriefDto.fromJson({
        'client_id': 'c1',
        'client_name': 'Pat',
        'access_notes': 'Gate',
        'allergies': 'Nuts',
        'support_plan_id': 'p1',
        'plan_body_invalid': true,
        'goals': <dynamic>[],
        'communication_methods': <dynamic>[],
        'service_categories': <dynamic>[],
      });
      expect(dto.planBodyInvalid, isTrue);
      expect(dto.allergies, 'Nuts');
      expect(dto.accessNotes, 'Gate');
      expect(dto.supportPlanId, 'p1');
    });
  });
}
