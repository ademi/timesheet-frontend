import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/contractor_register/controllers/contractor_register_controller.dart';

void main() {
  group('ContractorRegisterController.resolveInviteToken', () {
    test('returns path token when present', () {
      expect(
        ContractorRegisterController.resolveInviteToken(
          parameters: {'token': 'path-token-abc'},
        ),
        'path-token-abc',
      );
    });

    test('returns legacy invite query param from parameters', () {
      expect(
        ContractorRegisterController.resolveInviteToken(
          parameters: {'invite': 'legacy-token'},
        ),
        'legacy-token',
      );
    });

    test('prefers path token over legacy invite param', () {
      expect(
        ContractorRegisterController.resolveInviteToken(
          parameters: {'token': 'path', 'invite': 'legacy'},
        ),
        'path',
      );
    });

    test('falls back to Uri.base query invite on web', () {
      expect(
        ContractorRegisterController.resolveInviteToken(
          parameters: const {},
          baseUri: Uri.parse(
            'https://app.rostiq.co/contractor/register?invite=web-query',
          ),
        ),
        'web-query',
      );
    });

    test('returns null when no token is available', () {
      expect(
        ContractorRegisterController.resolveInviteToken(parameters: const {}),
        isNull,
      );
    });
  });
}
