# DOMAIN_V2 feature flag

Compile-time switch for the contractor-era dual-shell app.

| Define | Default | Effect |
|--------|---------|--------|
| `DOMAIN_V2=true` | **true** | Actor-based login routing, V2 shells, cutover wipe once, skip portal gateway |
| `DOMAIN_V2=false` | — | Legacy attendance/admin gateway + branch flow |

## Examples

```bash
# Local API (Phase 2+)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=DOMAIN_V2=true

# Legacy portal (pre-cutover binary only)
flutter run --dart-define=DOMAIN_V2=false
```

## Cutover wipe

On first launch with `DOMAIN_V2=true`, [DomainV2Cutover] clears secure tokens, `user_role`, and GetStorage `payroll_settings`, then shows “App updated — please sign in again.”

## Related

- [phase2-readiness.md](./phase1/phase2-readiness.md)
- [frontend-api-wiring-guide.md](./frontend-api-wiring-guide.md)
- `lib/core/constants/feature_flags.dart`
