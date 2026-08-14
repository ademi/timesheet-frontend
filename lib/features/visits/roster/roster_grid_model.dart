import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';

class RosterPerson {
  const RosterPerson({required this.contractorId, required this.displayName});

  final String contractorId;
  final String displayName;
}

class RosterTile {
  const RosterTile({
    required this.shiftId,
    required this.clientName,
    required this.start,
    required this.end,
    required this.openSlots,
    required this.requiredSlots,
    this.visitStatus,
    this.assignmentContractorId,
  });

  final String shiftId;
  final String clientName;
  final DateTime start;
  final DateTime end;
  final int openSlots;
  final int requiredSlots;
  final String? visitStatus;
  final String? assignmentContractorId;
}

class RosterCell {
  const RosterCell({
    this.tiles = const [],
    this.onLeave = false,
    this.availabilityHint,
  });

  final List<RosterTile> tiles;
  final bool onLeave;
  final String? availabilityHint;
}

class RosterRow {
  const RosterRow({
    required this.id,
    required this.label,
    required this.cells,
    this.isUnfilled = false,
  });

  final String id;
  final String label;
  final List<RosterCell> cells;
  final bool isUnfilled;
}

class RosterGrid {
  const RosterGrid({required this.dayStarts, required this.rows});

  final List<DateTime> dayStarts;
  final List<RosterRow> rows;
}

DateTime _startOfDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _dowFromDate(DateTime day) => day.weekday - 1;

int? _dayIndex(List<DateTime> dayStarts, DateTime instant) {
  final day = _startOfDay(instant);
  for (var i = 0; i < dayStarts.length; i++) {
    if (_startOfDay(dayStarts[i]) == day) return i;
  }
  return null;
}

bool _isOnLeave(DateTime day, List<LeaveIntervalOut> leave) {
  final target = _startOfDay(day);
  for (final interval in leave) {
    final start = _startOfDay(interval.startDate);
    final end = _startOfDay(interval.endDate);
    if (!target.isBefore(start) && !target.isAfter(end)) return true;
  }
  return false;
}

String? _availabilityHintForDay(
  DateTime day,
  List<AvailabilityRuleOut> availability,
) {
  final dow = _dowFromDate(day);
  final rules =
      availability.where((rule) => rule.dayOfWeek == dow).toList(growable: false);
  if (rules.isEmpty) return null;

  String trimTime(String value) {
    if (value.length >= 5) return value.substring(0, 5);
    return value;
  }

  return rules
      .map((rule) => '${trimTime(rule.startTime)}–${trimTime(rule.endTime)}')
      .join(', ');
}

ContractorRosterOverlay? _overlayFor(
  RosterOverlayOut overlay,
  String contractorId,
) {
  for (final contractor in overlay.contractors) {
    if (contractor.contractorId == contractorId) return contractor;
  }
  return null;
}

List<RosterCell> _emptyCells(int dayCount) =>
    List.generate(dayCount, (_) => const RosterCell());

RosterGrid buildRosterGrid({
  required DateTime rangeStart,
  required int dayCount,
  required List<ShiftOut> shifts,
  required List<RosterPerson> people,
  required RosterOverlayOut overlay,
  String? clientIdFilter,
}) {
  final dayStarts = List.generate(
    dayCount,
    (i) => _startOfDay(rangeStart.add(Duration(days: i))),
    growable: false,
  );

  // Controller owns status filtering; include every shift passed in.
  final filteredShifts = shifts.where((shift) {
    if (clientIdFilter == null || clientIdFilter.isEmpty) return true;
    return shift.clientId == clientIdFilter;
  }).toList(growable: false);

  final unfilledCells = _emptyCells(dayCount);
  final unfilledTileCells = List<RosterCell>.from(unfilledCells);

  for (final shift in filteredShifts) {
    if (shift.openSlots <= 0) continue;
    final dayIndex = _dayIndex(dayStarts, shift.scheduledStart);
    if (dayIndex == null) continue;

    final tile = RosterTile(
      shiftId: shift.id,
      clientName: shift.clientName ?? '',
      start: shift.scheduledStart,
      end: shift.scheduledEnd,
      openSlots: shift.openSlots,
      requiredSlots: shift.requiredSlots,
    );
    final cell = unfilledTileCells[dayIndex];
    unfilledTileCells[dayIndex] = RosterCell(
      tiles: [...cell.tiles, tile],
      onLeave: cell.onLeave,
      availabilityHint: cell.availabilityHint,
    );
  }

  final sortedPeople = [...people]
    ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

  final personRows = <RosterRow>[];
  for (final person in sortedPeople) {
    final contractorOverlay = _overlayFor(overlay, person.contractorId);
    final cells = _emptyCells(dayCount);

    for (var dayIndex = 0; dayIndex < dayCount; dayIndex++) {
      final day = dayStarts[dayIndex];
      final onLeave = contractorOverlay != null &&
          _isOnLeave(day, contractorOverlay.leave);
      final availabilityHint = contractorOverlay == null || onLeave
          ? null
          : _availabilityHintForDay(day, contractorOverlay.availability);

      final tiles = <RosterTile>[];
      for (final shift in filteredShifts) {
        final shiftDayIndex = _dayIndex(dayStarts, shift.scheduledStart);
        if (shiftDayIndex != dayIndex) continue;

        for (final assignment in shift.assignments) {
          if (assignment.contractorId != person.contractorId) continue;
          tiles.add(
            RosterTile(
              shiftId: shift.id,
              clientName: shift.clientName ?? '',
              start: shift.scheduledStart,
              end: shift.scheduledEnd,
              openSlots: shift.openSlots,
              requiredSlots: shift.requiredSlots,
              visitStatus: assignment.visitStatus,
              assignmentContractorId: assignment.contractorId,
            ),
          );
        }
      }

      cells[dayIndex] = RosterCell(
        tiles: tiles,
        onLeave: onLeave,
        availabilityHint: availabilityHint,
      );
    }

    personRows.add(
      RosterRow(
        id: person.contractorId,
        label: person.displayName,
        cells: cells,
      ),
    );
  }

  return RosterGrid(
    dayStarts: dayStarts,
    rows: [
      RosterRow(
        id: 'unfilled',
        label: 'Unfilled',
        cells: unfilledTileCells,
        isUnfilled: true,
      ),
      ...personRows,
    ],
  );
}
