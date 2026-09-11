import '../../clients/data/models/client_models.dart';

/// Route args for [AppRoutes.staffGroupShiftBook].
///
/// Design D11: roster client filter prefills a **participant** only; host stays
/// empty and Include-host stays off.
class GroupShiftBookArgs {
  const GroupShiftBookArgs({
    this.participantId,
    this.participantName,
    this.participant,
  });

  final String? participantId;
  final String? participantName;
  final ClientOut? participant;

  factory GroupShiftBookArgs.fromMap(Map<dynamic, dynamic> map) {
    return GroupShiftBookArgs(
      participantId: map['participantId']?.toString() ??
          map['participant_id']?.toString(),
      participantName: map['participantName']?.toString() ??
          map['participant_name']?.toString(),
      participant: map['participant'] is ClientOut
          ? map['participant'] as ClientOut
          : null,
    );
  }
}
