# Single ApiClient plan (S0)

**Rule:** One Dio stack — `ApiClient` in `lib/core/network/api_client.dart`.

| Client | Status |
|--------|--------|
| `ApiClient` | **Canonical** — all new datasources / repositories |
| `AttendanceApiClient` | **Legacy only** — no new call sites; delete when attendance/employee slices are removed |

Bindings must not `Get.put(ApiClient)` per feature when already registered in `AuthBinding` / `InitialBinding`.
