import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/features/contractor_register/controllers/contractor_register_controller.dart';
import 'package:rostiq/features/contractor_register/data/repositories/contractor_register_repository.dart';

class _MockRepository extends Mock implements ContractorRegisterRepository {}

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

    test('falls back to Uri.base path token on web deep link', () {
      expect(
        ContractorRegisterController.resolveInviteToken(
          parameters: const {},
          baseUri: Uri.parse(
            'http://localhost:5173/contractor/register/NfbL--92RGctMTm7',
          ),
        ),
        'NfbL--92RGctMTm7',
      );
    });

    test('returns null when no token is available', () {
      expect(
        ContractorRegisterController.resolveInviteToken(parameters: const {}),
        isNull,
      );
    });
  });

  group('ContractorRegisterController identity-only register', () {
    late _MockRepository repository;
    late ContractorRegisterController controller;

    setUp(() {
      Get.testMode = true;
      Get.reset();
      repository = _MockRepository();
      controller = ContractorRegisterController(repository: repository);
      // Skip onInit invite load — construct without putting into Get if needed.
      // Controller.onInit runs when put; call fields directly after construction.
    });

    tearDown(() {
      controller.dispose();
      Get.reset();
    });

    test('stepLabels is Identity only', () {
      expect(ContractorRegisterController.stepLabels, ['Identity']);
      expect(
        ContractorRegisterController.stepLabels,
        isNot(contains('Screening')),
      );
      expect(
        ContractorRegisterController.stepLabels,
        isNot(contains('Qualifications')),
      );
      expect(
        ContractorRegisterController.stepLabels,
        isNot(contains('Checks')),
      );
      expect(ContractorRegisterController.stepLabels, isNot(contains('Legal')));
    });

    test('buildRegisterRequest is identity-only (no compliance/terms/privacy)', () {
      controller.fullNameController.text = 'Alex Worker';
      controller.emailController.text = 'alex@example.com';
      controller.passwordController.text = 'Password1';
      controller.phoneController.text = '+61400000000';

      final request = controller.buildRegisterRequest();
      final json = request.toJson();

      expect(json['full_name'], 'Alex Worker');
      expect(json['email'], 'alex@example.com');
      expect(json['password'], 'Password1');
      expect(json['phone'], '+61400000000');
      expect(json.containsKey('compliance'), isFalse);
      expect(json.containsKey('terms_version'), isFalse);
      expect(json.containsKey('privacy_version'), isFalse);
    });
  });
}
