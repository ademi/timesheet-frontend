# Suggested Development Backlog

Companion to [flutter-migration-impact-study.md](./flutter-migration-impact-study.md).

**Estimate scale:** Small · Medium · Large · Extra Large  
**Priority:** P0 Critical/blocking · P1 High · P2 Medium · P3 Low

---

## Backlog table

| Task | Area | Priority | Estimate | Dependencies | Notes |
|---|---|---|---|---|---|
| Confirm OpenAPI + JWT claims + actor login sequence | Discovery | P0 | Small | Backend availability | Blocker for auth work |
| Confirm app packaging (dual shell vs flavors vs split apps) | Discovery / Product | P0 | Small | Product | Drives navigation IA |
| Confirm mobile V1 scope matrix (clients, form builder, billing, reports) | Discovery / Product | P0 | Medium | Product | Prevents overbuilding |
| Confirm adjustments/report/payment/rate endpoint details | Discovery | P0 | Medium | Backend | See clarification-questions.md |
| Define cutover/force-update strategy with backend | Discovery | P0 | Small | Backend + mobile release owners | No back-compat |
| Spike signed GCS upload/download on iOS/Android/Web | Documents | P0 | Medium | Docs API draft | Unblocks engagements + forms files |
| Spike login → me/context → switch-tenant on staging | Auth | P0 | Medium | Auth APIs | Proves session model |
| Extend `TokenStorage` + `SessionController` for actor/engagement/tenant | Auth | P0 | Large | Spike above | Replace `user_role` portal |
| Implement `switch-tenant` + token rotation UX | Auth | P0 | Medium | SessionController | Contractor multi-tenant |
| Expand `AppPermissions` + actor/permission guards | Auth / RBAC | P0 | Medium | JWT claim confirm | Replace scheduling-only constants |
| Redesign `AppRoutes` / `app_pages` / shells (admin + contractor) | Navigation | P0 | Large | Packaging decision | Keep behind flag until cutover |
| Scaffold feature modules/bindings (engagements, clients, jobs, …) | Architecture | P0 | Medium | Folder strategy agreement | Empty compileable skeleton |
| Tenant members CRUD UI + API layer (replace staff employees) | Tenant members | P0 | Medium | Auth session | Replaces part of Employees |
| Contractor profile + register (if in scope) | Contractors | P1 | Medium | Auth | `/contractor-me`, register |
| Engagements list/detail + lifecycle actions | Engagements | P0 | Extra Large | Contractors + docs upload | Status machine critical |
| Engagement required docs categories + consent display | Engagements / Docs | P0 | Large | Documents service | pending_docs gate |
| Documents service (upload-url, finalize, download-url) | Documents | P0 | Large | Spike GCS | Shared by many modules |
| Clients / sites / contacts admin module | Clients | P1 | Large | Tenant session | Needed for standing jobs |
| Client invite create + show raw token once | Clients | P1 | Small | Clients module | Public acknowledge likely web |
| Form template consume API + dynamic submission renderer | Forms | P1 | Large | Documents for file fields | Builder may be P2/web |
| Form template builder UI (if mobile in scope) | Forms | P2 | Extra Large | Product scope | Prefer web if possible |
| Jobs CRUD (standing/ad_hoc) + catalog attach | Jobs | P0 | Large | Clients + forms | Constraints UX |
| Recurrence rules + generate visits UI | Jobs | P1 | Large | Jobs CRUD | Handle overlap errors |
| Visits list/detail + tasks toggle | Visits | P0 | Large | Jobs | Core entity screens |
| Visit check-in GPS + geofence error UX | Attendance | P0 | Large | Visits + geolocator | Replaces clock-in |
| Visit complete + required forms gate | Attendance / Forms | P0 | Large | Forms renderer | Replaces clock-out |
| Remove PIN kiosk (`/home`, PIN APIs, dialogs) | Attendance | P0 | Medium | Visit check-in live | Spec §23 |
| Remove employee clock status reuse across modules | Cleanup | P0 | Medium | New list APIs | Stop `clocked-in-status` |
| Contractor timetable / availability / leave | Scheduling | P1 | Large | Contractor APIs | Cross-tenant |
| Admin schedule board rewrite around visits | Scheduling | P1 | Extra Large | Visits APIs | Replace shift assignment board |
| Engagement rates UI | Rates | P1 | Medium | Engagements | Replace employee rates |
| Payment batches create/post/void + unpaid visit picker | Payments | P1 | Large | Completed visits + rates | Replace period payments |
| Remove payroll periods/settings/results/balance UI | Payroll cleanup | P0 | Medium | Payment batches replacement ready | Spec §23 |
| Attendance corrections redesign | Corrections | P1 | Large | Adjustment API confirm | Unknown until clarified |
| Attendance/visit reporting redesign | Reports | P1 | Large | Report API confirm | Unknown until clarified |
| Push notification event handlers for new types | Notifications | P2 | Small | Payload schema | Safe ignore unknown |
| Branch model radius fields + job location UX | Branches / Jobs | P1 | Medium | Branch API fields | Point+radius |
| Clear secure storage + payroll settings on app upgrade | Data migration | P0 | Small | Version bump strategy | Force re-login |
| Feature flags / dart-define DOMAIN_V2 | Platform | P0 | Small | — | Staging vs prod |
| Error catalog mapping (§19 codes) | Core | P0 | Medium | OpenAPI errors | Shared failure type |
| Rewrite/remove obsolete tests; add visit/engagement tests | Testing | P0 | Large | Parallel with features | mocktail |
| Manual QA checklist execution on staging | QA | P0 | Large | Staging seed data | See checklist below |
| App Store / Play staged rollout + monitoring | Rollout | P0 | Medium | Cutover plan | Coordinated with API |
| Billing accounts UI | Billing | P3 | Small | Product | Likely out of V1 mobile |
| Public client invite acknowledge in Flutter web | Public | P3 | Medium | Product | Likely separate web |

---

## Manual QA checklist (Phase 5)

### Auth / session

- [ ] Tenant member login lands in admin shell with correct permissions
- [ ] Contractor login with one engagement auto-selects tenant
- [ ] Contractor with multiple engagements can switch tenant; old refresh invalidated
- [ ] Hard-split conflict surfaces clear error if triggered
- [ ] App upgrade clears old tokens/settings and forces login

### Engagements

- [ ] Invite → accept → upload required docs → approve → activate
- [ ] Suspend blocks check-in; allows complete/check-out if open
- [ ] End revokes profile doc access for tenant; historical visit docs still readable by assignee
- [ ] Approve blocked when required docs missing/blocked scan

### Visits / attendance

- [ ] Check-in inside radius succeeds; enforce mode outside returns `geofence_rejected`
- [ ] Informational mode allows outside with stored verdict (if exposed)
- [ ] Complete blocked when required forms missing (`forms_incomplete`)
- [ ] Tasks toggle by assignee
- [ ] Cancel by tenant; open time entry closed per rules

### Payments

- [ ] Unpaid completed visits selectable into draft batch
- [ ] Post marks visits paid; double-add blocked
- [ ] Void returns visits unpaid (if enabled)
- [ ] Contractor can view own paid visits only

### Regression

- [ ] Token proactive refresh still works
- [ ] Branch selection (if still required) works for members
- [ ] Responsive admin shell destinations correct on wide/narrow
- [ ] Push device registration still succeeds
- [ ] First-login password flow (if retained)

---

## Suggested sprint slicing (indicative)

| Sprint focus | Outcomes |
|--------------|----------|
| S0 Discovery | Answers + OpenAPI + scope matrix |
| S1 Foundation | Session, routes skeleton, flags, docs spike |
| S2 People | Members + engagements + profile docs |
| S3 Work core | Jobs/visits/tasks + check-in/complete |
| S4 Enablement | Clients + forms submit + recurrence |
| S5 Money + schedule | Rates, batches, timetable/board |
| S6 Cleanup + QA | Remove obsolete modules, tests, staging dogfood |
| S7 Rollout | Store release + monitoring |

Exact sprint capacity is team-dependent; overall sized **Extra Large**.
