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
              'Home (Dashboard) is your operations pulse: subscription status, '
              'credential and plan-burn alerts, and overview counts for '
              'participants, workers, supports, and roster.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/getting-around/home.png',
              caption:
                  'Staff Home — left nav, alerts, and overview cards.',
            ),
          ],
          steps: [
            'Open Home after sign-in to scan alerts and overview numbers.',
            'Follow alert links (e.g. Review workers) when something needs action.',
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
              'pilot feedback, legal notices, and timezone / ABN fields. It is '
              'the hub for admin setup work.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/getting-around/settings.png',
              caption:
                  'Settings — subscription, menu links, and tenant fields.',
            ),
          ],
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
              'Roster shows a staff week board for workers (and filters for '
              'participant, status, and support). Live hides unpublished '
              'drafts; switch status to see drafts when you need them.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/roster-publish/board.png',
              caption:
                  'Roster week board — filters, workers, and live visit cards.',
            ),
          ],
          steps: [
            'Open Roster from the staff nav.',
            'Pick the week with the date arrows, then scan rows for visits.',
            'Use Participant / Status / Support filters to focus the board.',
          ],
        ),
        TutorialSection(
          id: 'compose',
          heading: 'Composing visits and group shifts',
          body:
              'Roster compose walks you through participants, session type '
              '(one session or group), timing, and location before the visit '
              'lands on the board.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/roster-publish/compose.png',
              caption:
                  'Compose step 1 — pick participant and one session or group.',
            ),
          ],
          steps: [
            'From Roster, open compose / add to start a new visit.',
            'Choose One session or Group, then search or browse a participant.',
            'Continue through the steps for time and location, then review.',
          ],
        ),
        TutorialSection(
          id: 'publish',
          heading: 'Publishing the week',
          body:
              'Once published, a shift shows status Published with support item, '
              'assignments, and travel. Workers can see assigned visits; you can '
              'still open shift detail to adjust or cancel.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/roster-publish/publish.png',
              caption:
                  'Shift detail — Published status, NDIS item, and assignments.',
            ),
          ],
          steps: [
            'Publish when the week looks correct so workers see assigned visits.',
            'Open a shift card from the board to review item, people, and travel.',
            'Use Release / Cancel only when you need to change a published shift.',
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
              'Participants are the people you support. The list shows active '
              'clients with contact details and sites; open a row for the full '
              'profile used when you roster.',
          images: [
            TutorialImage(
              assetPath:
                  'assets/tutorials/participants-workers/participants.png',
              caption:
                  'Participants list — search, filters, and Add participant.',
            ),
          ],
          steps: [
            'Open Participants from the staff nav.',
            'Use Search or Show incomplete / Show archived to find someone.',
            'Tap Add participant to create a record, or open a row for profile details.',
          ],
        ),
        TutorialSection(
          id: 'workers',
          heading: 'Support workers',
          body:
              'Support workers (contractors) clock in, write notes, and appear '
              'on the roster. Filter by status (invited, pending docs, active, '
              'and more) and invite new workers from this list.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/participants-workers/workers.png',
              caption:
                  'Support workers list — status filters and Invite.',
            ),
          ],
          steps: [
            'Open Support workers from the staff nav.',
            'Use status filters to find invited, pending, or active workers.',
            'Tap Invite to email a new worker, or open a row for engagement details.',
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
              'Attendance & variance lists exceptions (geofence, late check-in, '
              'and more). Filter the queue, then Approve or Reject each item.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/attendance-review/review-list.png',
              caption:
                  'Attendance & variance — exception cards with Approve / Reject.',
            ),
          ],
          steps: [
            'Open Attendance review from the staff nav.',
            'Filter All / Location exceptions / Schedule variances / Sync conflicts.',
            'Read the card (worker, participant, variance), then Approve or Reject.',
            'Open the visit when you need scheduled vs actual times and GPS detail.',
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
              'Payments lists payment batches by period and status (draft, '
              'posted, void). Create a batch when you are ready to group '
              'payable work for a pay run.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/payments-csv/payments.png',
              caption:
                  'Payments — batch list with status and Create Batch.',
            ),
          ],
          steps: [
            'Open Payments from the staff nav.',
            'Scan existing batches (draft / posted / void) and filter by status.',
            'Use Create Batch when you are ready to group payable visits.',
          ],
        ),
        TutorialSection(
          id: 'billing',
          heading: 'Plan-manager CSV exports',
          body:
              'Billing → Invoice exports lists claim/export batches with status '
              '(finalized, void) and amounts. Create an export when attendance '
              'and notes are clean.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/payments-csv/billing.png',
              caption:
                  'Invoice exports — export list, Create, and billing monitors.',
            ),
          ],
          steps: [
            'Open Billing from the staff nav to see Invoice exports.',
            'Use Create when you are ready to build a plan-manager export.',
            'Open a row to download or review lines; fix attendance first if needed.',
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
              'Staff members are tenant users with login access — not support '
              'workers in the field. Filter by job title; each row shows role '
              'and Active status.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/staff-permissions/staff.png',
              caption:
                  'Staff directory — role filters and Add staff.',
            ),
          ],
          steps: [
            'Open Staff from the staff nav.',
            'Use job-title tabs to filter the directory.',
            'Tap Add staff to invite someone; they complete invite / password setup.',
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
              'Xero lives under Settings → Integrations. When connected, you '
              'see the organisation name and can Refresh or Disconnect. Worker '
              'mappings sit on the same page.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/xero-timesheets/xero-connect.png',
              caption:
                  'Xero settings — Connected status and worker mappings.',
            ),
          ],
          steps: [
            'Go to Settings → Integrations → Xero.',
            'Connect your Xero organisation (OAuth) until status shows Connected.',
            'Map workers (and pay items) so batch exports match payroll.',
          ],
        ),
        TutorialSection(
          id: 'export',
          heading: 'Export timesheets',
          body:
              'Map pay-item bands (Base, Night, Saturday, etc.) to Xero Ordinary '
              'Hours or Overtime. Posted payment batches then send to Xero '
              'Payroll as drafts — finish pay in Xero.',
          images: [
            TutorialImage(
              assetPath: 'assets/tutorials/xero-timesheets/xero-sent.png',
              caption:
                  'Payment batch detail — Sent to Xero (hours as drafts).',
            ),
            TutorialImage(
              assetPath: 'assets/tutorials/xero-timesheets/xero-export.png',
              caption:
                  'Xero Pay items — map bands to Ordinary Hours or Overtime.',
            ),
          ],
          steps: [
            'On Xero settings, open the Pay items tab and map each used band.',
            'Ensure workers on the batch are mapped under the Workers tab.',
            'Open a posted payment batch and tap Send to Xero.',
            'When status shows Sent to Xero, finish payroll in Xero (drafts).',
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
