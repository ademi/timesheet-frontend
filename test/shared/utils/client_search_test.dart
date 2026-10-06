import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/data/recent_clients_prefs.dart';
import 'package:rostiq/shared/utils/client_search.dart';

void main() {
  group('normalizePhoneDigits', () {
    test('strips non-digits', () {
      expect(normalizePhoneDigits('+61 412 345 678'), '61412345678');
      expect(normalizePhoneDigits(null), '');
    });
  });

  group('searchClients', () {
    final candidates = [
      const ClientSearchCandidate(
        id: '1',
        fullName: 'Jordan Lee',
        email: 'jordan@ex.com',
        phone: '+61 400 111 222',
      ),
      const ClientSearchCandidate(
        id: '2',
        fullName: 'John Smith',
        email: 'john@ex.com',
        phone: '0412 333 444',
      ),
      const ClientSearchCandidate(
        id: '3',
        fullName: 'Alex Test',
        email: 'alex@ex.com',
      ),
      const ClientSearchCandidate(
        id: '4',
        fullName: 'Sam Jordan',
        email: 'sam@ex.com',
      ),
    ];

    test('empty query returns none', () {
      final r = searchClients(candidates: candidates, query: '');
      expect(r.items, isEmpty);
      expect(r.totalMatches, 0);
    });

    test('ranks name starts-with above contains', () {
      final r = searchClients(candidates: candidates, query: 'jo');
      // John + Jordan both starts-with (A–Z among equals), Sam is token match.
      expect(r.items.map((e) => e.id).toList(), ['2', '1', '4']);
    });

    test('token match finds last-name first-name order', () {
      final r = searchClients(candidates: candidates, query: 'smith j');
      expect(r.items.map((e) => e.id).toList(), ['2']);
    });

    test('phone digits match across formatting', () {
      final r = searchClients(candidates: candidates, query: '0412333');
      expect(r.items.map((e) => e.id).toList(), ['2']);
    });

    test('excludes ids and reports truncation', () {
      final many = [
        for (var i = 0; i < 25; i++)
          ClientSearchCandidate(id: 'a$i', fullName: 'Alex $i'),
      ];
      final r = searchClients(
        candidates: many,
        query: 'alex',
        limit: 20,
        excludeIds: {'a0'},
      );
      expect(r.items.length, 20);
      expect(r.totalMatches, 24);
      expect(r.isTruncated, isTrue);
      expect(r.items.any((e) => e.id == 'a0'), isFalse);
    });
  });

  group('browseClients', () {
    test('puts recents first then A-Z fill', () {
      final candidates = [
        const ClientSearchCandidate(id: 'c', fullName: 'Charlie'),
        const ClientSearchCandidate(id: 'a', fullName: 'Alice'),
        const ClientSearchCandidate(id: 'b', fullName: 'Bob'),
      ];
      final browsed = browseClients(
        candidates: candidates,
        recentIds: ['b'],
        limit: 2,
      );
      expect(browsed.map((e) => e.id).toList(), ['b', 'a']);
    });
  });

  group('highlightQuerySpan', () {
    test('highlights first case-insensitive match', () {
      final span = highlightQuerySpan(
        text: 'Jordan Lee',
        query: 'jor',
        base: const TextStyle(),
        highlight: const TextStyle(fontWeight: FontWeight.bold),
      );
      expect(span, isA<TextSpan>());
      final children = (span as TextSpan).children!;
      expect((children[0] as TextSpan).text, 'Jor');
      expect((children[1] as TextSpan).text, 'dan Lee');
    });
  });

  group('RecentClientsPrefs', () {
    test('records MRU and caps length', () {
      final store = <String, dynamic>{};
      final prefs = RecentClientsPrefs(
        tenantId: 't1',
        maxIds: 3,
        read: (k) => store[k],
        write: (k, v) => store[k] = v,
        remove: store.remove,
      );
      prefs.record('a');
      prefs.record('b');
      prefs.record('c');
      prefs.record('d');
      prefs.record('b');
      expect(prefs.load(), ['b', 'd', 'c']);
    });
  });
}
