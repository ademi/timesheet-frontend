import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rostiq/app/data/models/auth/auth_token_model.dart';
import 'package:rostiq/app/data/models/auth/engagement_summary_model.dart';
import 'package:rostiq/app/data/models/auth/me_context_model.dart';
import 'package:rostiq/app/data/repositories/auth_repository.dart';
import 'package:rostiq/app/routes/app_routes.dart';
import 'package:rostiq/core/auth/jwt_claims.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/core/services/token_storage.dart';
import 'package:rostiq/features/contractor_onboarding/data/onboarding_progress_store.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeTokenStorage extends Fake implements TokenStorage {
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
  late OnboardingProgressStore progressStore;
  late Directory storageDirectory;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storageDirectory = await Directory.systemTemp.createTemp('rostiq_session_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return storageDirectory.path;
          }
          return null;
        });
    await GetStorage.init();
  });

  tearDownAll(() async {
    await storageDirectory.delete(recursive: true);
  });

  setUp(() async {
    authRepository = _MockAuthRepository();
    tokenStorage = _FakeTokenStorage();
    progressStore = OnboardingProgressStore();
    await progressStore.save('c1', const OnboardingProgressSnapshot.empty());
    session = SessionService(
      tokenStorage: tokenStorage,
      authRepository: authRepository,
      onboardingProgressStore: progressStore,
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

    test('platform complete contractor → /contractor/home', () async {
      await progressStore.markPlatformComplete('c1');
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

    test('contractor invited with incomplete platform → onboarding legal', () {
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
      expect(
        session.resolvePostLoginRoute(),
        AppRoutes.contractorOnboardingLegal,
      );
    });

    test(
      'multi-engagement contractor with incomplete platform → onboarding legal',
      () {
        tokenStorage.claims = const JwtClaims(
          sub: 'u2',
          tenantId: null,
          permissions: ['auth.session'],
          actorType: 'contractor',
          iat: 1,
          exp: 2,
          contractorId: 'c1',
        );
        session.applyMeContext(
          const MeContextModel(
            actorType: 'contractor',
            contractorId: 'c1',
            engagements: [
              EngagementSummaryModel(
                id: 'e1',
                tenantId: 't1',
                tenantName: 'Acme',
                status: 'invited',
              ),
              EngagementSummaryModel(
                id: 'e2',
                tenantId: 't2',
                tenantName: 'Globex',
                status: 'invited',
              ),
            ],
          ),
        );
        expect(session.needsPlatformCompliance.value, isTrue);
        expect(
          session.resolvePostLoginRoute(),
          AppRoutes.contractorOnboardingLegal,
        );
      },
    );

    test('platform complete contractor with no engagements → home', () async {
      await progressStore.markPlatformComplete('c1');
      tokenStorage.claims = const JwtClaims(
        sub: 'u2',
        tenantId: null,
        permissions: ['auth.session'],
        actorType: 'contractor',
        iat: 1,
        exp: 2,
        contractorId: 'c1',
      );
      session.applyMeContext(
        const MeContextModel(actorType: 'contractor', contractorId: 'c1'),
      );
      expect(session.needsPlatformCompliance.value, isFalse);
      expect(session.needsEngagementWork.value, isFalse);
      expect(session.needsOnboarding.value, isFalse);
      expect(session.resolvePostLoginRoute(), AppRoutes.contractorHome);
    });

    test(
      'platform complete invited contractor → onboarding engagement',
      () async {
        await progressStore.markPlatformComplete('c1');
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
        expect(session.needsPlatformCompliance.value, isFalse);
        expect(session.needsInviteAccept, isTrue);
        expect(session.needsEngagementWork.value, isTrue);
        expect(
          session.resolvePostLoginRoute(),
          AppRoutes.contractorOnboardingEngagement,
        );
      },
    );

    test(
      'pending_docs does not set needsOnboarding when platform complete',
      () async {
        await progressStore.markPlatformComplete('c1');
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
                status: 'pending_docs',
              ),
            ],
          ),
        );
        expect(session.needsPlatformCompliance.value, isFalse);
        expect(session.needsInviteAccept, isFalse);
        expect(session.needsOnboarding.value, isFalse);
        expect(session.needsDocsAttention, isTrue);
        expect(session.resolvePostLoginRoute(), AppRoutes.contractorHome);
      },
    );

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

    test('shares an in-flight me/context request', () async {
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

      await Future.wait([
        session.hydrateFromMeContext(),
        session.hydrateFromMeContext(),
      ]);

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
