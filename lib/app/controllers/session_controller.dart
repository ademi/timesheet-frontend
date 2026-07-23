import 'package:get/get.dart';

import '../../core/auth/jwt_claims.dart';
import '../../core/constants/feature_flags.dart';
import '../../core/services/token_storage.dart';
import '../data/models/auth/auth_token_model.dart';
import '../data/models/auth/engagement_summary_model.dart';
import '../data/models/auth/me_context_model.dart';
import '../data/repositories/auth_repository.dart';
import '../routes/app_routes.dart';

/// Permanent session state for DOMAIN_V2 actor / engagements / tenant context.
class SessionController extends GetxController {
  SessionController({
    required TokenStorage tokenStorage,
    required AuthRepository authRepository,
  })  : _tokenStorage = tokenStorage,
        _authRepository = authRepository;

  final TokenStorage _tokenStorage;
  final AuthRepository _authRepository;

  final actorType = RxnString();
  final engagements = <EngagementSummaryModel>[].obs;
  final selectedTenantId = RxnString();
  final selectedEngagementId = RxnString();
  final mustChangePassword = false.obs;

  JwtClaims? get claims => _tokenStorage.jwtClaims;

  bool get isTenantMember => claims?.isTenantMember ?? actorType.value == 'tenant_member';
  bool get isContractor => claims?.isContractor ?? actorType.value == 'contractor';

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

  /// Apply login / refresh / switch-tenant body into session + storage.
  Future<void> applyAuthTokens(AuthTokenModel tokens) async {
    actorType.value = tokens.actorType ?? claims?.actorType;
    engagements.assignAll(tokens.engagements);
    mustChangePassword.value =
        tokens.mustChangePassword || (claims?.mustChangePassword ?? false);

    final tenantFromJwt = claims?.tenantId;
    if (tenantFromJwt != null) {
      selectedTenantId.value = tenantFromJwt;
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
    try {
      final ctx = await _authRepository.getMeContext();
      applyMeContext(ctx);
    } catch (_) {
      // Keep JWT-derived session if context fails.
      actorType.value ??= claims?.actorType;
      selectedTenantId.value ??= claims?.tenantId;
    }
  }

  void applyMeContext(MeContextModel ctx) {
    actorType.value = ctx.actorType;
    engagements.assignAll(ctx.engagements);
    selectedTenantId.value = ctx.tenantId ?? selectedTenantId.value;
    if (ctx.tenantId != null) {
      for (final e in ctx.engagements) {
        if (e.tenantId == ctx.tenantId) {
          selectedEngagementId.value = e.id;
          break;
        }
      }
    }
  }

  Future<AuthTokenModel> switchTenant(String tenantId) async {
    final tokens = await _authRepository.switchTenant(tenantId);
    await applyAuthTokens(tokens);
    return tokens;
  }

  Future<void> clear() async {
    actorType.value = null;
    engagements.clear();
    selectedTenantId.value = null;
    selectedEngagementId.value = null;
    mustChangePassword.value = false;
  }

  /// Post-login / restore landing route for DOMAIN_V2.
  String resolvePostLoginRoute() {
    if (mustChangePassword.value || (claims?.mustChangePassword ?? false)) {
      return AppRoutes.firstLogin;
    }
    if (isTenantMember) {
      return AppRoutes.adminHub;
    }
    if (isContractor) {
      if (engagements.length > 1 &&
          selectedTenantId.value == null &&
          _tokenStorage.lastTenantId == null) {
        return AppRoutes.contractorSwitchTenant;
      }
      if (engagements.length > 1 && claims?.tenantId == null) {
        return AppRoutes.contractorSwitchTenant;
      }
      final status = selectedEngagementStatus;
      if (status == 'invited') {
        return AppRoutes.contractorEngagementAccept;
      }
      if (status == 'pending_docs' || status == 'approved') {
        return AppRoutes.contractorDocuments;
      }
      return AppRoutes.contractorVisits;
    }
    return AppRoutes.login;
  }
}
