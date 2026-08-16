# Merge plan: `refactor/client_info_update` → `master`

**Date:** 2026-08-16  
**Direction:** merge **into** `master` (keep master’s jobs/visits/roster model; bring feature-branch client/workforce/compliance work in)  
**Merge base:** `6e59cdb`  
**Dry-run result:** merge **fails** with **3 content conflicts** (other overlapping files auto-merge cleanly)

---

## 1. Branch divergence snapshot

| Side | Tip | Commits since base | Files changed |
|------|-----|--------------------|---------------|
| `master` (HEAD) | `9161fc3` — allow book-one before support exists | **41** | ~176 |
| `refactor/client_info_update` | `5f00847` — invite preview & email confirmation | **6** | ~36 |

`master` has moved much further, especially around **jobs → ongoing support**, **people-by-day roster**, **client-first visits**, and **DOMAIN_V2 / admin portal cleanup**. The feature branch is smaller but still touches shared client and shell surfaces.

### What `refactor/client_info_update` adds (to bring in)

- Client / site form UX: validation, list improvements, site form enhancements
- Workforce invite preview + email confirmation flow
- Engagements / rate-band form extract (`engagement_rate_form_view`)
- Compliance / home alerts & notification feed tweaks
- Staff credential review tweaks
- Admin nav / responsive scaffold small updates
- Feedback task breakdown doc

### What `master` already changed (must keep)

- Modular client detail (section widgets + visits + support CTAs)
- Site address helpers / maps / copy (`displayAddress`, `mapsQueryLabel`, etc.)
- Ongoing support ensure/get, book-one, roster support filter
- Jobs demoted to Settings “Supports”; roster board rewrite
- Legacy admin portal + `DOMAIN_V2` removed

---

## 2. Recommended merge procedure

Do this on a **throwaway branch** first (do not merge blind onto `master`).

```bash
git checkout master
git pull
git checkout -b merge/client_info_update-into-master
git merge refactor/client_info_update
# resolve the 3 conflicts below
flutter test
# smoke: clients list/detail/form, workforce invite, home alerts, roster
```

After conflicts are resolved and tests pass:

```bash
git checkout master
git merge --no-ff merge/client_info_update-into-master
# or open a PR from the merge branch into master
```

**Rule of thumb while resolving:** prefer **`master` structure** for client detail / jobs / visits / shell navigation; selectively **port feature-branch UX** (forms, invite preview, alerts) into that structure.

---

## 3. Confirmed conflicts (dry-run)

A `git merge --no-commit --no-ff refactor/client_info_update` on current `master` produced:

| File | Severity | Why |
|------|----------|-----|
| `lib/features/clients/views/client_detail_view.dart` | **Major** | Architectural rewrite on both sides |
| `lib/features/clients/data/models/client_models.dart` | Medium | Same `ClientSiteOut` getters edited differently |
| `lib/features/clients/widgets/client_requirement_editors.dart` | Medium | Duplicate / divergent widget body |

### 3.1 Major: `client_detail_view.dart`

| | `master` | `refactor/client_info_update` |
|--|----------|-------------------------------|
| Size | ~153 lines | ~481 lines |
| Shape | Thin shell + section widgets (`ClientDetailSitesSection`, `…VisitsSection`, `…SupportSection`, …) | Monolithic screen (inline sites, maps, clipboard, requirements) |
| Imports | Section widgets only | `external_url`, `async_action`, `client_models`, requirement editors |

**Conflict shape:** large hunks where `master` has a single-scroll `ListView` of sections, while the feature branch still has the old embedded layout (and wants map/clipboard imports that `master` already moved into helpers/sections).

**Resolution strategy (recommended):**

1. **Keep `master`’s file** as the base (sectioned layout + support/visits).
2. Diff feature-only behaviors that are **not** already on `master` (form polish usually lives in `client_form_view` / `client_site_form_view`, which auto-merge).
3. If anything unique remains (copy/open-map nuances), port into `client_detail_sites_section.dart` / utils — **do not** re-inline the monolithic UI.
4. Drop feature-branch imports of `external_url` / `async_action` from this view unless a section still needs them here.

This is the highest-risk file: wrong resolution can wipe master’s visits/support CTAs or reintroduce the pre-refactor detail screen.

### 3.2 Medium: `client_models.dart` (`ClientSiteOut`)

Both sides touch address display helpers:

- **`master`:** `displayAddress` falls back to `name` when empty; adds `mapsQueryLabel`.
- **Feature:** same `displayAddress` join logic **without** empty fallback / `mapsQueryLabel`.

**Resolution:** keep **`master`’s** getters (`displayAddress` + `mapsQueryLabel`). Feature additions elsewhere in the model (if any clean hunks remain) can stay.

### 3.3 Medium: `client_requirement_editors.dart`

Conflict is near the end of a requirement card build method: feature branch effectively **re-duplicates** help text + field/document blocks that `master` already structured differently.

**Resolution:** keep **`master`’s** closing structure; only re-apply feature tweaks that are missing (e.g. help text placement) **once**, without duplicating the child widgets.

---

## 4. Overlap that auto-merged (still review)

These files were changed on **both** branches but Git auto-merged them. They compiled into the index without conflict markers, but they deserve a **manual read** before commit:

| File | Risk | Notes |
|------|------|--------|
| `lib/features/clients/controllers/clients_controller.dart` | **High (logical)** | Both sides large (~180–250 line diffs). Master added visits/support/horizon; feature improved form/site flows. Auto-merge can leave mixed APIs or dead paths. |
| `lib/features/shell/staff_shell.dart` | Medium | Master demoted Jobs → Supports; feature changed admin/menu layout. Confirm nav labels/routes match V2-only shell. |
| `test/features/shell/staff_shell_nav_test.dart` | Medium | Must match final shell items. |
| `lib/app/routes/app_routes.dart` | Low–medium | Feature adds invite-related route; master cleaned admin routes. |
| `lib/core/constants/api_paths.dart` | Low–medium | Both add paths; verify no duplicate constants. |
| `lib/core/errors/app_failure.dart` | Low | Small message/code tweaks. |
| `lib/app/controllers/auth_controller.dart` | Low | Tiny feature addition. |

**No text conflict** ≠ **correct product behavior**. Especially re-test:

- Client detail: sites, contacts, ongoing support, book-one, visits list
- Client create/edit + site form validation from the feature branch
- Workforce invite preview / email confirmation
- Staff shell: Clients, roster/visits, Supports under Settings

---

## 5. Areas unlikely to conflict (but conceptually related)

Feature branch does **not** heavily edit master’s new roster/jobs stack. Expect clean takes of master’s:

- `lib/features/jobs/**`
- `lib/features/visits/**` (roster board, overlays, cancel/release/claim)
- Client detail section widgets under `lib/features/clients/widgets/client_detail_*.dart`

Conversely, master’s purge of legacy admin / `DOMAIN_V2` should remain; do not resurrect admin portal files from the feature branch (they are not in the feature tip’s unique file set anyway).

---

## 6. Conflict likelihood summary

| Category | Expectation |
|----------|-------------|
| Git content conflicts | **3 files** (confirmed) |
| Major product conflict | **Client detail architecture** — resolve for `master` layout |
| Silent logical risk | **`clients_controller.dart`**, **`staff_shell.dart`** |
| Jobs / roster / visits | Low merge conflict; keep master’s model |
| Invite / workforce / compliance / forms | Mostly additive; should land with light review |

**Verdict:** Merge is **feasible**, not clean. Plan for **~1 focused conflict-resolution session** on client detail + models/editors, then a **controller/shell sanity pass** and targeted Flutter tests — not a blind merge.

---

## 7. Post-merge checklist

- [ ] Resolve 3 conflicted files using strategies in §3
- [ ] Manually review auto-merged `clients_controller.dart` and `staff_shell.dart`
- [ ] `flutter analyze` (or IDE analysis) on touched packages
- [ ] `flutter test` (at least clients + shell + engagements + visits smoke)
- [ ] Manual smoke: client CRUD, site maps/copy, support CTAs, invite preview, home alerts bell
- [ ] Confirm no regression of roster people-by-day board / book-one-before-support

---

## 8. Suggested merge commit message (after resolution)

```
Merge branch 'refactor/client_info_update' into master

Bring client/site form UX, workforce invite preview, and compliance
alert tweaks onto the client-first jobs/visits master line; keep
modular client detail and master's site address helpers.
```
