# DF-P4 Task 1 report

## Request-path estimate

No network profiler was available, so these are code-path counts for a new
contractor who enters onboarding and advances from Legal to Notices:

| Path | Before | After |
| --- | ---: | ---: |
| Initial onboarding GETs | 6 | 3 |
| Legal → Notices GETs | 2 | 1 |
| Initial through Notices | 8 | 4 |

The initial count is `me/context` (1), two legal documents (2), plus eagerly
created engagements, credentials, and evidence-document loaders (3). Those
last three now load only on their respective steps. The notice call was issued
twice by `goToStep` and `next`; the loaded/in-flight guard reduces it to one.
Concurrent `hydrateFromMeContext` calls share one request, and accepting an
engagement keeps the returned entity rather than re-listing engagements.

## Tenant safety and verification

Cached onboarding state is scoped to the current contractor ID; no endpoint or
query scope changed. Focused Flutter tests and targeted static analysis pass.
