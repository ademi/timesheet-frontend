# Certificate Pinning — Implementation Guide (N-06 / F-fe-001)

## Summary

Production API traffic on **Android and iOS** is protected with SPKI (Subject Public Key Info) SHA-256 pinning via the `http_security_pinning` package. Pins live in `CertPins`; wiring is centralized in `configureApiClientNetworking`, which applies pinning to **both** `plainDio` (login/refresh) and `dio` (authenticated calls).

| Component | Path |
|-----------|------|
| Pin constants | `lib/core/network/cert_pins.dart` |
| Platform gate + adapter | `lib/core/network/cert_pinning_io.dart` (stub on web) |
| Release HTTPS gate + dual-Dio wire | `lib/core/network/api_client_networking.dart` |
| Consumer | `lib/core/network/api_client.dart` |

**Platforms:** Android and iOS only. Web and desktop use browser/OS TLS — pinning is not available there.

**Release builds:** Non-HTTPS `API_BASE_URL` throws `StateError` at `ApiClient` init (`assertReleaseHttps`).

**Debug/profile:** HTTP localhost URLs skip pinning (`shouldApplyCertPinning` requires `https://`). Android cleartext is allowed only in debug/profile manifests (F-fe-002).

---

## How it works

1. `ApiClient._()` calls `configureApiClientNetworking` with `CertPins.all` and `kReleaseMode`.
2. `assertReleaseHttps` rejects HTTP base URLs in release.
3. `shouldApplyCertPinning` returns true only when: mobile platform, HTTPS URL, non-empty pins, no `PASTE_*` placeholders.
4. `applyCertPinning` replaces the Dio `IOHttpClientAdapter.createHttpClient` factory with `HttpSecurityPinningClient(pins)`.

Pinning sits **below** interceptors (e.g. `AuthInterceptor`) on the HTTP adapter.

The first HTTPS request after app start may be slower while the native stack fetches/validates certificates — this is expected package behaviour.

---

## Extract SPKI pins

Run against production (`api.rostiq.co`). Replace the domain if it changes.

**Leaf certificate (primary pin):**

```bash
openssl s_client -connect api.rostiq.co:443 -servername api.rostiq.co 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

**Intermediate CA (backup pin):**

```bash
openssl s_client -connect api.rostiq.co:443 -showcerts 2>/dev/null \
  | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' \
  | csplit - '/-----BEGIN CERTIFICATE-----/' '{*}' --elide-empty-files --prefix=cert
# cert01 = leaf, cert02 = intermediate
openssl x509 -in cert02 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

Update `CertPins.leaf` and `CertPins.intermediate` in `cert_pins.dart`. Store extracted values in a secrets vault for rotation.

> If the server is behind Cloudflare, pin the Cloudflare-issued cert. Cloudflare rotates leaf certs frequently — keep the intermediate CA as backup.

---

## Certificate rotation

Never rotate the server cert and remove the old pin in the same release.

1. Extract the **new** leaf SPKI.
2. Ship an app release: new leaf → `CertPins.leaf` (primary), **old leaf → backup** (add alongside intermediate or replace intermediate temporarily).
3. Wait for majority of users to update.
4. Rotate the certificate on the server.
5. Next release: drop the old leaf pin; update intermediate if the CA chain changed.

---

## Testing

### Unit tests (CI)

```bash
cd frontend && flutter test \
  test/core/network/cert_pinning_test.dart \
  test/core/network/api_client_networking_test.dart \
  test/core/network/api_client_https_test.dart
```

### Manual MITM negative test (pre-production ops — required once)

**Not run in CI.** Complete before each major pin change or first production release with pinning enabled.

1. Start mitmproxy (or Charles) on your dev machine.
2. Install the proxy root CA on a physical Android/iOS test device.
3. Build a **release** APK/IPA with `--dart-define=API_BASE_URL=https://api.rostiq.co`.
4. Attempt login — requests **must fail** with a certificate/TLS error.
5. If traffic succeeds, pinning is broken — do not ship.

### Positive smoke

Real HTTPS request to production on a release build with shipped pins should succeed without proxy installed.

---

## Android cleartext (F-fe-002)

| Build variant | `usesCleartextTraffic` | Manifest |
|---------------|------------------------|----------|
| release (main) | **denied** (default) | `android/app/src/main/AndroidManifest.xml` |
| debug | allowed | `android/app/src/debug/AndroidManifest.xml` |
| profile | allowed | `android/app/src/profile/AndroidManifest.xml` |

Local emulator HTTP workflow requires a **debug** or **profile** build. See `docs/local-emulator-api.md`.

Manifest policy is covered by `test/android/cleartext_traffic_test.dart`.

---

## Pre-production checklist

- [ ] Re-extract leaf + intermediate SPKI pins; update `cert_pins.dart`
- [ ] Unit tests pass (`cert_pinning_test`, `api_client_networking_test`, `api_client_https_test`)
- [ ] Release build uses `--dart-define=API_BASE_URL=https://api.rostiq.co`
- [ ] **Manual mitmproxy negative test** — proxy + rogue CA installed → requests fail
- [ ] Certificate rotation runbook communicated to ops
- [ ] After server cert rotation: verify backup pin still valid or ship pin update first

---

## Out of scope

- Web CSP / browser pinning — not available; HTTPS only
- OTA / remote pin updates — rotation via app release
- Automated mitmproxy in CI — manual ops step sufficient for this audit
