import 'package:get/get.dart';

import '../../app/data/models/auth/auth_token_model.dart';
import '../../app/data/models/auth/engagement_summary_model.dart';
import '../../app/data/models/auth/me_context_model.dart';
import '../../app/data/repositories/auth_repository.dart';
import '../../app/routes/app_routes.dart';
import '../../features/contractor_onboarding/data/onboarding_progress_store.dart';
import '../../features/contractor_onboarding/onboarding_routing.dart';
import '../auth/jwt_claims.dart';
import '../constants/feature_flags.dart';
import 'token_storage.dart';

/// Permanent session: actor, engagements, permissions, post-login routing.
///
/// After login / refresh / switch-tenant / app resume with tokens →
/// call [hydrateFromMeContext] (`GET /v1/auth/me/context`).
class SessionService extends GetxController {
  SessionService({
    required TokenStorage tokenStorage,
    required AuthRepository authRepository,
    OnboardingProgressStore? onboardingProgressStore,
  }) : _tokenStorage = tokenStorage,
       _authRepository = authRepository,
       _onboardingProgressStore =
           onboardingProgressStore ?? OnboardingProgressStore();

  final TokenStorage _tokenStorage;
  final AuthRepository _authRepository;
  final OnboardingProgressStore _onboardingProgressStore;

  final actorType = RxnString();
  final tenantId = RxnString();
  final contractorId = RxnString();
  final tenantMemberId = RxnString();
  final engagements = <EngagementSummaryModel>[].obs;
  final selectedTenantId = RxnString();
  final selectedEngagementId = RxnString();
  final mustChangePassword = false.obs;
  final isHydrating = false.obs;
  final needsOnboarding = false.obs;
  final needsPlatformCompliance = false.obs;
  final needsEngagementWork = false.obs;

  JwtClaims? get claims => _tokenStorage.jwtClaims;

  bool get isStaff =>
      claims?.isTenantMember ?? actorType.value == 'tenant_member';

  bool get isTenantMember => isStaff;

  bool get isContractor =>
      claims?.isContractor ?? actorType.value == 'contractor';

  EngagementSummaryModel? get selectedEngagement {
    final id = selectedEngagementId.value;
    if (id == null) return null;
    for (final e in engagements) {
      if (e.id == id) return e;
    }
    return null;
  }

  String? get selectedEngagementStatus => selectedEngagement?.status;

  bool get isPendingDocs {
    final s = selectedEngagementStatus;
    return s == 'pending_docs' || s == 'invited' || s == 'approved';
  }

  bool hasPermission(String permission) {
    final c = claims;
    if (c == null) return false;
    if (c.permissions.contains('*')) return true;
    if (c.permissions.contains('platform.admin')) return true;
    return c.hasPermission(permission);
  }

  bool hasAny(List<String> permissions) {
    for (final p in permissions) {
      if (hasPermission(p)) return true;
    }
    return false;
  }

  bool hasAll(List<String> permissions) {
    for (final p in permissions) {
      if (!hasPermission(p)) return false;
    }
    return true;
  }

  /// Apply login / refresh / switch-tenant body into session + storage.
  Future<void> applyAuthTokens(AuthTokenModel tokens) async {
    actorType.value = tokens.actorType ?? claims?.actorType;
    engagements.assignAll(tokens.engagements);
    mustChangePassword.value =
        tokens.mustChangePassword || (claims?.mustChangePassword ?? false);
    contractorId.value = claims?.contractorId;
    tenantMemberId.value = claims?.tenantMemberId;

    final tenantFromJwt = claims?.tenantId;
    if (tenantFromJwt != null) {
      selectedTenantId.value = tenantFromJwt;
      tenantId.value = tenantFromJwt;
    }

    EngagementSummaryModel? match;
    if (tenantFromJwt != null) {
      for (final e in tokens.engagements) {
        if (e.tenantId == tenantFromJwt) {
          match = e;
          break;
        }
      }
    }
    match ??= tokens.engagements.isNotEmpty ? tokens.engagements.first : null;
    selectedEngagementId.value = match?.id;
    _recomputeOnboarding();

    if (tenantFromJwt != null) {
      await _tokenStorage.persistLastTenantSelection(
        tenantId: tenantFromJwt,
        engagementId: match?.id,
      );
    }
  }

  Future<void> hydrateFromMeContext() async {
    if (!FeatureFlags.domainV2) return;
    if (_tokenStorage.accessToken == null) return;
    isHydrating.value = true;
    try {
      final ctx = await _authRepository.getMeContext();
      applyMeContext(ctx);
    } catch (_) {
      actorType.value ??= claims?.actorType;
      selectedTenantId.value ??= claims?.tenantId;
      tenantId.value ??= claims?.tenantId;
      contractorId.value ??= claims?.contractorId;
      tenantMemberId.value ??= claims?.tenantMemberId;
      _recomputeOnboarding();
    } finally {
      isHydrating.value = false;
    }
  }

  void applyMeContext(MeContextModel ctx) {
    actorType.value = ctx.actorType;
    engagements.assignAll(ctx.engagements);
    tenantId.value = ctx.tenantId;
    contractorId.value = ctx.contractorId;
    tenantMemberId.value = ctx.tenantMemberId;
    selectedTenantId.value = ctx.tenantId ?? selectedTenantId.value;
    if (ctx.tenantId != null) {
      for (final e in ctx.engagements) {
        if (e.tenantId == ctx.tenantId) {
          selectedEngagementId.value = e.id;
          break;
        }
      }
    } else if (engagements.isNotEmpty && selectedEngagementId.value == null) {
      selectedEngagementId.value = engagements.first.id;
    }
    _recomputeOnboarding();
  }

  void _recomputeOnboarding() {
    if (!isContractor) {
      needsOnboarding.value = false;
      needsPlatformCompliance.value = false;
      needsEngagementWork.value = false;
      return;
    }
    final statuses = engagements.map((e) => e.status).toSet();
    needsPlatformCompliance.value =
        !_onboardingProgressStore.isPlatformComplete(contractorId.value);
    needsEngagementWork.value = statuses.any(
      (status) =>
          status == 'invited' ||
          status == 'pending_docs' ||
          status == 'approved',
    );
    needsOnboarding.value =
        needsPlatformCompliance.value || needsEngagementWork.value;
  }

  void refreshOnboardingFlags() => _recomputeOnboarding();

  Future<AuthTokenModel> switchTenant(String nextTenantId) async {
    final tokens = await _authRepository.switchTenant(nextTenantId);
    await applyAuthTokens(tokens);
    await hydrateFromMeContext();
    return tokens;
  }

  Future<void> clear() async {
    actorType.value = null;
    tenantId.value = null;
    contractorId.value = null;
    tenantMemberId.value = null;
    engagements.clear();
    selectedTenantId.value = null;
    selectedEngagementId.value = null;
    mustChangePassword.value = false;
    needsOnboarding.value = false;
    needsPlatformCompliance.value = false;
    needsEngagementWork.value = false;
  }

  /// Design §4.2 post-login / restore landing route.
  String resolvePostLoginRoute() {
    if (mustChangePassword.value || (claims?.mustChangePassword ?? false)) {
      return AppRoutes.firstLogin;
    }
    if (isStaff) {
      return AppRoutes.staffHome;
    }
    if (isContractor) {
      if (engagements.length > 1 && claims?.tenantId == null) {
        return AppRoutes.contractorProfile;
      }
      if (needsOnboarding.value) {
        return OnboardingRouting.entryRoute(
          needsPlatformCompliance: needsPlatformCompliance.value,
          needsEngagementWork: needsEngagementWork.value,
        );
      }
      return AppRoutes.contractorHome;
    }
    return AppRoutes.login;
  }
}

/// Backward-compatible alias used by Phase 2 scaffolding.
typedef SessionController = SessionService;
