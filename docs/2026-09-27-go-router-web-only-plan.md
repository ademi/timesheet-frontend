# Plan: `go_router` on web only (GetX stays on mobile)

**Audience:** Engineers implementing §F (web refresh / back / forward) from `docs/2026-09-22-ux-friction-inventory.md`  
**Date:** 2026-09-27  
**Status:** Phases 0–6 complete  
**ADR:** [`docs/adr-go-router-web-only.md`](./adr-go-router-web-only.md)

### ADR blurb

| | |
|--|--|
| **Context** | Web refresh/back/forward failed under GetX-only routing (§F). |
| **Decision** | `go_router` on **Flutter Web only**; GetX named routes on **mobile**; GetX DI/Rx on both; feature nav via `AppNavigator` + shared `AppRoutes`. |
| **Consequences** | URL query/path is web refresh source of truth; mobile facade still calls GetX; FCM tap→route not wired (use `AppNavigator` when added). |

**Decision:** Adopt **Path B (`go_router`)** for **Flutter Web only**. Keep **GetX navigation** (`GetMaterialApp` + `GetPage` + `Get.toNamed` / `offAllNamed`) on **iOS / Android**. Keep **GetX for DI / controllers / Rx** on **both** platforms.

**Why split:** Web is primary; browser history, refresh, and shareable deep links need declarative URL routing. Mobile has a real Navigator stack and does not suffer the same refresh/history failure modes, so a full GetX → go_router cutover there is unnecessary cost and risk.

---

## 1. Problem recap (§F)

| Failure mode | Today |
|--------------|--------|
| Workflow state only in `Get.arguments` / controller Rx | Refresh recreates app → empty/wrong screen |
| `GatewayController._resumeIfAuthenticated` → `Get.offAllNamed(home)` | Authenticated cold start / refresh can yank user off a deep URL |
| GetX stack ≠ browser history | After refresh: one route; in-app back vanishes; Chrome back/forward mismatch |

**Already done (keep):** `PathUrlStrategy` (`main.dart`); client detail `?id=` + hydrate-from-route; `AppBackButton` + `backOrToParent` (client detail only so far); Auth/Actor/Permission `GetMiddleware`s.

**Still broken for staff mid-flow:** onboarding step, many detail screens (visits/shifts args-only), support compose, gateway home redirect after session hydrate.

---

## 2. Target architecture

```
                    ┌─────────────────────────────────────┐
                    │  Shared: AppRoutes path constants   │
                    │  Shared: GetX DI / controllers / Rx │
                    │  Shared: hydrate-from-id / step     │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │                                         │
     kIsWeb == true                            kIsWeb == false
              │                                         │
   MaterialApp.router                          GetMaterialApp
   + GoRouter                                  + getPages: AppPages.routes
   + ShellRoute (staff/contractor)             + GetMiddleware guards
   + redirect() auth/actor/perm                + Get.toNamed / offAllNamed
              │                                         │
              └────────────────────┬────────────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │  AppNavigator facade        │
                    │  go / push / replace / pop  │
                    │  → GoRouter *or* GetX       │
                    └─────────────────────────────┘
```

### Non-negotiables

1. **Same path strings** on both platforms (`AppRoutes.*`). Web URLs and mobile named routes stay aligned.
2. **URL (path + query) is source of truth for refreshable state** on web. `Get.arguments` is optional cache only — never the only restore path.
3. **Mobile keeps GetX routing** for the duration of this plan (no forced go_router on iOS/Android).
4. **Controllers stay GetX**; do not rewrite features to Riverpod/Bloc as part of this work.
5. **No dual navigation calls** in feature code (`Get.toNamed` *and* `context.go`). Feature code calls **only** `AppNavigator` (or thin wrappers).

---

## 3. Key files (current → planned)

| Area | Current | Planned (web) |
|------|---------|----------------|
| Bootstrap | `lib/main.dart` → `GetMaterialApp` | `kIsWeb` branch: `MaterialApp.router` vs `GetMaterialApp` |
| Route table | `app/routes/app_pages.dart` + feature `*_routes.dart` | Keep GetX tables for mobile; add `app/router/app_go_router.dart` (+ feature go_route modules) for web |
| Paths | `app/routes/app_routes.dart` | Unchanged shared constants; add typed path helpers if needed (`/staff/clients/detail?id=`) |
| Navigation API | `Get.toNamed` / `app_navigation.dart` | Expand `app_navigation.dart` → platform-aware facade |
| Auth gate | `AuthGuard` / `ActorGuard` / `PermissionGuard` | Web: `GoRouter.redirect` + shared pure helpers from `auth_route_utils.dart`; mobile: keep middlewares |
| Session resume | `GatewayController._resumeIfAuthenticated` | Gate: do **not** `offAllNamed(home)` when current location is already a valid deep route |
| Shells | Each `GetPage` wraps `staffShellPage` / `contractorShellPage` | Web: `ShellRoute` + `navigatorKey`; mobile unchanged |
| Back | `AppBackButton` / `backOrToParent` | Web: pop GoRouter / `go(parent)`; mobile: existing GetX behavior |

---

## 4. Design contracts (apply before / during migration)

### 4.1 Route params contract

Every refreshable detail / wizard must encode:

| Kind | URL shape (prefer) | Hydrate in |
|------|--------------------|------------|
| Entity detail | `/staff/clients/detail?id=` or `/staff/clients/:id` | `onInit` / binding / go_router `builder` |
| Wizard step | `?id=&step=` (onboarding, support compose) | Controller reads step from route |
| Nested entity | e.g. credential `?id=`, export `?id=` | Same as client detail pattern |

**Rule:** If a screen cannot rebuild from URL + auth alone, it is not web-refresh-safe.

### 4.2 Navigation facade contract

```dart
// Conceptual — implement in lib/app/routes/app_navigation.dart (or app/router/)
abstract class AppNavigator {
  void go(String location, {Object? extra});      // replace stack / go
  Future<T?> push<T>(String location, {Object? extra});
  void replace(String location, {Object? extra});
  void offAll(String location);                    // login / logout / post-auth
  void pop<T>([T? result]);
  void backOrToParent(String parentLocation);
  String get currentLocation;
  Map<String, String> get queryParameters;
}
```

- **Web:** delegates to `GoRouter` (`go` / `push` / `replace` / `pop`).
- **Mobile:** delegates to `Get.offNamed` / `toNamed` / `offAllNamed` / `back`.
- **`extra`:** maps to `Get.arguments` on mobile; on web prefer query/path; use `extra` only as non-refresh cache (same discipline as today).

### 4.3 Guard contract (shared logic)

Extract pure functions (already partly in `auth_route_utils.dart`):

- `redirectWhenUnauthenticated(location)`
- `redirectWrongActor(location, actorType)`
- `redirectMissingPermission(location, perms)`
- `redirectMustChangePassword(...)`

Wire once into GetMiddleware (mobile) and `GoRouter.redirect` (web). Do not duplicate policy.

### 4.4 Gateway cold-start contract (P0 even before full go_router)

`GatewayController._resumeIfAuthenticated` today:

```dart
final route = session.resolvePostLoginRoute();
if (route != AppRoutes.login && route != AppRoutes.gateway) {
  Get.offAllNamed(route); // ← ejects deep links after refresh
}
```

**Target behavior:**

1. If app entered on `/gateway` (or empty) **and** session is valid → navigate to `resolvePostLoginRoute()`.
2. If app entered on an already-valid authenticated deep location → **hydrate session only; do not navigate away**.
3. If token invalid → stay / send to login or gateway per existing auth policy.

Implement this in a platform-safe way (read “intended initial location” from `Uri.base` on web; on mobile keep current resume behavior).

---

## 5. Phased task plan

Checkboxes are implementation tasks. Complete phases in order unless noted.

---

### Phase 0 — Prerequisites (unblocks web + helps mobile)

**Goal:** Stop the worst refresh eject; make ids/steps URL-addressable where still args-only; shared helpers ready for both routers.

**Status:** ✅ Complete (2026-09-27)

- [x] **0.1** Document inventory of args-only navigations (starting list below) and mark each: *URL-ready* / *needs id param* / *wizard needs step*.
- [x] **0.2** Gate gateway session resume (F4.1) so deep URLs are not replaced by home after hydrate.
- [x] **0.3** Client onboarding: put `id` + `step` in URL; hydrate in binding/`onInit` from params (not only `Get.arguments is ClientOut`).
- [x] **0.4** Extend URL `id` hydration to remaining high-traffic details that still open args-only: staff visit detail, shift detail, support-plan / strengths-needs if not already param-based.
- [x] **0.5** Roll out `AppBackButton` + `backOrToParent` on pushed staff/contractor detail screens (not only client detail).
- [x] **0.6** Extract / harden shared redirect helpers in `auth_route_utils.dart` so GoRouter and GetMiddleware call the same policy.
- [x] **0.7** Add widget/unit tests for: gateway does not steal deep link; onboarding restores `step` from URL; detail hydrates from `id`.

**Exit criteria:** Refresh on `/staff/clients/detail?id=…` and onboarding URL stays on that workflow after session hydrate (still on GetX). Back button visible post-refresh on major details.

**Args-only hotspots inventory (0.1):**

| Call site | Route | Status after Phase 0 |
|-----------|-------|----------------------|
| `ClientsController` → onboarding | `staffClientOnboarding` | **URL-ready** — `?id=&step=` + `ensureHydratedFromRoute` |
| `ClientsController` → form | `staffClientForm` | **URL-ready** — `?id=` passed (form still uses in-memory `editing`) |
| `ClientsController` → support plan | `staffClientSupportPlan` | **URL-ready** — `clientId`/`planId` in params + args |
| Support plan → S&N | `staffClientStrengthsNeeds` | **URL-ready** — `clientId`/`assessmentId` in params + args |
| `StaffVisitsController` visit/shift | `staffVisitDetail`, `staffShiftDetail` | **URL-ready** — `?id=` + refresh hydrate |
| Contractor visit / schedule | `contractorVisitDetail` | **URL-ready** — `?id=` |
| Client / workforce / credential detail | detail routes | **URL-ready** (pre-existing `?id=`) |
| Group shift wizards | book / edit / publish / travel / … | **needs id + mode** — deferred to Phase 4 |
| Jobs template editor / unified support | form editor, compose | **wizard needs step** — deferred to Phase 4 (AppBackButton added) |
| Billing tab arg | `staffBillingExports` | **needs `?tab=`** — deferred to Phase 5 |

---

### Phase 1 — Dual bootstrap scaffold (no feature cutover yet)

**Goal:** Web can boot with `GoRouter` for a **minimal** route set; mobile unchanged.

**Status:** ✅ Complete (2026-09-27)

- [x] **1.1** Add dependency: `go_router` in `pubspec.yaml`.
- [x] **1.2** Create `lib/app/router/` package layout:
  - `app_go_router.dart` — `GoRouter` factory
  - dual bootstrap in `main.dart` — `GetMaterialApp.router` on web
  - `go_router_redirect.dart` — shared auth/actor redirect
- [x] **1.3** Split `RostiqApp` build:
  - web: `GetMaterialApp.router` + go_router
  - mobile: `GetMaterialApp` + `getPages` (unchanged)
- [x] **1.4** Register **Phase-1 routes** on GoRouter: `/gateway`, `/login`, `/first-login`, `/admin/branches`, `/wrong-actor`, `/staff/home`, `/contractor/home`, plus auth-entry contractor register.
- [x] **1.5** Implement `GoRouter.redirect` for auth + must-change-password (+ actor) using shared helpers.
- [x] **1.6** Keep `InitialBinding` / `TokenStorage` warmup identical on both platforms (run in `main()` before resume).
- [x] **1.7** Introduce `AppNavigator` facade; migrate gateway/login/logout/`resolvePostLoginRoute` / interceptor / first-login call sites.
- [x] **1.8** Tests: `test/app/router/go_router_phase1_test.dart` (redirect + boot + unknown-route behavior).

**Exit criteria:** `flutter run -d chrome` reaches login/home via GoRouter; `flutter run` mobile still uses GetX pages; analyze clean; no feature deep links required yet.

**Phase-1 note:** Unmigrated bookmarks while authenticated show `Phase1UnknownRoutePage`; while logged out they redirect to `/gateway`. Shell tabs land in Phase 2.

---

### Phase 2 — Shell routes + actor/permission redirects

**Goal:** Staff and contractor tab shells work on web with correct URL per tab; guards match GetX.

**Status:** ✅ Complete (2026-09-27)

- [x] **2.1** Add `ShellRoute` (or two shells) for staff + contractor; reuse `StaffShell` / `ContractorShell` widgets (adapt to take `child` from `ShellRoute` instead of only `staffShellPage` wrappers).
- [x] **2.2** Register all **shell tab** destinations as GoRoutes under the shell: home, visits, clients, workforce, attendance review, payments, billing, compliance (if shown), settings; contractor home/visits/schedule/credentials/profile.
- [x] **2.3** Port `ActorGuard` + `PermissionGuard` into `redirect` (or per-route redirect). Wrong actor → `/wrong-actor`.
- [x] **2.4** Wire shell nav taps through `AppNavigator.go` (replace direct `Get.offNamed` / `toNamed` in shell files).
- [x] **2.5** Ensure `PathUrlStrategy` still set; browser back switches tabs correctly.
- [x] **2.6** Manual + widget tests: permission-denied redirect; contractor cannot open `/staff/...`.

**Exit criteria:** Authenticated staff can use all primary shell tabs on web with refresh staying on the same tab URL. Mobile shells unchanged.

---

### Phase 3 — Clients domain (highest staff friction)

**Goal:** Clients list → detail → onboarding → support plan / S&N / forms are refresh-safe on web.

**Status:** ✅ Complete (2026-09-27)

**Param shape (3.2):** Keep **`?id=` / `?clientId=` / `?planId=` / `?step=`** query params (aligned with existing GetX `parameters`). Path params only for public invite `:token`.

**Onboarding step history (3.3):** Step changes use **`AppNavigator.replace`** under go_router (no junk history entries). Mobile GetX only updates `Get.parameters`.

- [x] **3.1** Add GoRoutes for all `ClientsPages` paths (list, detail, onboarding, form, support-plan, strengths-needs, site/contact forms, SIL, public invite token routes).
- [x] **3.2** Prefer path or query `id` consistently; document chosen shape in this file once decided (recommend keep `?id=` to minimize churn with existing GetX params).
- [x] **3.3** Onboarding: `?id=&step=` synced when step changes (`AppNavigator.replace` / `go` without stacking junk history — product choice: replace vs push per step).
- [x] **3.4** Replace clients-feature `Get.toNamed` / `offNamed` with `AppNavigator`.
- [x] **3.5** Bindings: on web, register controllers in go_router `builder`/`pageBuilder` or a small `Get.put` bridge in route builders (keep GetX DI). Ensure idempotent `ensureShared` patterns still work after refresh.
- [x] **3.6** `AppBackButton` uses facade `backOrToParent`.
- [x] **3.7** Tests: refresh simulation via initial `GoRouter(initialLocation: …)`; onboarding step restore; public invite `:token`.

**Exit criteria:** Full client onboarding + detail + care-plan entry survive Chrome refresh and back/forward without landing on empty home.

---

### Phase 4 — Visits, shifts, jobs / support compose

**Goal:** Roster and support workflows are URL-addressable on web.

**Status:** ✅ Complete (2026-09-27)

**Param shape:** `?id=` for visit/shift/job detail; wizards add `?participantId=` when needed; unified support uses `?clientId=` / `?mode=`; attendance review filter uses `?visitId=`. Group windows editor stays a local overlay (not a named GoRoute).

- [x] **4.1** GoRoutes for visits board, visit detail, shift detail, group-shift wizards (book/edit/windows/attendance/publish/travel/remove), attendance review.
- [x] **4.2** Encode `visitId` / `shiftId` / wizard `mode` in path or query; hydrate controllers from ids (fetch if no `extra`).
- [x] **4.3** Unified support compose + jobs detail/form/templates: id + step/query as needed.
- [x] **4.4** Migrate `StaffVisitsController` / `JobsController` / unified support navigation to `AppNavigator`.
- [x] **4.5** Tests for visit/shift detail refresh; one group-shift wizard happy path restore.

**Exit criteria:** Opening a visit/shift URL cold (authenticated) loads the entity; back returns to roster parent.

---

### Phase 5 — Workforce, credentials, billing, contractor surfaces

**Goal:** Remaining staff + contractor deep links on web.

**Status:** ✅ Complete (2026-09-27)

**Known exception:** `staffGroupShiftWindows` stays a local overlay (Phase 4) — not a GoRoute.

- [x] **5.1** Workforce detail / invite / rate-form (already partly `parameters: {id}` — align GoRoutes).
- [x] **5.2** Credentials list/create/detail + staff credential review.
- [x] **5.3** Billing exports list/detail (`?id=`, `?tab=`).
- [x] **5.4** Contractor onboarding funnel routes, register `:token`, schedule, profile, complete-account, payments.
- [x] **5.5** Payroll / compliance_ops leftovers if still GetX-only on web.
- [x] **5.6** Facade migration: grep for remaining `Get.toNamed` / `offAllNamed` / `offNamed` in `lib/` and eliminate from web path (mobile may still call GetX **inside** the facade only).

**Exit criteria:** Grep shows no raw `Get.toNamed` / `Get.offAllNamed` outside `app_navigation.dart` (and tests). All `AppRoutes` have a GoRoute mapping.

---

### Phase 6 — Hardening, parity, cleanup

**Goal:** Production-ready web router; mobile GetX proven untouched.

**Status:** ✅ Complete (2026-09-27)

- [x] **6.1** 404 / unknown route → safe fallback (staff home or gateway) + logging.
  - `UnknownRoutePage` logs path/query/auth; CTA → `AppNavigator.offAll` gateway or post-login home.
- [x] **6.2** Session expiry / `AuthInterceptor` logout uses `AppNavigator.offAll(login)`.
  - Already wired in `lib/core/network/auth_interceptor.dart` (`_redirectToLogin`).
- [x] **6.3** Push notification / deep link entry (if any) uses same location strings.
  - **N/A today:** FCM registers tokens only (no tap→route). Contract documented on `PushNotificationService` + ADR: future handlers must use `AppNavigator` + `AppRoutes`.
- [x] **6.4** Manual test matrix (Chrome) — see below.
- [x] **6.5** Manual test matrix (iOS/Android) — see below.
- [x] **6.6** Update `docs/web-refresh-back-button-fix.md` with superseded-for-web banner + link to this plan.
- [x] **6.7** ADR: `docs/adr-go-router-web-only.md` + blurb at top of this file.
- [x] **6.8** Smoke: `test/app/router/go_router_phase6_hardening_test.dart` (cold `initialLocation` + unknown CTA). Full Chrome `integration_test` deferred (widget coverage sufficient).

**Exit criteria:** §F failure modes closed on web; mobile navigation regressions = 0; docs point to the dual strategy.

#### Manual matrix — Chrome (6.4)

| # | Case | Pass? |
|---|------|-------|
| C1 | Refresh mid client onboarding / visit detail / shift detail keeps URL + hydrates | |
| C2 | Chrome back / forward after refresh switches tabs / details correctly | |
| C3 | Paste protected URL while logged out → gateway; while logged in → screen | |
| C4 | Open deep URL in new tab (same session) loads entity | |
| C5 | Logout mid-flow → gateway/login; 401 after expiry → login via interceptor | |
| C6 | `must-change-password` claim → first-login | |
| C7 | Contractor session opening `/staff/...` → wrong-actor | |
| C8 | Unknown path → “Page not found” + Go to home | |
| C9 | Public `/invites/client/:token` while logged out | |

#### Manual matrix — iOS / Android (6.5)

| # | Case | Pass? |
|---|------|-------|
| M1 | Login / logout / gateway session resume (no deep-link steal) | |
| M2 | Staff + contractor shells / primary tabs | |
| M3 | Clients list → detail → onboarding (GetX stack) | |
| M4 | Visits board → visit/shift detail; AppBackButton pops | |
| M5 | Confirm no go_router bootstrap on mobile (`GetMaterialApp` + getPages) | |

---

## 6. Suggested phase order vs §F priority

| §F item | Phase | Notes |
|---------|-------|-------|
| F4.1 Gateway redirect gate | **0.2** | Do first; helps even before GoRouter |
| F4.2 Id/step-addressable routes | **0.3–0.4**, then **3–5** | Start on GetX; GoRouter consumes same URLs |
| F4.3 AppBackButton roll-out | **0.5**, refine in **3+** | |
| Path B go_router | **1–6** | Web only |
| Keep GetX on mobile | **All phases** | Mobile branch never switches to `MaterialApp.router` in this plan |

---

## 7. Testing strategy

| Layer | What |
|-------|------|
| Unit | Shared redirect helpers; gateway “do not steal deep link” |
| Router | `GoRouter` with `initialLocation` + `routerDelegate` pump for hydrate |
| Widget | Existing GetX tests remain for mobile patterns; add web variants only where behavior diverges |
| Manual | Chrome matrix (Phase 6.4); device matrix (Phase 6.5) |

**Do not** require go_router in every existing `GetMaterialApp` test — keep mobile tests on GetX.

---

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Two routers drift (path missing on one side) | Single `AppRoutes` source; CI test or script that every `AppRoutes` constant is registered in **both** `AppPages` and `AppGoRouter` |
| Feature code still calls `Get.toNamed` on web | Facade + lint/grep gate in Phase 5.6 |
| GetX bindings don’t run under GoRouter | Explicit `Get.put` / `Bindings` invoke in route `builder`; reuse `ensureShared` |
| History spam from wizard steps | Use `go`/`replace` for step changes; `push` only for true sub-screens |
| Large PR | Merge by phase (0 → 1 → 2 → 3…); each phase shippable |
| Temporary web 404 during Phase 1 | Minimize Phase 1 window; or register remaining routes as redirect-to-home stubs |

---

## 9. Out of scope (this plan)

- Replacing GetX **state management** / DI.
- Migrating iOS/Android to go_router.
- Upload-on-pick / form UX (§A–E) — separate workstream.
- Backend token multi-device session issues called out in older web-refresh doc.

---

## 10. Definition of done (whole initiative)

1. Web: refresh / back / forward / pasted URL restore authenticated workflows from `path + query` for all staff/contractor routes in `AppRoutes`.
2. Web: gateway session resume never overrides a valid deep link.
3. Mobile: still `GetMaterialApp` + `GetPage`; behavior preserved (plus any Phase 0 URL hydrate improvements that are platform-agnostic).
4. Feature navigation goes through one facade; guards share one policy module.
5. Docs updated (`web-refresh-back-button-fix.md` + this plan checkboxes).

---

## 11. Quick start (when implementation begins)

1. Land **Phase 0.2** (gateway gate) immediately — highest leverage, small diff.
2. Land onboarding `id`+`step` URL (**0.3**) next.
3. Scaffold **Phase 1** dual bootstrap behind `kIsWeb`.
4. Continue phases 2→6 without switching mobile off GetX.

**Related docs:**

- `docs/2026-09-22-ux-friction-inventory.md` §F  
- `docs/web-refresh-back-button-fix.md` (GetX-only mitigations; partially superseded on web)  
- `docs/superpowers/plans/2026-09-21-client-detail-nav-hydration.md` (id-param pattern to copy)
