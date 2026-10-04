import 'package:get/get.dart';

/// GetX registration helpers for GoRouter (`onEnter` → Binding).
///
/// GoRouter does not run GetX SmartManagement route disposal. Controllers
/// registered with `if (!Get.isRegistered) Get.put(...)` survive leave/re-enter
/// and show stale UI. Use the tier policy below (see
/// `docs/2026-10-04-getx-controller-lifecycle-gorouter.md`):
///
/// * **Tier 1 — global:** `permanent: true` (Auth, Session, Gateway, sync).
/// * **Tier 2 — shell tabs:** [putOrReenter] (keep instance; optional refresh).
/// * **Tier 3 — detail/wizard:** [putFresh] (delete then put on every enter).
///
/// Prefer [putFresh] for entity screens. For wizards that sync query params via
/// `AppNavigator.replace` while staying on the same route (e.g. client
/// onboarding step), prefer **onExit delete + put-if-missing** so mid-flow
/// URL updates do not wipe state.
T putFresh<T extends GetxController>(T Function() create) {
  if (Get.isRegistered<T>()) {
    Get.delete<T>(force: true);
  }
  return Get.put(create());
}

/// Tier-2 helper: reuse the existing controller and optionally refresh it.
T putOrReenter<T extends GetxController>(
  T Function() create, {
  void Function(T controller)? onReenter,
}) {
  if (Get.isRegistered<T>()) {
    final existing = Get.find<T>();
    onReenter?.call(existing);
    return existing;
  }
  return Get.put(create());
}
