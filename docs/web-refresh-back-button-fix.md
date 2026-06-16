# Web Refresh & Back-Button Fix (GetX-only)

Fixes two Flutter Web (Chrome) problems while staying **100% on GetX** — no
`go_router`, `auto_route`, or other navigation packages were introduced.

## Problems

1. **In-app back button disappears after a browser refresh.** On web, refreshing
   resets GetX's in-memory navigation stack to a single route. The default
   `AppBar` back arrow only renders when `Navigator.canPop()` is `true`, so after a
   refresh `canPop()` is `false` and the arrow vanishes.
2. **Chrome's back button misbehaves after refresh.** The first click did nothing
   and the second jumped to logout/login. The browser history stack and GetX's
   reset in-memory stack were out of sync, and (with hash URLs) the framework
   could not reconcile them, so back eventually popped "below" the app to the
   initial route (`/gateway`).

> The separate backend token issue (mobile login invalidating the web session) is
> intentionally **out of scope**.

## Root causes found

- **No URL strategy** was set, so web used the default **hash** strategy
  (`/#/...`), which makes browser history hard to reconcile with GetX.
- Views relied on the **implicit** `AppBar` leading, which is `canPop()`-gated.
- **No route guard** existed; a refresh on a deep route could resolve before auth
  was reconsidered, contributing to the logout bounce.
- Auth state actually lives in **`TokenStorage`** (backed by
  `flutter_secure_storage`), not `GetStorage`. `GetStorage` is only used for
  payroll settings. The guard therefore reads `TokenStorage` via GetX DI.
- Deep screens (e.g. employee detail, period detail) carry state via in-memory
  `Get.arguments`, which **does not survive a refresh**; their old fallback was a
  no-op `Get.back()`.

## Changes

### A. Clean web URLs — `PathUrlStrategy` (web-only)
`lib/main.dart` sets the path URL strategy before `runApp`, guarded by `kIsWeb`:

```dart
if (kIsWeb) {
  setUrlStrategy(PathUrlStrategy());
}
```

- **Why:** Clean path URLs let the browser history and GetX routing reconcile
  predictably across refresh and back/forward. This is the foundation that makes
  B and C behave consistently.
- `flutter_web_plugins` (an SDK package) was added to `pubspec.yaml` so the import
  resolves. **No third-party package** was added.
- **Mobile:** guarded by `kIsWeb` (URL strategy is meaningless on mobile).

### B. Refresh-aware back button — `AppBackButton`
New widget `lib/app/views/widgets/app_back_button.dart`, used as `AppBar.leading`
on deep screens. It is **always rendered** and delegates to the shared helper
`backOrToParent` (see D):

- pops normally when a route exists (`Get.back()`), or
- navigates to a logical parent `fallbackRoute` when the stack is empty
  (post-refresh).

- **Why:** Because it does not depend on `canPop()`, the button never disappears
  after refresh; it pops when it can and otherwise lands the user on a sensible
  parent. This directly fixes **Problem 1**.
- **Mobile:** no `kIsWeb` needed — `canPop()` is `true` on mobile, so it behaves
  exactly like the previous implicit back arrow.

Applied to the deep (pushed) screens, each with a logical parent fallback:

| Screen | Fallback parent |
| --- | --- |
| Employees | Admin Panel |
| Employee Detail | Employees |
| Create Employee | Employees |
| Attendance Report | Admin Panel |
| Attendance Corrections | Admin Panel |
| Attendance Adjustment | Attendance Corrections |
| Employee Picker | Admin Panel |
| Payments | Admin Panel |
| Create Payment | Payments |
| Payments Report | Payments |
| Employee Payment History | Payments |
| Payroll | Admin Panel |
| Payroll Periods | Payroll |
| Payroll Settings | Payroll |
| Period Detail | Payroll Periods |
| Period Results | Payroll Periods |
| Payroll Result Detail | Period Results |
| Employee Rates | Payroll |
| Employee Rate Form | Employee Rates |
| Employee Balance | Payroll |
| Payroll Summary | Payroll |

> Root/entry screens that intentionally have no back action (Gateway, Login,
> First-Login, Branch Gateway, Admin Panel, Home/Attendance, Employee Created)
> were left unchanged.

### C. Route guarding — `AuthGuard` (`GetMiddleware`)
New middleware `lib/app/routes/middlewares/auth_guard.dart`, attached to every
protected `GetPage` in `lib/app/routes/app_pages.dart`:

```dart
class AuthGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final hasToken = Get.isRegistered<TokenStorage>() &&
        (Get.find<TokenStorage>().accessToken?.isNotEmpty ?? false);
    if (hasToken) return null;                       // authenticated → allow
    return const RouteSettings(name: AppRoutes.gateway); // else → gateway
  }
}
```

- **Why:** GetX runs middleware on **every** route resolution, including the one
  rebuilt from the URL on refresh. Re-evaluating auth from the live source of
  truth (`TokenStorage`) means a refresh on a protected route deterministically
  resolves to a valid screen for authenticated users instead of being dragged
  toward logout/login by the history/stack mismatch. Combined with A, this fixes
  **Problem 2**.
- Applied to all protected routes; left **off** `gateway`, `login`, and
  `firstLogin`.
- **Mobile:** no `kIsWeb` needed — same auth source, authenticated users pass
  unchanged; only a genuinely missing token redirects (desired on both
  platforms).

### C.1 Session dependencies available on every entry — `InitialBinding`
`lib/main.dart` now sets `GetMaterialApp.initialBinding: InitialBinding()`
(`lib/app/bindings/initial_binding.dart`), which registers the auth/API graph
(via `AuthBinding`) **and** `GatewayController`.

- **The bug:** On web a refresh rebuilds the app from the URL alone, so only the
  current route's binding (plus the initial binding) runs. Controllers that are
  normally registered by a *different* route's binding were then missing:
  - `AuthController` (registered by `AuthBinding` on `/login`) — used by
    `AdminPanelView` / `AttendanceView` → *"AuthController not found"*.
  - `GatewayController` (registered by `GatewayBinding` on `/gateway`) — used by
    `LoginView` and `BranchGatewayController` (to decide admin vs attendance after
    selecting a branch) → *"GatewayController not found"* when changing branch
    after a refresh.
- **Fix:** `InitialBinding` runs at startup on every entry (including refresh), so
  both session controllers always exist. All registrations are **idempotent**
  (`isRegistered` guards) and reuse the `TokenStorage` warmed in `main()`; they
  only construct objects (no network), so they are safe to run eagerly.
- **Mobile:** unaffected — same dependencies, just created at startup instead of
  on first visit to gateway/login.

> Module graphs (payroll, payments, employees, attendance) were already safe on
> refresh: each page binding calls its module's idempotent `ensureDependencies()`,
> and the shared `ApiClient`/`AuthRepository` are now registered app-wide by
> `InitialBinding`. The remaining gap was only the two session controllers above.

### C.2 Persist the selected portal role (refresh-correct branch switching)
The chosen portal (`UserRole.admin` / `attendance`) lived only in
`GatewayController.selectedRole` (in-memory), so a refresh lost it and
"change branch" could route an admin to the attendance screen.

- `TokenStorage` now persists the role (`persistRole` / `role`, cleared on
  `clear()`), alongside the existing branch selection.
- `GatewayController.selectRole` persists the role; `GatewayController.onInit`
  restores it from `TokenStorage`, so after a refresh the role is correct.
- **Why:** This makes the post-refresh "change branch" flow choose the right
  destination, and pairs with C.1 so the controller is both present and correct.

### D. Minimal, stack-aware fallback helper — `backOrToParent`
Added to `lib/app/routes/app_navigation.dart`:

```dart
void backOrToParent(String parentRoute) {
  if (Get.key.currentState?.canPop() ?? false) {
    Get.back();
  } else {
    Get.offNamed(parentRoute);
  }
}
```

Used by `AppBackButton` (B) and by the **arg-guards** of the two deepest
object-argument screens, replacing their old no-op `Get.back()`:

- `EmployeeDetailController.onInit` → `backOrToParent(AppRoutes.adminEmployees)`
- `PayrollPeriodDetailController.onInit` → `backOrToParent(AppRoutes.payrollPeriods)`

- **Why:** These screens receive their state via in-memory `Get.arguments`, which
  is lost on refresh. Previously they called `Get.back()`, which is a no-op when
  the stack is empty, leaving the user stranded on a broken screen. Now they seed
  the logical parent so the user lands somewhere valid with a working back button.
- **Mobile-safe by construction:** the helper only diverges from `Get.back()` when
  `canPop()` is `false`, which does not happen for pushed screens on mobile — so
  no `kIsWeb` guard is required.
- **Used sparingly**, as recommended. A full "rebuild the deep stack" approach was
  intentionally avoided because object arguments cannot be reconstructed from the
  URL; it would only be appropriate for routes whose state is fully URL-derivable.

## Files changed

- `lib/main.dart` — `kIsWeb` + `setUrlStrategy(PathUrlStrategy())`; plus
  `initialBinding: InitialBinding()` so session deps exist on every entry/refresh.
- `lib/app/bindings/initial_binding.dart` — **new** initial binding (auth graph +
  `GatewayController`).
- `lib/core/services/token_storage.dart` — persist/restore the selected role.
- `lib/app/controllers/gateway_controller.dart` — persist role on select, restore
  on init.
- `pubspec.yaml` — declare SDK package `flutter_web_plugins`.
- `lib/app/views/widgets/app_back_button.dart` — **new** reusable back button.
- `lib/app/routes/middlewares/auth_guard.dart` — **new** auth middleware.
- `lib/app/routes/app_navigation.dart` — **new** `backOrToParent` helper.
- `lib/app/routes/app_pages.dart` — `AuthGuard` on all protected pages.
- 21 deep `*_view.dart` files — `AppBar(leading: AppBackButton(...))`.
- `lib/app/controllers/employee_detail_controller.dart`,
  `lib/app/controllers/payroll_period_detail_controller.dart` — use
  `backOrToParent` in the arg-guard.

## Manual test steps

### 1. Refresh on a deep screen keeps the back button visible and working (Problem 1)
1. `flutter run -d chrome`.
2. Log in → Admin Panel → Payroll → Periods → open a period (Period Detail).
3. Press Chrome **reload**.
4. **Expect:** the in-app back arrow is **still visible**. Clicking it returns to
   Payroll Periods (the logical parent). Repeat for Employee Detail and a couple
   of other deep screens.

### 2. Chrome back button no longer needs two clicks / no logout jump (Problem 2)
1. Navigate Admin Panel → Payroll → Periods.
2. Reload the page on Periods.
3. Click Chrome's **back** button once.
4. **Expect:** a single click moves back as expected (not a dead first click), and
   you are **not** thrown to logout/login. URLs are clean paths (no `#`).

### 3. Auth redirect still works after refresh on protected routes
1. While logged in, reload on any protected deep route → **stays** on a valid
   screen.
2. Log out (or clear storage) and paste a protected URL, then reload → **redirected
   to Gateway**.

### 4. Mobile navigation is unaffected
1. `flutter run` on Android/iOS.
2. Exercise the same flows: push deep screens, use the in-app back button, log in
   and log out.
3. **Expect:** identical behavior to before — back pops normally, no extra/duplicate
   routes, auth flow unchanged. (`PathUrlStrategy` and the D reseed are no-ops on
   mobile.)

## Notes / verification
- `flutter analyze lib` passes; the only remaining infos are **pre-existing**
  `Share`/`shareXFiles` deprecations in `payroll_period_detail_controller.dart`,
  unrelated to this change.
- Existing route names, bindings, and `arguments` passing were preserved.
