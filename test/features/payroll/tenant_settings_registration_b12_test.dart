import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/payroll/data/models/payroll_models.dart';

void main() {
  test('TenantSettingsOut parses ndis_provider_registration_status', () {
    final registered = TenantSettingsOut.fromJson({
      'id': 't1',
      'name': 'Demo',
      'timezone': 'Australia/Sydney',
      'ndis_provider_registration_status': 'registered',
    });
    expect(registered.ndisProviderRegistrationStatus, 'registered');

    final unregistered = TenantSettingsOut.fromJson({
      'id': 't1',
      'ndis_provider_registration_status': 'unregistered',
    });
    expect(unregistered.ndisProviderRegistrationStatus, 'unregistered');

    final missing = TenantSettingsOut.fromJson({'id': 't1'});
    expect(missing.ndisProviderRegistrationStatus, 'registered');
  });

  test('TenantSettingsOut parses default_progress_note_template_id', () {
    final withTpl = TenantSettingsOut.fromJson({
      'id': 't1',
      'default_progress_note_template_id': 'tpl-99',
    });
    expect(withTpl.defaultProgressNoteTemplateId, 'tpl-99');

    final cleared = TenantSettingsOut.fromJson({'id': 't1'});
    expect(cleared.defaultProgressNoteTemplateId, isNull);
  });
}
