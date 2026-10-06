import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/shifts/data/models/shift_models.dart';
import 'package:rostiq/features/shifts/utils/participant_display.dart';

OpenShiftOut _shift({
  String jobTitle = 'Host Support Job',
  String? clientName = 'Host Client',
  String? placeLabel,
  String? locationLabel,
  List<ShiftParticipantOut> participants = const [],
}) {
  return OpenShiftOut(
    id: 's1',
    jobTitle: jobTitle,
    clientName: clientName,
    scheduledStart: DateTime.utc(2026, 10, 6, 9),
    scheduledEnd: DateTime.utc(2026, 10, 6, 12),
    requiredSlots: 1,
    openSlots: 1,
    placeLabel: placeLabel,
    locationLabel: locationLabel,
    participantsSummary: participants,
  );
}

ShiftParticipantOut _participant(String name) => ShiftParticipantOut(
  id: 'sp-$name',
  participantId: 'c-$name',
  status: 'active',
  participantName: name,
);

/// Mirrors open-tab card headline from [_OpenShiftsList].
String openShiftCardHeadline(OpenShiftOut shift) {
  final active = shift.activeParticipantsSummary;
  final headline = placeFirstShiftLabel(
    placeLabel: shift.placeLabel,
    locationLabel: shift.locationLabel,
    participantNames: active.map((p) => p.participantName),
    clientName: shift.clientName,
    jobTitle: shift.jobTitle,
  );
  return headline.isEmpty ? shift.jobTitle : headline;
}

void main() {
  test('open card prefers place · participants over job/host title', () {
    final shift = _shift(
      placeLabel: 'North Centre',
      participants: [_participant('Maya Smith'), _participant('Jordan Lee')],
    );
    expect(openShiftCardHeadline(shift), 'North Centre · Maya, Jordan');
    expect(openShiftCardHeadline(shift), isNot(contains('Host')));
  });

  test('open card uses participants before clientName when no place', () {
    final shift = _shift(participants: [_participant('Maya Smith')]);
    expect(openShiftCardHeadline(shift), 'Maya');
  });

  test('open card falls back to client then job title', () {
    expect(openShiftCardHeadline(_shift()), 'Host Client');
    expect(
      openShiftCardHeadline(_shift(clientName: null)),
      'Host Support Job',
    );
  });
}
