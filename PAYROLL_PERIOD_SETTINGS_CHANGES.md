# Payroll Period Settings Changes

## Purpose

The payroll period creation flow was changed from a fully manual date-range picker to a settings-based flow. This helps admins create weekly, biweekly, and monthly payroll periods faster and with fewer date mistakes.

## Previous Flow

Before this change, the `+` button on the Payroll Periods screen opened a date range picker immediately. The user had to manually choose both the start date and end date every time.

That flow was flexible, but it allowed common mistakes:

- overlapping payroll periods
- duplicate payroll periods
- wrong weekly or biweekly length
- accidental far-past or far-future periods

## New Flow

The app now supports Payroll Settings.

Admins can configure:

- payroll frequency: Weekly, Biweekly, Monthly, or Custom
- weekly start day
- biweekly anchor start date
- monthly start day
- default creation option: Previous, Current, or Next period
- whether overlapping periods should be prevented

## Payroll Settings Screen

A new Payroll Settings screen was added.

It can be opened from:

- the Payroll main screen
- the settings icon on the Payroll Periods screen

The settings are stored locally using `GetStorage`.

## FAB Behavior

The `+` button on Payroll Periods no longer opens the date range picker immediately.

Now it works like this:

1. If payroll settings do not exist, the user is asked to set them up first.
2. If settings exist, the app calculates quick period options.
3. A bottom sheet shows Previous, Current, and Next period options.
4. The user can still choose Custom date range as a fallback.
5. The selected period is validated before the API call.

## Weekly Payroll

Weekly payroll uses the configured week start day.

Example:

- week starts on Monday
- today is Tuesday, Jun 9, 2026
- current period is Jun 8, 2026 to Jun 14, 2026
- previous period is Jun 1, 2026 to Jun 7, 2026
- next period is Jun 15, 2026 to Jun 21, 2026

Weekly periods must be exactly 7 days.

## Biweekly Payroll

Biweekly payroll uses a configured anchor date.

The anchor date is the first known period start date. After that, the app calculates periods in 14-day blocks.

Biweekly periods must be exactly 14 days.

## Monthly Payroll

Monthly payroll supports:

- calendar month, when the start day is `1`
- custom monthly cutoff, such as `26` to `25`

The app calculates Previous, Current, and Next monthly periods from the configured monthly start day.

## Validation Added

Before creating a payroll period, the frontend now checks:

- end date is not before start date
- exact duplicate periods are blocked
- overlapping periods are blocked when enabled in settings
- weekly periods are exactly 7 days
- biweekly periods are exactly 14 days
- very long periods are blocked
- far-past or far-future periods require confirmation

## API Impact

No backend API change was required.

The app still calls the existing period creation API with:

- `period_start`
- `period_end`

The difference is that the frontend now calculates and validates those dates before sending them.

## Files Added

- `lib/app/data/models/payroll/payroll_settings.dart`
- `lib/app/data/models/payroll/payroll_period_calculator.dart`
- `lib/app/data/services/payroll_settings_storage.dart`
- `lib/app/controllers/payroll_settings_controller.dart`
- `lib/app/bindings/payroll_settings_binding.dart`
- `lib/app/views/payroll_settings_view.dart`

## Files Updated

- `lib/app/controllers/payroll_periods_controller.dart`
- `lib/app/views/payroll_periods_view.dart`
- `lib/app/controllers/payroll_main_controller.dart`
- `lib/app/views/payroll_main_view.dart`
- `lib/app/bindings/payroll_module_binding.dart`
- `lib/app/bindings/payroll_periods_binding.dart`
- `lib/app/routes/app_routes.dart`
- `lib/app/routes/app_pages.dart`
