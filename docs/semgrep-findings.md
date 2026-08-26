# Semgrep Security Scan Findings

**Command:** `uvx semgrep scan --config auto`  
**Last re-scan:** 2026-08-26  
**Semgrep version:** 1.174.0  
**Engine:** OSS  
**Config:** `auto` (Community rules)

## Current status

| Metric | Value |
| --- | --- |
| Open findings | **0** |
| Rules run | 369 |
| Targets scanned | 422 |
| Parsed lines | ~100.0% |

Re-scan after remediation: **clean** (0 findings).

---

## Remediated findings

### 1. Exported Android activity — remediates

| Field | Value |
| --- | --- |
| **Severity** | WARNING |
| **Rule ID** | `java.android.security.exported_activity.exported_activity` |
| **File** | `android/app/src/main/AndroidManifest.xml` |
| **Status** | Remediates / accepted required export |

**Why `exported="true"` cannot be removed**

`MainActivity` is the Flutter launcher activity with a `MAIN` / `LAUNCHER` intent-filter. Android requires `android:exported="true"` for that role; setting `false` breaks home-screen / Play Store launching.

**What we changed**

1. **`AndroidManifest.xml`** — Documented the required export and added an inline Semgrep ignore (`nosemgrep`) with justification so the scan no longer treats the intentional launcher export as an open issue.
2. **`MainActivity.kt`** — Hardened cold start / `onNewIntent` by stripping unexpected Intent URI `data` (no VIEW / deep-link filters are registered). Intent extras are left intact so FCM / notification taps still work. Flutter auth guards continue to gate privileged UI.

**Verification**

```bash
uvx semgrep scan --config auto
# Findings: 0
```

---

## How to re-run

```bash
uvx semgrep scan --config auto
```
