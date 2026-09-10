import '../data/models/shift_participant_models.dart';

List<ShiftParticipantOut> activeParticipants(List<ShiftParticipantOut> all) =>
    all.where((p) => p.isActive).toList(growable: false);

double sumActivePercentage(List<ShiftParticipantOut> all) {
  var sum = 0.0;
  for (final p in activeParticipants(all)) {
    if (p.allocationStrategy == 'percentage') {
      sum += p.allocationValue;
    }
  }
  return sum;
}

double remainingPercentage(List<ShiftParticipantOut> all) =>
    100 - sumActivePercentage(all);

bool isPublishReadyPercentage(List<ShiftParticipantOut> all) {
  final active = activeParticipants(all);
  if (active.isEmpty) return false;
  if (active.any((p) => p.allocationStrategy != 'percentage')) return false;
  final sum = sumActivePercentage(all);
  return (sum - 100).abs() < 0.01;
}

bool isPublishReadyTimeBased(List<ShiftParticipantOut> all) {
  final active = activeParticipants(all);
  if (active.isEmpty) return false;
  if (active.any((p) => p.allocationStrategy != 'time_based')) return false;
  return active.every((p) => (p.timeWindows?.isNotEmpty ?? false));
}

bool isPublishReady(List<ShiftParticipantOut> all) {
  final active = activeParticipants(all);
  if (active.isEmpty) return false;
  final strategy = active.first.allocationStrategy;
  if (strategy == 'percentage') return isPublishReadyPercentage(all);
  if (strategy == 'time_based') return isPublishReadyTimeBased(all);
  return false;
}

String participantLabel({
  required String participantId,
  required Map<String, String> idToName,
  String? hostClientId,
}) {
  final name = idToName[participantId] ?? 'Participant';
  if (hostClientId != null && participantId == hostClientId) {
    return '$name (host)';
  }
  return name;
}

String rosterParticipantsLabel({
  required String? hostClientName,
  required List<ShiftParticipantOut> participants,
  required Map<String, String> idToName,
}) {
  final active = activeParticipants(participants);
  if (active.isEmpty) return hostClientName ?? '';
  final names = active
      .map((p) => idToName[p.participantId] ?? 'Participant')
      .toList(growable: false);
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} + ${names[1]}';
  return '${names[0]} +${names.length - 1}';
}
