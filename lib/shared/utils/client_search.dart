import 'package:flutter/painting.dart';

import '../../features/clients/data/models/client_models.dart';

/// Lightweight candidate for in-memory client search / ranking.
class ClientSearchCandidate {
  const ClientSearchCandidate({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.subtitle,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? subtitle;

  factory ClientSearchCandidate.fromClient(ClientOut client) {
    final parts = <String>[
      if (client.email != null && client.email!.trim().isNotEmpty)
        client.email!.trim(),
      if (client.phone != null && client.phone!.trim().isNotEmpty)
        client.phone!.trim(),
      if (client.primaryDisplayAddress.isNotEmpty) client.primaryDisplayAddress,
    ];
    return ClientSearchCandidate(
      id: client.id,
      fullName: client.fullName,
      email: client.email,
      phone: client.phone,
      subtitle: parts.isEmpty ? null : parts.join(' · '),
    );
  }

  factory ClientSearchCandidate.fromIdName({
    required String id,
    required String name,
  }) {
    return ClientSearchCandidate(id: id, fullName: name);
  }
}

/// Result of [searchClients] including truncation metadata.
class ClientSearchResult {
  const ClientSearchResult({
    required this.items,
    required this.totalMatches,
    required this.limit,
  });

  final List<ClientSearchCandidate> items;
  final int totalMatches;
  final int limit;

  bool get isTruncated => totalMatches > items.length;
}

/// Digits-only phone key for fuzzy compare (`+61 412` ↔ `0412`).
String normalizePhoneDigits(String? raw) {
  if (raw == null) return '';
  return raw.replaceAll(RegExp(r'\D'), '');
}

/// Ranked local client search.
///
/// Ranking (lower is better): name starts-with → any name-token starts-with →
/// name contains → email/phone contains. Empty [query] returns [].
ClientSearchResult searchClients({
  required Iterable<ClientSearchCandidate> candidates,
  required String query,
  int limit = 20,
  Set<String> excludeIds = const {},
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    return ClientSearchResult(items: const [], totalMatches: 0, limit: limit);
  }

  final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final phoneQ = normalizePhoneDigits(q);
  final scored = <({ClientSearchCandidate c, int rank, String name})>[];
  final seen = <String>{};

  for (final c in candidates) {
    if (excludeIds.contains(c.id) || !seen.add(c.id)) continue;
    final rank = _matchRank(c, q, tokens, phoneQ);
    if (rank == null) continue;
    scored.add((c: c, rank: rank, name: c.fullName.toLowerCase()));
  }

  scored.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    final byName = a.name.compareTo(b.name);
    if (byName != 0) return byName;
    return a.c.id.compareTo(b.c.id);
  });

  final total = scored.length;
  final items = [
    for (final row in scored.take(limit < 1 ? 0 : limit)) row.c,
  ];
  return ClientSearchResult(items: items, totalMatches: total, limit: limit);
}

/// Idle browse list: recents first (when still in [candidates]), then A–Z fill.
List<ClientSearchCandidate> browseClients({
  required Iterable<ClientSearchCandidate> candidates,
  List<String> recentIds = const [],
  int limit = 8,
  Set<String> excludeIds = const {},
}) {
  if (limit < 1) return const [];
  final byId = <String, ClientSearchCandidate>{};
  for (final c in candidates) {
    if (excludeIds.contains(c.id)) continue;
    byId.putIfAbsent(c.id, () => c);
  }

  final out = <ClientSearchCandidate>[];
  final used = <String>{};
  for (final id in recentIds) {
    final c = byId[id];
    if (c == null || !used.add(id)) continue;
    out.add(c);
    if (out.length >= limit) return out;
  }

  final rest = byId.values.toList()
    ..sort((a, b) {
      final byName = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      if (byName != 0) return byName;
      return a.id.compareTo(b.id);
    });
  for (final c in rest) {
    if (!used.add(c.id)) continue;
    out.add(c);
    if (out.length >= limit) break;
  }
  return out;
}

/// Subtitle for picker rows when not precomputed.
String clientSearchSubtitle(ClientSearchCandidate client) {
  if (client.subtitle != null && client.subtitle!.isNotEmpty) {
    return client.subtitle!;
  }
  final parts = <String>[
    if (client.email != null && client.email!.trim().isNotEmpty)
      client.email!.trim(),
    if (client.phone != null && client.phone!.trim().isNotEmpty)
      client.phone!.trim(),
  ];
  if (parts.isNotEmpty) return parts.join(' · ');
  final id = client.id;
  return id.length > 8 ? id.substring(0, 8) : id;
}

/// Highlight [query] inside [text] (case-insensitive first match).
InlineSpan highlightQuerySpan({
  required String text,
  required String query,
  required TextStyle base,
  required TextStyle highlight,
}) {
  final q = query.trim();
  if (q.isEmpty) return TextSpan(text: text, style: base);
  final lower = text.toLowerCase();
  final qi = lower.indexOf(q.toLowerCase());
  if (qi < 0) return TextSpan(text: text, style: base);
  return TextSpan(
    style: base,
    children: [
      if (qi > 0) TextSpan(text: text.substring(0, qi)),
      TextSpan(text: text.substring(qi, qi + q.length), style: highlight),
      if (qi + q.length < text.length)
        TextSpan(text: text.substring(qi + q.length)),
    ],
  );
}

int? _matchRank(
  ClientSearchCandidate c,
  String q,
  List<String> tokens,
  String phoneQ,
) {
  final name = c.fullName.toLowerCase();
  if (name.startsWith(q)) return 0;

  final nameTokens = name.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  if (tokens.every((t) => nameTokens.any((nt) => nt.startsWith(t)))) {
    return 1;
  }
  if (tokens.every((t) => name.contains(t))) return 2;

  final email = c.email?.toLowerCase() ?? '';
  if (email.contains(q)) return 3;

  final phoneDigits = normalizePhoneDigits(c.phone);
  if (phoneQ.isNotEmpty &&
      phoneDigits.isNotEmpty &&
      phoneDigits.contains(phoneQ)) {
    return 4;
  }
  final phoneRaw = c.phone?.toLowerCase() ?? '';
  if (phoneRaw.contains(q)) return 4;

  return null;
}
