import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/features/clients/controllers/strengths_needs_controller.dart';
import 'package:rostiq/features/clients/data/models/strengths_needs_models.dart';
import 'package:rostiq/features/clients/data/repositories/clients_repository.dart';
import 'package:rostiq/features/clients/utils/strengths_needs_keys.dart';

class _MockClientsRepository extends Mock implements ClientsRepository {}

final _now = DateTime.utc(2026, 8, 30, 9);

StrengthsNeedsDto _assessment({
  String id = 'sn-1',
  String status = StrengthsNeedsKeys.statusDraft,
  bool isCurrent = false,
  StrengthsNeedsBody? body,
}) {
  return StrengthsNeedsDto(
    id: id,
    clientId: 'client-1',
    status: status,
    isCurrent: isCurrent,
    body: body ??
        StrengthsNeedsBody(
          header: const StrengthsNeedsHeader(participantName: 'Alex'),
          sections: {StrengthsNeedsKeys.livingSkills: 'Independent cooking'},
        ),
    createdAt: _now,
    updatedAt: _now,
  );
}

void main() {
  late _MockClientsRepository mock;
  late StrengthsNeedsController c;

  setUp(() {
    mock = _MockClientsRepository();
    c = StrengthsNeedsController(
      repository: mock,
      clientId: 'client-1',
      assessmentId: 'sn-1',
    );
  });

  tearDown(() {
    c.onClose();
  });

  test('applyLoaded populates section controllers', () {
    c.applyLoaded(_assessment());
    expect(c.participantNameCtrl.text, 'Alex');
    expect(c.sectionCtrls[StrengthsNeedsKeys.livingSkills]!.text,
        'Independent cooking');
    expect(c.status.value, StrengthsNeedsKeys.statusDraft);
  });

  test('buildBody roundtrips header and sections', () {
    c.applyLoaded(_assessment());
    c.sectionCtrls[StrengthsNeedsKeys.challengingBehaviour]!.text =
        'May abscond';
    final body = c.buildBody();
    expect(body.header.participantName, 'Alex');
    expect(body.sections[StrengthsNeedsKeys.challengingBehaviour],
        'May abscond');
  });

  test('default import keys exclude sensitive sections', () {
    for (final key in StrengthsNeedsKeys.sensitiveSectionKeys) {
      expect(StrengthsNeedsKeys.defaultImportKeys, isNot(contains(key)));
    }
  });

  test('submitted assessment is read-only', () {
    c.applyLoaded(
      _assessment(
        status: StrengthsNeedsKeys.statusSubmitted,
        isCurrent: true,
      ),
    );
    expect(c.canEdit, isFalse);
    expect(c.isSubmitted, isTrue);
  });
}
