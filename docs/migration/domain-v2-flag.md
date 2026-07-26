# Compile-time defines (Flutter contractor domain)

| Define | Default / notes | Purpose |
|--------|-----------------|---------|
| `API_BASE_URL` | `https://api.rostiq.co` (local: `http://localhost:8000`) | API origin |
| `BILLING_URL` | **Required** for subscription CTA | Landing GoCardless / billing page |
| `LANDING_URL` | Optional | Gateway “Provider signup” external link |
| `TERMS_VERSION` | Must match DB `platform_terms` current | Public contractor register (until public legal-read exists) |
| `PRIVACY_VERSION` | Must match DB `privacy_policy` current | Same |
| `DOMAIN_V2` | Prefer `true`; end-state V2-only | Transition flag while deleting legacy portal |

## Examples

```bash
flutter run -d chrome \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=BILLING_URL=https://rostiq.co/billing \
  --dart-define=LANDING_URL=https://rostiq.co/signup \
  --dart-define=TERMS_VERSION=2026-07-01 \
  --dart-define=PRIVACY_VERSION=2026-07-01 \
  --dart-define=DOMAIN_V2=true
```

## Cutover wipe

On first DOMAIN_V2 / upgrade launch: clear secure tokens, legacy `user_role`, GetStorage `payroll_settings`; show “App updated — please sign in again.”

## Related

- [2026-07-23-frontend-contractor-domain-restructure-design.md](./2026-07-23-frontend-contractor-domain-restructure-design.md) §3.2, §15
- [design-delta-2026-07-26.md](./design-delta-2026-07-26.md)
- `lib/core/constants/feature_flags.dart` (extend for billing/terms defines in S0)
