import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/contractor_me/data/models/contractor_me_models.dart';

void main() {
  Map<String, dynamic> baseJson({
    String? abn = '53004085616',
    bool? profileOnboardingComplete,
    Map<String, dynamic>? onboardingFlags,
    Map<String, dynamic>? profileSectionsTouched,
    bool? abnComplete,
  }) => {
    'id': 'c1',
    'user_id': 'u1',
    'full_name': 'Alex',
    'abn': abn,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
    if (abnComplete != null) 'abn_complete': abnComplete,
    if (profileOnboardingComplete != null)
      'profile_onboarding_complete': profileOnboardingComplete,
    if (onboardingFlags != null) 'onboarding_flags': onboardingFlags,
    if (profileSectionsTouched != null)
      'profile_sections_touched': profileSectionsTouched,
  };

  test('isProfileComplete is ABN-only (legacy)', () {
    expect(
      ContractorMeOut.fromJson(baseJson(abn: '53004085616')).isProfileComplete,
      isTrue,
    );
    expect(
      ContractorMeOut.fromJson(baseJson(abn: null)).isProfileComplete,
      isFalse,
    );
  });

  test('isOnboardingComplete uses profile_onboarding_complete from API', () {
    final incomplete = ContractorMeOut.fromJson(
      baseJson(profileOnboardingComplete: false),
    );
    expect(incomplete.isOnboardingComplete, isFalse);
    expect(incomplete.isProfileComplete, isTrue);

    final complete = ContractorMeOut.fromJson(
      baseJson(profileOnboardingComplete: true),
    );
    expect(complete.isOnboardingComplete, isTrue);
  });

  test('derives onboarding complete from flags + sections + ABN when API omits', () {
    final incomplete = ContractorMeOut.fromJson(
      baseJson(
        onboardingFlags: {
          'wwcc_applicable': true,
          'qualifications_applicable': false,
          'drives_participants': false,
          'uses_own_vehicle': false,
        },
        profileSectionsTouched: {
          'screening': true,
          'qualifications': true,
          'checks': false,
        },
      ),
    );
    expect(incomplete.isOnboardingComplete, isFalse);

    final complete = ContractorMeOut.fromJson(
      baseJson(
        onboardingFlags: {
          'wwcc_applicable': true,
          'qualifications_applicable': false,
          'drives_participants': false,
          'uses_own_vehicle': false,
        },
        profileSectionsTouched: {
          'screening': true,
          'qualifications': true,
          'checks': true,
        },
      ),
    );
    expect(complete.isOnboardingComplete, isTrue);
  });

  test('parses onboarding_flags from metadata when top-level absent', () {
    final me = ContractorMeOut.fromJson({
      ...baseJson(abn: '53004085616'),
      'metadata': {
        'onboarding_flags': {'wwcc_applicable': true},
        'profile_sections_touched': {'screening': true},
      },
    });
    expect(me.onboardingFlags['wwcc_applicable'], isTrue);
    expect(me.profileSectionsTouched['screening'], isTrue);
  });
}
