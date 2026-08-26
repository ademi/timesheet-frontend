import 'package:get/get.dart';

import '../../app/data/models/auth/auth_token_model.dart';
import '../../app/data/models/auth/engagement_summary_model.dart';
import '../../app/data/models/auth/me_context_model.dart';
import '../../app/data/repositories/auth_repository.dart';
import '../../app/routes/app_routes.dart';
import '../../features/contractor_onboarding/data/onboarding_progress_store.dart';
import '../../features/contractor_onboarding/onboarding_routing.dart';
import '../../features/billing/data/repositories/ndis_catalogue_repository.dart';
import '../../app/constants/app_permissions.dart';
import '../auth/jwt_claims.dart';
import 'token_storage.dart';

void _clearNdisCatalogueCacheIfRegistered() {
  if (Get.isRegistered<NdisCatalogueRepository>()) {
    Get.find<NdisCatalogueRepository>().clearCache();
  }
}

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
  final tenantTimezone = RxnString();
  final mustChangePassword = false.obs;
  final isHydrating = false.obs;
  final needsOnboarding = false.obs;
  final needsPlatformCompliance = false.obs;
  final needsEngagementWork = false.obs;
  Future<void>? _hydratingMeContext;
  int _meContextGeneration = 0;

  /// Tracks whether the backend confirmed that this contractor has already
  /// accepted all required platform compliance documents. Set by
  /// [applyMeContext] and used by [_recomputeOnboarding] to avoid forcing
  /// a self-registered contractor through the legal/terms funnel again.
  bool _backendConfirmedPlatformCompliance = false;

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

  /// True when at least one engagement still needs contractor accept.
  bool get needsInviteAccept => engagements.any((e) => e.status == 'invited');

  /// True when at least one engagement needs contractor documents.
  bool get needsDocsAttention =>
      engagements.any((e) => e.status == 'pending_docs');

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

  /// List/get invoice exports and download CSV (`billing.view`).
  bool get canViewBilling =>
      hasPermission(AppPermissions.billingView) ||
      hasPermission(AppPermissions.billingManage);

  /// Create and void NDIS invoice exports (`billing.manage`).
  bool get canManageBilling => hasPermission(AppPermissions.billingManage);

  /// NDIS catalogue typeahead (`jobs.manage` or `billing.view` on backend).
  bool get canSearchNdisCatalogue =>
      hasPermission(AppPermissions.jobsManage) ||
      hasPermission(AppPermissions.billingView) ||
      hasPermission(AppPermissions.billingManage);

  /// Apply login / refresh / switch-tenant body into session + storage.
  Future<void> applyAuthTokens(AuthTokenModel tokens) async {
    // A response started under the previous tenant must neither be shared with
    // nor overwrite the context refresh that follows this token change.
    _meContextGeneration++;
    _hydratingMeContext = null;
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
    tenantTimezone.value = null;
    _recomputeOnboarding();

    if (tenantFromJwt != null) {
      await _tokenStorage.persistLastTenantSelection(
        tenantId: tenantFromJwt,
        engagementId: match?.id,
      );
    }
  }

  Future<void> hydrateFromMeContext() async {
    if (_tokenStorage.accessToken == null) return;
    final inFlight = _hydratingMeContext;
    if (inFlight != null) return inFlight;

    final request = _hydrateMeContext(_meContextGeneration);
    _hydratingMeContext = request;
    try {
      await request;
    } finally {
      if (identical(_hydratingMeContext, request)) {
        _hydratingMeContext = null;
      }
    }
  }

  Future<void> _hydrateMeContext(int generation) async {
    isHydrating.value = true;
    try {
      final ctx = await _authRepository.getMeContext();
      if (generation == _meContextGeneration) {
        applyMeContext(ctx);
      }
    } catch (_) {
      if (generation != _meContextGeneration) return;
      actorType.value ??= claims?.actorType;
      selectedTenantId.value ??= claims?.tenantId;
      tenantId.value ??= claims?.tenantId;
      contractorId.value ??= claims?.contractorId;
      tenantMemberId.value ??= claims?.tenantMemberId;
      _recomputeOnboarding();
    } finally {
      if (generation == _meContextGeneration) {
        isHydrating.value = false;
      }
    }
  }

  void applyMeContext(MeContextModel ctx) {
    actorType.value = ctx.actorType;
    engagements.assignAll(ctx.engagements);
    tenantId.value = ctx.tenantId;
    contractorId.value = ctx.contractorId;
    tenantMemberId.value = ctx.tenantMemberId;
    selectedTenantId.value = ctx.tenantId ?? selectedTenantId.value;
    final tz = ctx.timezone?.trim();
    tenantTimezone.value = (tz == null || tz.isEmpty) ? null : tz;
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
    _backendConfirmedPlatformCompliance = ctx.platformComplianceAccepted;
    _recomputeOnboarding();
  }

  /// Engagement statuses that mean the contractor already passed platform
  /// onboarding (legal/notices/consents) and should not be forced through it
  /// again when local GetStorage progress is missing.
  static const _platformOnboardingSatisfiedStatuses = {
    'pending_docs',
    'approved',
    'active',
  };

  /// True when at least one engagement proves platform onboarding is done.
  bool get hasPostInviteEngagement => engagements.any(
        (e) => _platformOnboardingSatisfiedStatuses.contains(e.status),
      );

  void _recomputeOnboarding() {
    if (!isContractor) {
      needsOnboarding.value = false;
      needsPlatformCompliance.value = false;
      needsEngagementWork.value = false;
      return;
    }
    final id = contractorId.value;
    final localComplete = _onboardingProgressStore.isPlatformComplete(id);
    final progressed = hasPostInviteEngagement;
    // Backend confirms the contractor already accepted platform docs during
    // registration or a previous onboarding session.
    final backendConfirmed = _backendConfirmedPlatformCompliance;

    final alreadyCompliant = localComplete || progressed || backendConfirmed;
    if (!localComplete && alreadyCompliant && id != null && id.isNotEmpty) {
      // Persist so later logins on this device skip the funnel without
      // needing the backend check again.
      _onboardingProgressStore.markPlatformComplete(id);
    }
    needsPlatformCompliance.value = !alreadyCompliant;
    needsEngagementWork.value = engagements.any((e) => e.status == 'invited');
    needsOnboarding.value =
        needsPlatformCompliance.value || needsEngagementWork.value;
  }

  void refreshOnboardingFlags() => _recomputeOnboarding();

  Future<AuthTokenModel> switchTenant(String nextTenantId) async {
    final tokens = await _authRepository.switchTenant(nextTenantId);
    // Invalidate any in-flight me/context from the previous tenant so hydrate
    // after switch cannot reuse a stale single-flight future.
    _meContextGeneration += 1;
    _hydratingMeContext = null;
    _clearNdisCatalogueCacheIfRegistered();
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
    tenantTimezone.value = null;
    mustChangePassword.value = false;
    needsOnboarding.value = false;
    needsPlatformCompliance.value = false;
    needsEngagementWork.value = false;
    _backendConfirmedPlatformCompliance = false;
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
      if (needsOnboarding.value) {
        return OnboardingRouting.entryRoute(
          needsPlatformCompliance: needsPlatformCompliance.value,
          needsInviteAccept: needsInviteAccept,
        );
      }
      if (engagements.length > 1 && claims?.tenantId == null) {
        return AppRoutes.contractorProfile;
      }
      return AppRoutes.contractorHome;
    }
    return AppRoutes.login;
  }
}

/// Backward-compatible alias used by Phase 2 scaffolding.
typedef SessionController = SessionService;
