import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/utils/participant_display.dart';

class _NamedParticipant {
  const _NamedParticipant({required this.status, required this.name});

  final String status;
  final String name;
}

void main() {
  group('activeParticipants', () {
    test('keeps only status == active', () {
      final all = [
        const _NamedParticipant(status: 'active', name: 'Maya'),
        const _NamedParticipant(status: 'removed', name: 'Jordan'),
        const _NamedParticipant(status: 'active', name: 'Alex'),
      ];

      final active = activeParticipants(all);
      expect(active.map((p) => p.name), ['Maya', 'Alex']);
    });

    test('supports map rows with status key', () {
      final active = activeParticipants([
        {'status': 'active', 'name': 'Maya'},
        {'status': 'removed', 'name': 'Jordan'},
      ]);
      expect(active, [
        {'status': 'active', 'name': 'Maya'},
      ]);
    });
  });

  group('staffParticipantLabel', () {
    test('formats workerCount:n', () {
      expect(staffParticipantLabel(2, 3), '2:3');
      expect(staffParticipantLabel(1, 1), '1:1');
    });
  });

  group('rosterTileLabel', () {
    test('single name uses first name', () {
      expect(rosterTileLabel(['Maya Smith']), 'Maya');
    });

    test('two names use first names', () {
      expect(rosterTileLabel(['Maya Smith', 'Jordan Lee']), 'Maya, Jordan');
    });

    test('three or more uses two first names then +N more', () {
      expect(
        rosterTileLabel(['Maya Smith', 'Jordan Lee', 'Alex Kim']),
        'Maya, Jordan +1 more',
      );
      expect(
        rosterTileLabel([
          'Maya Smith',
          'Jordan Lee',
          'Alex Kim',
          'Sam Park',
        ]),
        'Maya, Jordan +2 more',
      );
    });

    test('first-name collision in visible set uses truncated full names', () {
      expect(
        rosterTileLabel(['Maya Smith', 'Maya Jones']),
        'Maya S, Maya J',
      );
      expect(
        rosterTileLabel(['Maya Smith', 'Maya Jones', 'Alex Kim']),
        'Maya S, Maya J +1 more',
      );
    });

    test('collision only applies within visible pair', () {
      expect(
        rosterTileLabel(['Maya Smith', 'Jordan Lee', 'Maya Jones']),
        'Maya, Jordan +1 more',
      );
    });
  });
}
