import 'package:flutter_test/flutter_test.dart';

import 'package:rostiq/features/engagements/data/models/engagement_models.dart';

void main() {
  test('parses a registration invite response', () {
    final response = EngagementInviteResponse.fromJson({
      'kind': 'registration_invite',
      'engagement': null,
      'registration_invite': {
        'id': 'invite-1',
        'email': 'new.contractor@example.com',
        'phone': null,
        'required_categories': ['wwcc'],
        'expires_at': '2026-08-01T00:00:00Z',
        'created_at': '2026-07-30T00:00:00Z',
      },
    });

    expect(response.isRegistrationInvite, isTrue);
    expect(response.registrationInvite?.email, 'new.contractor@example.com');
    expect(response.engagement, isNull);
  });

  test('parses an engagement invite response', () {
    final response = EngagementInviteResponse.fromJson({
      'kind': 'engagement',
      'engagement': {
        'id': 'engagement-1',
        'tenant_id': 'tenant-1',
        'contractor_id': 'contractor-1',
        'status': 'invited',
        'created_at': '2026-07-30T00:00:00Z',
        'updated_at': '2026-07-30T00:00:00Z',
      },
      'registration_invite': null,
    });

    expect(response.isEngagement, isTrue);
    expect(response.engagement?.id, 'engagement-1');
    expect(response.registrationInvite, isNull);
  });

  test('EngagementOut parses pack docs-status fields', () {
    final engagement = EngagementOut.fromJson({
      'id': 'engagement-1',
      'tenant_id': 'tenant-1',
      'contractor_id': 'contractor-1',
      'status': 'pending_docs',
      'created_at': '2026-07-30T00:00:00Z',
      'updated_at': '2026-07-30T00:00:00Z',
      'document_pack': 'support_worker_v1',
      'required_resolved': ['resume', 'passport_id', 'wwcc'],
      'missing': ['passport_id'],
      'photo_id_points_total': 70,
      'onboarding_flags': {'wwcc_applicable': true},
    });

    expect(engagement.documentPack, 'support_worker_v1');
    expect(engagement.requiredResolved, ['resume', 'passport_id', 'wwcc']);
    expect(engagement.apiMissing, ['passport_id']);
    expect(engagement.photoIdPointsTotal, 70);
    expect(engagement.onboardingFlags['wwcc_applicable'], isTrue);
  });

  test('RequiredDocCategory parses label and falls back when missing', () {
    final withLabel = RequiredDocCategory.fromJson({
      'category': 'passport_id',
      'label': 'Passport',
      'is_required': true,
    });
    expect(withLabel.category, 'passport_id');
    expect(withLabel.label, 'Passport');
    expect(withLabel.displayLabel, 'Passport');
    expect(withLabel.isRequired, isTrue);

    final withoutLabel = RequiredDocCategory.fromJson({
      'category': 'wwcc',
      'is_required': false,
    });
    expect(withoutLabel.category, 'wwcc');
    expect(withoutLabel.isRequired, isFalse);
    expect(withoutLabel.displayLabel, 'Working With Children Check');
  });

  test('invite preview existing_account is not blocking', () {
    const preview = EngagementInvitePreviewOut(
      outcome: 'existing_account',
      message: 'Already has a login.',
    );
    expect(preview.isExistingAccount, isTrue);
    expect(preview.isBlocking, isFalse);
  });

  test('invite preview hard_split remains blocking', () {
    const preview = EngagementInvitePreviewOut(
      outcome: 'hard_split_violation',
      message: 'Staff member.',
    );
    expect(preview.isBlocking, isTrue);
  });
}
