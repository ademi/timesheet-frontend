import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/auth/landing_auth_handoff.dart';
import 'package:rostiq/app/routes/app_routes.dart';

void main() {
  group('parseLandingAuthHandoffFragment', () {
    test('parses landing hash params', () {
      final handoff = parseLandingAuthHandoffFragment(
        'access_token=tok-a&token_type=bearer&tenant_id=ten-1'
        '&admin_must_change_password=false&refresh_token=tok-r',
      );

      expect(handoff, isNotNull);
      expect(handoff!.accessToken, 'tok-a');
      expect(handoff.refreshToken, 'tok-r');
      expect(handoff.tokenType, 'bearer');
      expect(handoff.tenantId, 'ten-1');
      expect(handoff.adminMustChangePassword, isFalse);
    });

    test('accepts leading hash and must-change true', () {
      final handoff = parseLandingAuthHandoffFragment(
        '#access_token=abc&admin_must_change_password=true',
      );

      expect(handoff, isNotNull);
      expect(handoff!.accessToken, 'abc');
      expect(handoff.refreshToken, isEmpty);
      expect(handoff.adminMustChangePassword, isTrue);
      expect(handoff.tokenType, 'bearer');
    });

    test('returns null without access_token', () {
      expect(
        parseLandingAuthHandoffFragment('refresh_token=only'),
        isNull,
      );
      expect(parseLandingAuthHandoffFragment(''), isNull);
      expect(parseLandingAuthHandoffFragment(null), isNull);
    });

    test('toAuthTokens maps must-change flag', () {
      final tokens = parseLandingAuthHandoffFragment(
        'access_token=a&refresh_token=r&admin_must_change_password=1',
      )!.toAuthTokens();

      expect(tokens.accessToken, 'a');
      expect(tokens.refreshToken, 'r');
      expect(tokens.mustChangePassword, isTrue);
    });
  });

  group('isLandingAuthHandoffPath', () {
    test('matches landing aliases only', () {
      expect(isLandingAuthHandoffPath(AppRoutes.adminPanel), isTrue);
      expect(isLandingAuthHandoffPath(AppRoutes.changePassword), isTrue);
      expect(isLandingAuthHandoffPath(AppRoutes.staffHome), isFalse);
      expect(isLandingAuthHandoffPath(AppRoutes.login), isFalse);
    });
  });
}
