import '../../../app/routes/app_routes.dart';
import '../models/tutorial_guide.dart';

/// Static curated catalog for staff-web tutorials (option A — no CMS).
///
/// Each entry is an **article** with sections; steps live inside sections.
abstract final class TutorialCatalog {
  TutorialCatalog._();

  static const List<TutorialGuide> guides = [
    TutorialGuide(
      id: 'getting-around',
      title: 'Getting around the staff app',
      summary:
          'Where to find Home, Roster, people, billing, and Settings — and '
          'what the app bar actions do.',
      tags: ['navigation', 'home', 'settings', 'overview'],
      routeHints: [AppRoutes.staffHome, AppRoutes.staffSettings],
      writtenBy: 'Rostiq',
      updatedLabel: 'November 2026',
      sections: [
        TutorialSection(
          id: 'nav',
          heading: 'Main navigation',
          body:
              'Rostiq staff web uses a left rail on wide screens and a bottom '
              'bar on narrow layouts. The first destinations are the ones you '
              'use every day; everything else sits under More on small screens.',
          steps: [
            'Use Home, Roster, Participants, and Support workers from the '
                'primary nav.',
            'On narrow layouts, open More for Attendance, Payments, Billing, '
                'Staff, and Settings.',
          ],
        ),
        TutorialSection(
          id: 'home',
          heading: 'Home and alerts',
          body:
              'Home is your operations pulse: alerts that need attention, plus '
              'the pilot getting-started checklist while you are ramping up.',
          steps: [
            'Open Home after sign-in to scan alerts and checklist items.',
            'Work through checklist items as you configure the tenant.',
          ],
        ),
        TutorialSection(
          id: 'app-bar',
          heading: 'App bar actions',
          body:
              'Every main staff screen shares the same app bar utilities so '
              'feedback and notifications stay one click away.',
          steps: [
            'Use Feedback to send a suggestion or issue without leaving the page.',
            'Open Notifications for compliance and ops events.',
            'Use Refresh when a list looks stale, and Log out when finished.',
          ],
        ),
        TutorialSection(
          id: 'settings',
          heading: 'Settings',
          body:
              'Settings holds tenant preferences, integrations (such as Xero), '
              'and pilot feedback history. It is the hub for admin setup work.',
        ),
      ],
    ),
    TutorialGuide(
      id: 'roster-publish',
      title: 'Building and publishing a roster week',
      summary:
          'Compose visits or group shifts on the week board, review drafts, '
          'then publish so workers can see their work.',
      tags: ['roster', 'visits', 'publish', 'shifts', 'compose'],
      routeHints: [
        AppRoutes.staffVisits,
        AppRoutes.staffRosterCompose,
        AppRoutes.staffGroupShiftBook,
        AppRoutes.staffGroupShiftPublish,
      ],
      writtenBy: 'Rostiq',
      updatedLabel: 'November 2026',
      sections: [
        TutorialSection(
          id: 'board',
          heading: 'The roster board',
          body:
              'Roster shows a staff week board for participants and workers. '
              'Drafts stay editable until you publish; published visits are '
              'what support workers see in their app.',
          steps: [
            'Open Roster from the staff nav.',
            'Scan the week for open slots, drafts, and published visits.',
          ],
        ),
        TutorialSection(
          id: 'compose',
          heading: 'Composing visits and group shifts',
          body:
              'One-to-one visits and shared / group supports use compose flows '
              'so people, time, and location stay consistent before publish.',
          steps: [
            'Add a visit or open roster compose to set people, time, and location.',
            'For shared supports, use Book group shift and assign participants '
                'and workers.',
            'Review draft shifts on the board and edit details before publish.',
          ],
        ),
        TutorialSection(
          id: 'publish',
          heading: 'Publishing the week',
          body:
              'Publish when the week is ready. After publish you can still use '
              'shift detail for windows, attendance flags, or travel adjustments.',
          steps: [
            'Publish when the week looks correct so workers see assigned visits.',
            'Open shift detail later if you need to adjust windows, attendance, '
                'or travel.',
          ],
        ),
      ],
    ),
    TutorialGuide(
      id: 'participants-workers',
      title: 'Adding participants and support workers',
      summary:
          'Create participant records, flesh out profiles, and invite or '
          'onboard your support worker workforce.',
      tags: ['participants', 'clients', 'workforce', 'invite', 'onboarding'],
      routeHints: [
        AppRoutes.staffClients,
        AppRoutes.staffWorkforce,
        AppRoutes.staffClientOnboarding,
        AppRoutes.staffWorkforceInvite,
      ],
      writtenBy: 'Rostiq',
      updatedLabel: 'November 2026',
      sections: [
        TutorialSection(
          id: 'participants',
          heading: 'Participants',
          body:
              'Participants are the people you support. Profiles hold sites, '
              'contacts, and support-plan context used when you roster.',
          steps: [
            'Open Participants and use Add participant to create a record.',
            'Complete sites, contacts, and support-plan details from the profile.',
          ],
        ),
        TutorialSection(
          id: 'workers',
          heading: 'Support workers',
          body:
              'Support workers (contractors) clock in, write notes, and appear '
              'on the roster. Invite them by email or continue after they '
              'register via engagement and credentials.',
          steps: [
            'Open Support workers to manage your contractor workforce.',
            'Invite a worker by email, or follow engagement / credentials after '
                'they register.',
          ],
        ),
        TutorialSection(
          id: 'import',
          heading: 'Bulk import',
          body:
              'When you are migrating from another system, import tools under '
              'Participants or Support workers can load many records at once.',
        ),
      ],
    ),
    TutorialGuide(
      id: 'attendance-review',
      title: 'Attendance review basics',
      summary:
          'Check clock-ins, resolve gaps, and adjust attendance so billing and '
          'payments stay clean.',
      tags: ['attendance', 'clock-in', 'review', 'gps'],
      routeHints: [AppRoutes.staffAttendanceReview],
      writtenBy: 'Rostiq',
      updatedLabel: 'November 2026',
      sections: [
        TutorialSection(
          id: 'why',
          heading: 'Why review attendance',
          body:
              'Workers clock in and out with GPS context. Review catches missing '
              'punches, late clocks, and adjustments before you pay or export '
              'plan-manager CSV.',
        ),
        TutorialSection(
          id: 'how',
          heading: 'How to review',
          body:
              'Attendance review lists visits that need attention. Open a visit '
              'to compare scheduled vs actual times.',
          steps: [
            'Open Attendance review from the staff menu (More on narrow layouts).',
            'Scan visits that need attention — missing punches, late clocks, or '
                'adjustments.',
            'Open a visit to compare scheduled vs actual times and GPS context.',
            'Apply adjustments when you have permission, then save.',
          ],
        ),
      ],
    ),
    TutorialGuide(
      id: 'payments-csv',
      title: 'Payments and plan-manager CSV',
      summary:
          'Build payment batches for workers and export claim-ready CSV for '
          'plan managers.',
      tags: ['payments', 'billing', 'csv', 'exports', 'ndis'],
      routeHints: [
        AppRoutes.staffPayments,
        AppRoutes.staffBillingExports,
      ],
      writtenBy: 'Rostiq',
      updatedLabel: 'November 2026',
      sections: [
        TutorialSection(
          id: 'payments',
          heading: 'Payments batches',
          body:
              'Payments groups payable visits so you can batch work for payroll '
              'or contractor pay runs.',
          steps: [
            'Open Payments to review payable visits grouped for batching.',
            'Select visits / workers and create a payment batch when ready.',
          ],
        ),
        TutorialSection(
          id: 'billing',
          heading: 'Plan-manager CSV exports',
          body:
              'Billing exports produce plan-manager CSV and related claim files. '
              'Clean attendance and complete visit notes before you export.',
          steps: [
            'Open Billing exports for plan-manager CSV and related claim files.',
            'Download the export and upload it to your plan-manager workflow.',
            'Fix attendance or notes first if the export looks incomplete.',
          ],
        ),
      ],
    ),
    TutorialGuide(
      id: 'staff-permissions',
      title: 'Staff users and permissions',
      summary:
          'Invite coordinators and admins, and understand why menus differ by '
          'permission.',
      tags: ['staff', 'admin', 'permissions', 'rbac', 'members'],
      routeHints: [AppRoutes.staffMembers, AppRoutes.staffAdd],
      writtenBy: 'Rostiq',
      updatedLabel: 'November 2026',
      sections: [
        TutorialSection(
          id: 'directory',
          heading: 'Staff directory',
          body:
              'Staff members are tenant users of the staff web app — not '
              'support workers in the field. Permissions control which nav '
              'items and actions they see.',
          steps: [
            'Open Staff to see tenant members.',
            'Use Add member to invite someone; they complete invite / password '
                'setup.',
          ],
        ),
        TutorialSection(
          id: 'access',
          heading: 'Permissions and offboarding',
          body:
              'If a menu is missing, the user likely lacks the required '
              'permission. When someone leaves, adjust or revoke access from '
              'member detail.',
          steps: [
            'Confirm the right role / permissions when onboarding a coordinator.',
            'Revoke or adjust access from member detail when someone leaves.',
          ],
        ),
      ],
    ),
    TutorialGuide(
      id: 'xero-timesheets',
      title: 'Xero timesheet export',
      summary:
          'Connect Xero under Settings → Integrations and export timesheets '
          'for payroll.',
      tags: ['xero', 'integrations', 'payroll', 'timesheet'],
      routeHints: [AppRoutes.staffXeroSettings, AppRoutes.staffSettings],
      writtenBy: 'Rostiq',
      updatedLabel: 'November 2026',
      sections: [
        TutorialSection(
          id: 'connect',
          heading: 'Connect Xero',
          body:
              'Xero lives under Settings → Integrations. You connect once via '
              'OAuth; reconnect if the token expires later.',
          steps: [
            'Go to Settings → Integrations → Xero.',
            'Connect your Xero organisation and complete the OAuth return.',
          ],
        ),
        TutorialSection(
          id: 'export',
          heading: 'Export timesheets',
          body:
              'Map workers / settings as prompted so exports line up with '
              'payroll, then run an export for the period you need.',
          steps: [
            'Map workers / settings so exports match payroll.',
            'Run a timesheet export for the period you need.',
            'Confirm the result in Xero.',
          ],
        ),
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
