# Certificate Pinning — Implementation Guide (N-06)

## Background

The current `ApiClient` in `lib/core/network/api_client.dart` contains a placeholder:

```dart
static const _spkiPin = 'PASTE_BASE64_SPKI_PIN_HERE';
```

This constant is **never read**. Dio performs standard OS certificate validation only. Without
pinning, an attacker on the same network who has installed a rogue root CA (common on corporate
MDM devices and in some geographies) can intercept all API traffic — including access tokens,
refresh tokens, GPS coordinates, and payroll data.

---

## Step 1 — Extract the Production SPKI Pin

Run this against the production server's certificate. Replace `timesheetbackend.deepdownidea.com`
with the actual domain if it changes.

```bash
openssl s_client -connect timesheetbackend.deepdownidea.com:443 -servername timesheetbackend.deepdownidea.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

Copy the output (a 44-character base-64 string). This is your SPKI pin.  
**Store it in `_spkiPin` in `api_client.dart`** and also record it in a safe place (password
manager / secrets vault). You will need it again when the certificate renews.

> If the server is behind Cloudflare, pin the Cloudflare-issued cert — not a self-signed one.
> Cloudflare rotates certificates, so you must also set a **backup pin** for the next
> certificate in the chain (see Step 3).

---

## Step 2 — Choose an Implementation Approach

### Option A — `http_certificate_pinning` package (recommended for now)

The `http_certificate_pinning` package works at the HTTP client level and does not require
Dio-level changes. It is available on pub.dev.

Add to `pubspec.yaml`:

```yaml
dependencies:
  http_certificate_pinning: ^3.0.1
```

Then replace the Dio `httpClientAdapter` in `ApiClient._`:

```dart
import 'dart:io';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

// Inside ApiClient._() constructor, after creating each Dio instance:
(plainDio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
  final client = HttpClient();
  client.badCertificateCallback = (cert, host, port) {
    // Check SHA-256 of the SPKI against the pinned value.
    // http_certificate_pinning provides a helper for this.
    return false; // reject everything that does not match
  };
  return client;
};
```

However, this package's API changes across versions. See the package README for the exact
`SecureHttpClient.build` or `CertificatePinning.check` API for the version you install.

---

### Option B — Manual `IOHttpClientAdapter` (no extra package)

This gives full control. Works with any Dio version.

```dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart'; // add to pubspec.yaml

/// Returns true if the certificate's SPKI SHA-256 matches [pinnedBase64].
bool _certMatchesPin(X509Certificate cert, String pinnedBase64) {
  final digest = sha256.convert(cert.der);
  return base64.encode(digest.bytes) == pinnedBase64;
}

void _pinDio(Dio dio, String pinnedBase64) {
  (dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // Returning false = reject. We only accept the cert that matches our pin.
      return false;
    };
    return client;
  };
  // Override the onHttpClientCreate to inspect the actual cert:
  (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
    client.badCertificateCallback = (X509Certificate cert, String host, int port) => false;
    return client;
  };
}
```

> **Note:** Dio's `IOHttpClientAdapter` does not expose the raw `X509Certificate` during the
> normal TLS handshake for SPKI comparison. The cleanest production approach uses a custom
> `SecurityContext` with the pinned certificate file, or the `native_http` package.

---

### Option C — `native_http` + Dio adapter (most robust, most work)

`native_http` (pub.dev) delegates HTTP to the platform's native stack (NSURLSession on iOS,
OkHttp on Android) and supports SPKI pinning natively via configuration objects. This is the
approach used by large Flutter apps.

```yaml
dependencies:
  native_http: ^0.2.0
```

```dart
import 'package:native_http/native_http.dart';

final client = NativeHttpClient(
  certificatePinning: CertificatePinning(
    host: 'timesheetbackend.deepdownidea.com',
    pinnedSPKIs: [_spkiPin, _spkiPinBackup],
  ),
);
```

Then wrap it in a Dio adapter. See the `native_http` README for the adapter setup.

---

## Step 3 — Backup Pin (Mandatory)

Always configure a **backup pin** — the SPKI of the next certificate in the chain (e.g. the
intermediate CA) or the next leaf certificate you plan to deploy. Without it, a certificate
rotation will break all deployed app versions that have a hard pin.

```dart
// In api_client.dart
static const _spkiPin       = 'BASE64_OF_CURRENT_LEAF_CERT_SPKI';
static const _spkiPinBackup = 'BASE64_OF_INTERMEDIATE_CA_SPKI';  // stays stable longer
```

To extract the intermediate CA SPKI:

```bash
openssl s_client -connect timesheetbackend.deepdownidea.com:443 -showcerts 2>/dev/null \
  | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' \
  | csplit - '/-----BEGIN CERTIFICATE-----/' '{*}' --elide-empty-files --prefix=cert
# cert01 = leaf, cert02 = intermediate, cert03 = root
openssl x509 -in cert02 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

---

## Step 4 — Wire into `ApiClient`

After choosing an option, update `api_client.dart`:

```dart
class ApiClient {
  static const _spkiPin       = 'PASTE_REAL_LEAF_SPKI_HERE';
  static const _spkiPinBackup = 'PASTE_INTERMEDIATE_CA_SPKI_HERE';

  ApiClient._(TokenStorage tokenStorage) : ... {
    // Apply pinning to both Dio instances
    _applyPinning(plainDio);
    _applyPinning(dio);
    dio.interceptors.add(AuthInterceptor(...));
  }

  void _applyPinning(Dio d) {
    // Insert chosen implementation here (Option A, B, or C above)
  }
}
```

---

## Step 5 — Testing Pinning

1. **Positive test:** make a real HTTPS request to the backend — it should succeed.
2. **Negative test (using a proxy):**
   - Configure Charles Proxy / mitmproxy on your machine.
   - Install the proxy's root CA on your test device.
   - Run the app — requests should **fail with a certificate error**, not succeed.
   - If they succeed, pinning is not working.
3. **Unit test:** mock `HttpClient.badCertificateCallback` and assert it returns `false` for
   a non-matching certificate.

---

## Step 6 — Certificate Rotation Process

When the production certificate is about to expire (Cloudflare auto-renews, but you still need
to update the pin in the app):

1. Extract the new leaf certificate's SPKI (Step 1).
2. Add it as the **primary pin** in a new app release, keeping the old pin as the backup.
3. Publish the new app version. Wait for the majority of users to update.
4. Rotate the certificate on the server.
5. In the subsequent release, remove the old pin.

> **Never** remove the old pin and rotate the certificate in the same release — this will
> brick all users on the old version.

---

## Summary Checklist

- [ ] Extract SPKI pin from production certificate
- [ ] Extract SPKI pin from intermediate CA (backup pin)
- [ ] Choose implementation option (A, B, or C)
- [ ] Add chosen package to `pubspec.yaml`
- [ ] Wire `_applyPinning()` into both `plainDio` and `dio` in `ApiClient`
- [ ] Replace placeholder strings in `_spkiPin` / `_spkiPinBackup`
- [ ] Test with mitmproxy — requests should fail
- [ ] Document certificate renewal process in ops runbook
