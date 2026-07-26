import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/app/data/models/auth/auth_token_model.dart';
import 'package:rostiq/app/data/models/auth/engagement_summary_model.dart';
import 'package:rostiq/app/data/models/auth/me_context_model.dart';
import 'package:rostiq/app/data/repositories/auth_repository.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/auth/jwt_claims.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/services/token_storage.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeTokenStorage extends Fake implements TokenStorage {
  _FakeTokenStorage({this.claims});

  JwtClaims? claims;

  @override
  JwtClaims? get jwtClaims => claims;

  @override
  String? get accessToken => claims == null ? null : 'token';

  @override
  String? get lastTenantId => null;

  @override
  Future<void> persistLastTenantSelection({
    required String tenantId,
    String? engagementId,
  }) async {}
}

void main() {
  late _MockAuthRepository authRepository;
  late _FakeTokenStorage tokenStorage;
  late SessionService session;

  setUp(() {
    authRepository = _MockAuthRepository();
    tokenStorage = _FakeTokenStorage();
    session = SessionService(
      tokenStorage: tokenStorage,
      authRepository: authRepository,
    );
  });

  group('SessionService.resolvePostLoginRoute', () {
    test('staff → /staff/home', () {
      tokenStorage.claims = const JwtClaims(
        sub: 'u1',
        tenantId: 't1',
        permissions: ['auth.session'],
        actorType: 'tenant_member',
        iat: 1,
        exp: 2,
      );
      session.actorType.value = 'tenant_member';
      expect(session.resolvePostLoginRoute(), AppRoutes.staffHome);
      expect(session.isStaff, isTrue);
    });

    test('contractor ready → /contractor/home', () {
      tokenStorage.claims = const JwtClaims(
        sub: 'u2',
        tenantId: 't1',
        permissions: ['auth.session'],
        actorType: 'contractor',
        iat: 1,
        exp: 2,
        contractorId: 'c1',
      );
      session.applyMeContext(
        const MeContextModel(
          actorType: 'contractor',
          tenantId: 't1',
          contractorId: 'c1',
          engagements: [
            EngagementSummaryModel(
              id: 'e1',
              tenantId: 't1',
              tenantName: 'Acme',
              status: 'active',
            ),
          ],
        ),
      );
      expect(session.needsOnboarding.value, isFalse);
      expect(session.resolvePostLoginRoute(), AppRoutes.contractorHome);
    });

    test('contractor invited → onboarding', () {
      tokenStorage.claims = const JwtClaims(
        sub: 'u2',
        tenantId: 't1',
        permissions: ['auth.session'],
        actorType: 'contractor',
        iat: 1,
        exp: 2,
        contractorId: 'c1',
      );
      session.applyMeContext(
        const MeContextModel(
          actorType: 'contractor',
          tenantId: 't1',
          contractorId: 'c1',
          engagements: [
            EngagementSummaryModel(
              id: 'e1',
              tenantId: 't1',
              tenantName: 'Acme',
              status: 'invited',
            ),
          ],
        ),
      );
      expect(session.needsOnboarding.value, isTrue);
      expect(session.resolvePostLoginRoute(), AppRoutes.contractorOnboarding);
    });

    test('must change password → first login', () {
      tokenStorage.claims = const JwtClaims(
        sub: 'u1',
        tenantId: 't1',
        permissions: ['*'],
        actorType: 'tenant_member',
        iat: 1,
        exp: 2,
        mustChangePassword: true,
      );
      expect(session.resolvePostLoginRoute(), AppRoutes.firstLogin);
    });
  });

  group('SessionService permissions', () {
    test('platform.admin allows any permission', () {
      tokenStorage.claims = const JwtClaims(
        sub: 'u1',
        tenantId: 't1',
        permissions: ['platform.admin'],
        actorType: 'tenant_member',
        iat: 1,
        exp: 2,
      );
      expect(session.hasPermission('clients.read'), isTrue);
      expect(session.hasAny(['jobs.read', 'visits.read']), isTrue);
    });

    test('star permission allows any', () {
      tokenStorage.claims = const JwtClaims(
        sub: 'u1',
        tenantId: 't1',
        permissions: ['*'],
        actorType: 'tenant_member',
        iat: 1,
        exp: 2,
      );
      expect(session.hasAll(['clients.read', 'jobs.read']), isTrue);
    });
  });

  group('hydrateFromMeContext', () {
    test('applies me/context actor', () async {
      tokenStorage.claims = const JwtClaims(
        sub: 'u1',
        tenantId: 't1',
        permissions: ['auth.session'],
        actorType: 'tenant_member',
        iat: 1,
        exp: 2,
      );
      when(() => authRepository.getMeContext()).thenAnswer(
        (_) async => const MeContextModel(
          actorType: 'tenant_member',
          tenantId: 't1',
          tenantMemberId: 'tm1',
        ),
      );
      await session.hydrateFromMeContext();
      expect(session.actorType.value, 'tenant_member');
      expect(session.tenantMemberId.value, 'tm1');
      verify(() => authRepository.getMeContext()).called(1);
    });
  });

  test('applyAuthTokens stores engagement selection', () async {
    tokenStorage.claims = const JwtClaims(
      sub: 'u1',
      tenantId: 't1',
      permissions: ['auth.session'],
      actorType: 'contractor',
      iat: 1,
      exp: 2,
      contractorId: 'c1',
    );
    await session.applyAuthTokens(
      const AuthTokenModel(
        accessToken: 'a',
        refreshToken: 'r',
        tokenType: 'bearer',
        actorType: 'contractor',
        engagements: [
          EngagementSummaryModel(
            id: 'e9',
            tenantId: 't1',
            tenantName: 'Acme',
            status: 'active',
          ),
        ],
      ),
    );
    expect(session.selectedEngagementId.value, 'e9');
    expect(session.isContractor, isTrue);
  });
}
