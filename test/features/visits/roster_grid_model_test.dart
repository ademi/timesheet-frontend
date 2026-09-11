import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/visits/data/models/roster_overlay_models.dart';
import 'package:rostiq/features/visits/roster/roster_grid_model.dart';

void main() {
  group('buildRosterGrid', () {
    test('builds Unfilled row first and places open-slot tiles', () {
      final monday = DateTime(2026, 8, 10, 9);
      final shift = ShiftOut(
        id: 's1',
        tenantId: 't',
        jobId: 'j',
        jobTitle: 'Sam support',
        clientId: 'cl',
        clientName: 'Sam',
        scheduledStart: monday,
        scheduledEnd: monday.add(const Duration(hours: 3)),
        requiredSlots: 2,
        openSlots: 1,
        status: 'published',
        assignments: [
          ShiftAssignmentOut(
            id: 'a1',
            contractorId: 'jane',
            contractorName: 'Jane',
            visitId: 'v1',
            source: 'staff_assign',
            status: 'active',
            visitStatus: 'scheduled',
          ),
        ],
        createdAt: monday,
        updatedAt: monday,
      );
      final grid = buildRosterGrid(
        rangeStart: DateTime(2026, 8, 10),
        dayCount: 5,
        shifts: [shift],
        people: const [
          RosterPerson(contractorId: 'jane', displayName: 'Jane'),
          RosterPerson(contractorId: 'ali', displayName: 'Ali'),
        ],
        overlay: const RosterOverlayOut(contractors: []),
      );
      expect(grid.rows.first.id, 'unfilled');
      expect(grid.rows.first.isUnfilled, isTrue);
      expect(grid.rows.first.cells[0].tiles, isNotEmpty);
      final jane = grid.rows.firstWhere((r) => r.id == 'jane');
      expect(jane.cells[0].tiles.single.clientName, 'Sam');
      expect(jane.cells[0].tiles.single.visitStatus, 'scheduled');
    });

    test('leave marks cell on person row', () {
      final grid = buildRosterGrid(
        rangeStart: DateTime(2026, 8, 10),
        dayCount: 5,
        shifts: const [],
        people: const [RosterPerson(contractorId: 'jane', displayName: 'Jane')],
        overlay: RosterOverlayOut(
          contractors: [
            ContractorRosterOverlay(
              contractorId: 'jane',
              displayName: 'Jane',
              leave: [
                LeaveIntervalOut(
                  startDate: DateTime(2026, 8, 13),
                  endDate: DateTime(2026, 8, 13),
                  leaveType: 'sick',
                ),
              ],
            ),
          ],
        ),
      );
      final jane = grid.rows.firstWhere((r) => r.id == 'jane');
      expect(jane.cells[3].onLeave, isTrue); // Thu 13
      expect(jane.cells[0].onLeave, isFalse);
    });

    test('client filter drops other clients', () {
      final monday = DateTime(2026, 8, 10, 9);
      final shiftA = ShiftOut(
        id: 's-a',
        tenantId: 't',
        jobId: 'j',
        jobTitle: 'A support',
        clientId: 'cl-a',
        clientName: 'Client A',
        scheduledStart: monday,
        scheduledEnd: monday.add(const Duration(hours: 2)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        createdAt: monday,
        updatedAt: monday,
      );
      final shiftB = ShiftOut(
        id: 's-b',
        tenantId: 't',
        jobId: 'j',
        jobTitle: 'B support',
        clientId: 'cl-b',
        clientName: 'Client B',
        scheduledStart: monday,
        scheduledEnd: monday.add(const Duration(hours: 2)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        createdAt: monday,
        updatedAt: monday,
      );
      final grid = buildRosterGrid(
        rangeStart: DateTime(2026, 8, 10),
        dayCount: 5,
        shifts: [shiftA, shiftB],
        people: const [],
        overlay: const RosterOverlayOut(contractors: []),
        clientIdFilter: 'cl-a',
      );
      final unfilled = grid.rows.first;
      expect(unfilled.cells[0].tiles, hasLength(1));
      expect(unfilled.cells[0].tiles.single.shiftId, 's-a');
    });

    test('client filter keeps non-host participant shifts', () {
      final monday = DateTime(2026, 8, 10, 9);
      final hostOnly = ShiftOut(
        id: 's-host',
        tenantId: 't',
        jobId: 'j',
        jobTitle: 'Host support',
        clientId: 'host',
        clientName: 'Host Client',
        scheduledStart: monday,
        scheduledEnd: monday.add(const Duration(hours: 2)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        createdAt: monday,
        updatedAt: monday,
      );
      final groupShift = ShiftOut(
        id: 's-group',
        tenantId: 't',
        jobId: 'j',
        jobTitle: 'Group',
        clientId: 'host',
        clientName: 'Host Client',
        scheduledStart: monday,
        scheduledEnd: monday.add(const Duration(hours: 2)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        participants: const [
          ShiftParticipantOut(
            id: 'sp1',
            participantId: 'maya',
            participantName: 'Maya Smith',
            status: 'active',
          ),
          ShiftParticipantOut(
            id: 'sp2',
            participantId: 'jordan',
            participantName: 'Jordan Lee',
            status: 'active',
          ),
        ],
        createdAt: monday,
        updatedAt: monday,
      );
      final grid = buildRosterGrid(
        rangeStart: DateTime(2026, 8, 10),
        dayCount: 5,
        shifts: [hostOnly, groupShift],
        people: const [],
        overlay: const RosterOverlayOut(contractors: []),
        clientIdFilter: 'maya',
      );
      final unfilled = grid.rows.first;
      expect(unfilled.cells[0].tiles, hasLength(1));
      expect(unfilled.cells[0].tiles.single.shiftId, 's-group');
      expect(unfilled.cells[0].tiles.single.clientName, 'Maya, Jordan');
    });

    test('tile label uses active participants then host fallback', () {
      final monday = DateTime(2026, 8, 10, 9);
      final withParticipants = ShiftOut(
        id: 's-p',
        tenantId: 't',
        jobId: 'j',
        jobTitle: 'Group',
        clientId: 'host',
        clientName: 'Host Client',
        scheduledStart: monday,
        scheduledEnd: monday.add(const Duration(hours: 2)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        participants: const [
          ShiftParticipantOut(
            id: 'sp1',
            participantId: 'maya',
            participantName: 'Maya Smith',
            status: 'active',
          ),
          ShiftParticipantOut(
            id: 'sp2',
            participantId: 'jordan',
            participantName: 'Jordan Lee',
            status: 'active',
          ),
          ShiftParticipantOut(
            id: 'sp3',
            participantId: 'alex',
            participantName: 'Alex Kim',
            status: 'active',
          ),
          ShiftParticipantOut(
            id: 'sp-rm',
            participantId: 'gone',
            participantName: 'Removed Person',
            status: 'removed',
          ),
        ],
        createdAt: monday,
        updatedAt: monday,
      );
      final hostOnly = ShiftOut(
        id: 's-host',
        tenantId: 't',
        jobId: 'j',
        jobTitle: 'One',
        clientId: 'host',
        clientName: 'Host Client',
        scheduledStart: monday.add(const Duration(days: 1)),
        scheduledEnd: monday.add(const Duration(days: 1, hours: 2)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        createdAt: monday,
        updatedAt: monday,
      );
      expect(rosterShiftTileLabel(withParticipants), 'Maya, Jordan +1 more');
      expect(rosterShiftTileLabel(hostOnly), 'Host Client');

      final grid = buildRosterGrid(
        rangeStart: DateTime(2026, 8, 10),
        dayCount: 5,
        shifts: [withParticipants, hostOnly],
        people: const [],
        overlay: const RosterOverlayOut(contractors: []),
      );
      final unfilled = grid.rows.first;
      expect(unfilled.cells[0].tiles.single.clientName, 'Maya, Jordan +1 more');
      expect(unfilled.cells[1].tiles.single.clientName, 'Host Client');
    });

    test(
      'includes draft/cancelled shifts passed in and sorts people by name',
      () {
        final monday = DateTime(2026, 8, 10, 9);
        final draft = ShiftOut(
          id: 'draft',
          tenantId: 't',
          jobId: 'j',
          jobTitle: 'Draft',
          clientId: 'cl',
          clientName: 'Unpublished',
          scheduledStart: monday,
          scheduledEnd: monday.add(const Duration(hours: 1)),
          requiredSlots: 1,
          openSlots: 1,
          status: 'draft',
          createdAt: monday,
          updatedAt: monday,
        );
        final cancelled = ShiftOut(
          id: 'cancelled',
          tenantId: 't',
          jobId: 'j',
          jobTitle: 'Cancelled',
          clientId: 'cl',
          clientName: 'Cancelled Client',
          scheduledStart: monday.add(const Duration(days: 1)),
          scheduledEnd: monday.add(const Duration(days: 1, hours: 1)),
          requiredSlots: 1,
          openSlots: 1,
          status: 'cancelled',
          createdAt: monday,
          updatedAt: monday,
        );
        final grid = buildRosterGrid(
          rangeStart: DateTime(2026, 8, 10),
          dayCount: 3,
          shifts: [draft, cancelled],
          people: const [
            RosterPerson(contractorId: 'zoe', displayName: 'Zoe'),
            RosterPerson(contractorId: 'ali', displayName: 'Ali'),
          ],
          overlay: const RosterOverlayOut(contractors: []),
        );
        expect(grid.rows.first.id, 'unfilled');
        expect(grid.rows.first.cells[0].tiles.single.shiftId, 'draft');
        expect(grid.rows.first.cells[1].tiles.single.shiftId, 'cancelled');
        expect(grid.rows.skip(1).map((r) => r.id).toList(), ['ali', 'zoe']);
      },
    );

    test('sets availability hint from overlay day-of-week', () {
      final grid = buildRosterGrid(
        rangeStart: DateTime(2026, 8, 10),
        dayCount: 5,
        shifts: const [],
        people: const [RosterPerson(contractorId: 'jane', displayName: 'Jane')],
        overlay: RosterOverlayOut(
          contractors: [
            ContractorRosterOverlay(
              contractorId: 'jane',
              displayName: 'Jane',
              availability: const [
                AvailabilityRuleOut(
                  dayOfWeek: 0,
                  startTime: '09:00:00',
                  endTime: '17:00:00',
                ),
              ],
            ),
          ],
        ),
      );
      final jane = grid.rows.firstWhere((r) => r.id == 'jane');
      expect(jane.cells[0].availabilityHint, '09:00–17:00');
      expect(jane.cells[1].availabilityHint, isNull);
    });

    test('UTC Sunday evening shift buckets to Monday local column', () {
      // Mon 09:00 AEST = Sun 23:00Z. API payloads are UTC; week chrome is local.
      final utcSundayEvening = DateTime.utc(2026, 8, 9, 23);
      final localMonday = DateTime(2026, 8, 10);
      expect(
        DateTime(
          utcSundayEvening.toLocal().year,
          utcSundayEvening.toLocal().month,
          utcSundayEvening.toLocal().day,
        ),
        localMonday,
        reason: 'device TZ must place Sun 23:00Z on local Monday',
      );

      final shift = ShiftOut(
        id: 's-utc',
        tenantId: 't',
        jobId: 'j',
        jobTitle: 'Morning',
        clientId: 'cl',
        clientName: 'Sam',
        scheduledStart: utcSundayEvening,
        scheduledEnd: utcSundayEvening.add(const Duration(hours: 3)),
        requiredSlots: 1,
        openSlots: 1,
        status: 'published',
        createdAt: utcSundayEvening,
        updatedAt: utcSundayEvening,
      );
      final grid = buildRosterGrid(
        rangeStart: localMonday,
        dayCount: 5,
        shifts: [shift],
        people: const [],
        overlay: const RosterOverlayOut(contractors: []),
      );
      final unfilled = grid.rows.first;
      expect(unfilled.cells[0].tiles, hasLength(1));
      expect(unfilled.cells[0].tiles.single.shiftId, 's-utc');
      for (var i = 1; i < 5; i++) {
        expect(unfilled.cells[i].tiles, isEmpty);
      }
    });
  });
}
