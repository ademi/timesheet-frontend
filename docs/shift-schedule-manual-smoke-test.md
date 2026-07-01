# Employee Shift Schedule — Manual Smoke Test Checklist

Run against a backend with scheduling migration **V020** and demo seed loaded.

**Prerequisites**
- [ ] API running and reachable (`API_BASE_URL` configured)
- [ ] Demo admin credentials with `scheduling.read` and `scheduling.manage`
- [ ] Head Office (or known) branch selected

## Navigation
- [ ] Login as demo admin
- [ ] Open admin panel → tap **Shift Schedule** card
- [ ] On wide layout, **Schedule** rail item opens the same screen

## Today view
- [ ] Today view loads with employee roster
- [ ] Mixed statuses visible (assigned, leave, unassigned)
- [ ] Summary chips show counts from `board.meta`
- [ ] Tap summary chip filters list (e.g. Unassigned)
- [ ] Tap employee row → bottom sheet shows status, shift, times
- [ ] Pull-to-refresh reloads board

## Week view
- [ ] Switch to **Week** → grid renders 7 day columns
- [ ] Employee column sticky on horizontal scroll
- [ ] Prev/next week updates range label
- [ ] Tap cell → bottom sheet opens
- [ ] Today column highlighted when in current week

## Manage actions (`scheduling.manage`)
- [ ] **Change shift** on a cell updates board after save
- [ ] **Mark day off** works with confirmation
- [ ] **Mark leave** with date range + type
- [ ] **Clear override** on override source day
- [ ] **Recurring schedules** list / add / delete
- [ ] FAB → **Copy last week** copies overrides

## Demo seed scenarios
- [ ] **DEMO-E04** — unassigned
- [ ] **Employee1** — daily override on 2026-06-23
- [ ] **Employee2** — leave 2026-06-24 to 2026-06-25

## Permissions & errors
- [ ] User with only `scheduling.read` — no FAB, no edit actions in sheet
- [ ] User without `scheduling.read` — No access screen
- [ ] 409 on overlapping recurring — conflict dialog shown

## Automated tests

```bash
flutter test test/app/views/widgets/shift_schedule_cell_test.dart
flutter test test/core/services/token_storage_test.dart
```
