import '../../../app/routes/app_routes.dart';
import '../models/tutorial_guide.dart';

/// Static curated catalog for staff-web tutorials (option A — no CMS).
abstract final class TutorialCatalog {
  TutorialCatalog._();

  static const List<TutorialGuide> guides = [
    TutorialGuide(
      id: 'getting-around',
      title: 'Getting around the staff app',
      summary:
          'Learn the main navigation, Home alerts, and where Settings live.',
      tags: ['navigation', 'home', 'settings', 'overview'],
      routeHints: [AppRoutes.staffHome, AppRoutes.staffSettings],
      steps: [
        'Use the left rail (wide screens) or bottom bar (narrow) to move '
            'between Home, Roster, Participants, and Support workers.',
        'Open More on narrow layouts for Attendance, Payments, Billing, and '
            'Settings.',
        'Home shows operational alerts and the pilot getting-started checklist.',
        'App bar actions include Feedback, Notifications, Refresh, and Log out.',
        'Settings holds tenant preferences, integrations (e.g. Xero), and '
            'pilot feedback history.',
      ],
    ),
    TutorialGuide(
      id: 'roster-publish',
      title: 'Building and publishing a roster week',
      summary:
          'Compose visits or group shifts, review the week board, then publish.',
      tags: ['roster', 'visits', 'publish', 'shifts', 'compose'],
      routeHints: [
        AppRoutes.staffVisits,
        AppRoutes.staffRosterCompose,
        AppRoutes.staffGroupShiftBook,
        AppRoutes.staffGroupShiftPublish,
      ],
      steps: [
        'Open Roster to see the staff week board for participants and workers.',
        'Add a visit or open the roster compose flow to set people, time, and '
            'location.',
        'For shared supports, use Book group shift and assign participants '
            'and workers.',
        'Review draft shifts on the board; edit details before publish.',
        'Publish when the week is ready so workers can see assigned visits.',
        'Use shift detail to adjust windows, attendance flags, or travel when '
            'needed.',
      ],
    ),
    TutorialGuide(
      id: 'participants-workers',
      title: 'Adding participants and support workers',
      summary:
          'Create participant records and invite or onboard support workers.',
      tags: ['participants', 'clients', 'workforce', 'invite', 'onboarding'],
      routeHints: [
        AppRoutes.staffClients,
        AppRoutes.staffWorkforce,
        AppRoutes.staffClientOnboarding,
        AppRoutes.staffWorkforceInvite,
      ],
      steps: [
        'Open Participants to view the client list; use Add participant to '
            'create a record.',
        'Complete sites, contacts, and support-plan details from the '
            'participant profile.',
        'Open Support workers to manage your contractor workforce.',
        'Invite a worker by email, or follow the engagement / credentials '
            'flow after they register.',
        'Import tools under Participants / Support workers can bulk-load '
            'records when available.',
      ],
    ),
    TutorialGuide(
      id: 'attendance-review',
      title: 'Attendance review basics',
      summary:
          'Check clock-ins, resolve gaps, and adjust attendance before billing.',
      tags: ['attendance', 'clock-in', 'review', 'gps'],
      routeHints: [AppRoutes.staffAttendanceReview],
      steps: [
        'Open Attendance review from the staff menu (More on narrow layouts).',
        'Scan visits that need attention — missing punches, late clocks, or '
            'adjustments.',
        'Open a visit to compare scheduled vs actual times and GPS context.',
        'Apply adjustments when you have permission, then save.',
        'Clean attendance data feeds smoother payments and plan-manager '
            'exports.',
      ],
    ),
    TutorialGuide(
      id: 'payments-csv',
      title: 'Payments and plan-manager CSV',
      summary:
          'Build payment batches and export claim-ready CSV for plan managers.',
      tags: ['payments', 'billing', 'csv', 'exports', 'ndis'],
      routeHints: [
        AppRoutes.staffPayments,
        AppRoutes.staffBillingExports,
      ],
      steps: [
        'Open Payments to review payable visits grouped for batching.',
        'Select visits / workers and create a payment batch when ready.',
        'Open Billing exports for plan-manager CSV and related claim files.',
        'Download the export and upload it to your plan-manager workflow.',
        'Keep attendance and visit notes complete before export to reduce '
            'rework.',
      ],
    ),
    TutorialGuide(
      id: 'staff-permissions',
      title: 'Staff users and permissions',
      summary: 'Invite staff members and understand role-gated menu access.',
      tags: ['staff', 'admin', 'permissions', 'rbac', 'members'],
      routeHints: [AppRoutes.staffMembers, AppRoutes.staffAdd],
      steps: [
        'Open Staff to see tenant members who can use the staff web app.',
        'Add staff with Add member; they complete invite / password setup.',
        'Menus and actions are gated by permissions — users only see what '
            'they can access.',
        'Use Settings and Staff together when onboarding a new admin or '
            'coordinator.',
        'Revoke or adjust access from the member detail when someone leaves '
            'the organisation.',
      ],
    ),
    TutorialGuide(
      id: 'xero-timesheets',
      title: 'Xero timesheet export',
      summary: 'Connect Xero and export timesheets for payroll.',
      tags: ['xero', 'integrations', 'payroll', 'timesheet'],
      routeHints: [AppRoutes.staffXeroSettings, AppRoutes.staffSettings],
      steps: [
        'Go to Settings → Integrations → Xero.',
        'Connect your Xero organisation and complete the OAuth return.',
        'Map workers / settings as prompted so exports line up with payroll.',
        'Run a timesheet export for the period you need.',
        'Confirm the result in Xero; reconnect if the token expires.',
      ],
    ),
  ];

  static TutorialGuide? byId(String id) {
    for (final g in guides) {
      if (g.id == id) return g;
    }
    return null;
  }
}
