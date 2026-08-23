import '../../visits/data/models/visit_models.dart';
import '../../visits/utils/visit_billing_utils.dart';

enum VisitExportCheckStatus { ok, warn, block }

class VisitExportCheck {
  const VisitExportCheck({
    required this.label,
    required this.status,
    this.detail,
  });

  final String label;
  final VisitExportCheckStatus status;
  final String? detail;
}

class VisitExportPreflight {
  const VisitExportPreflight({
    required this.visit,
    required this.checks,
  });

  final VisitOut visit;
  final List<VisitExportCheck> checks;

  bool get isReady =>
      checks.every((c) => c.status != VisitExportCheckStatus.block);

  bool get hasWarnings =>
      checks.any((c) => c.status == VisitExportCheckStatus.warn);
}

VisitExportPreflight buildVisitExportPreflight(VisitOut visit) {
  final checks = <VisitExportCheck>[];

  if (visit.status != 'completed') {
    checks.add(
      const VisitExportCheck(
        label: 'Visit completed',
        status: VisitExportCheckStatus.block,
        detail: 'Only completed visits can be exported.',
      ),
    );
  } else {
    checks.add(
      const VisitExportCheck(
        label: 'Visit completed',
        status: VisitExportCheckStatus.ok,
      ),
    );
  }

  final coded = visitHasCodedTasks(visit);
  if (coded) {
    final missingMinutes = visit.tasks.where((task) {
      final code = task.supportItemCode?.trim();
      return code != null && code.isNotEmpty && task.billableMinutes == null;
    }).toList();
    if (missingMinutes.isNotEmpty) {
      checks.add(
        VisitExportCheck(
          label: 'Task billable minutes',
          status: VisitExportCheckStatus.block,
          detail:
              '${missingMinutes.length} coded task(s) need billable minutes.',
        ),
      );
    } else {
      checks.add(
        const VisitExportCheck(
          label: 'Task billable minutes',
          status: VisitExportCheckStatus.ok,
        ),
      );
    }
    if (taskMinutesExceedVisitDuration(visit)) {
      checks.add(
        VisitExportCheck(
          label: 'Task minutes within visit duration',
          status: VisitExportCheckStatus.block,
          detail:
              'Coded task minutes (${codedTaskBillableMinutesTotal(visit)}) '
              'exceed scheduled duration '
              '(${visitScheduledDurationMinutes(visit)} min).',
        ),
      );
    } else {
      checks.add(
        const VisitExportCheck(
          label: 'Task minutes within visit duration',
          status: VisitExportCheckStatus.ok,
        ),
      );
    }
  } else {
    final code = visit.supportItemCode?.trim();
    if (code == null || code.isEmpty) {
      checks.add(
        const VisitExportCheck(
          label: 'Visit support item',
          status: VisitExportCheckStatus.block,
          detail: 'Set a visit-level NDIS support item, or code tasks.',
        ),
      );
    } else {
      checks.add(
        const VisitExportCheck(
          label: 'Visit support item',
          status: VisitExportCheckStatus.ok,
        ),
      );
    }
  }

  if (visit.priceTierOverride?.trim().isNotEmpty == true) {
    checks.add(
      VisitExportCheck(
        label: 'Price tier',
        status: VisitExportCheckStatus.ok,
        detail: 'Staff override: ${visit.priceTierOverride}.',
      ),
    );
  } else {
    checks.add(
      const VisitExportCheck(
        label: 'Price tier / postcode',
        status: VisitExportCheckStatus.warn,
        detail:
            'No tier override — export uses MMM postcode on the job location. '
            'Missing postcode fails unless you set an override on the visit.',
      ),
    );
  }

  checks.add(
    const VisitExportCheck(
      label: 'Closed time entry',
      status: VisitExportCheckStatus.warn,
      detail: 'Verified by the server when exporting.',
    ),
  );

  return VisitExportPreflight(visit: visit, checks: checks);
}

bool selectedVisitsExportReady(
  Iterable<VisitOut> visits,
  Set<String> excludedVisitIds,
) {
  for (final visit in visits) {
    if (excludedVisitIds.contains(visit.id)) continue;
    if (!buildVisitExportPreflight(visit).isReady) return false;
  }
  return true;
}
