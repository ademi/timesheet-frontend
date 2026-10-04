import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/sil/data/models/sil_models.dart';

void main() {
  test('silWarningLabel maps ROC drift codes', () {
    expect(silWarningLabel('roc_staffing_richer'), contains('richer'));
    expect(silWarningLabel('roc_staffing_thinner'), contains('thinner'));
    expect(silWarningLabel('roc_participant_drift'), contains('Participant'));
    expect(silWarningLabel('roc_occupancy_absent_on_shift'), contains('vacant'));
    expect(silWarningLabel('unknown_code'), 'unknown_code');
  });
}
