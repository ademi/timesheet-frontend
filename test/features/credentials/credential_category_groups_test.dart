import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/credentials/utils/credential_category_groups.dart';

void main() {
  test('groups known codes into sections and sorts labels', () {
    final groups = groupCredentialCategories(const [
      CredentialCategory(code: 'cpr', label: 'CPR'),
      CredentialCategory(code: 'passport_id', label: 'Passport'),
      CredentialCategory(code: 'insurance', label: 'Car Insurance'),
      CredentialCategory(code: 'first_aid', label: 'First Aid'),
      CredentialCategory(code: 'cert_iii', label: 'Certificate III'),
    ]);

    expect(groups.map((g) => g.title).toList(), [
      'Identity',
      'Training & certifications',
      'Qualifications',
      'Vehicle & insurance',
    ]);
    expect(groups[0].items.map((e) => e.code).toList(), ['passport_id']);
    expect(groups[1].items.map((e) => e.label).toList(), [
      'CPR',
      'First Aid',
    ]);
  });

  test('prefers API group label when present', () {
    final groups = groupCredentialCategories(const [
      CredentialCategory(
        code: 'cpr',
        label: 'CPR',
        group: 'Clinical skills',
      ),
      CredentialCategory(code: 'passport_id', label: 'Passport'),
    ]);

    expect(groups.map((g) => g.title), contains('Clinical skills'));
    expect(
      groups.firstWhere((g) => g.title == 'Clinical skills').items.single.code,
      'cpr',
    );
  });

  test('fromJson reads group_label', () {
    final cat = CredentialCategory.fromJson({
      'code': 'wwcc',
      'label': 'Working With Children Check',
      'group_label': 'Screening & checks',
    });
    expect(cat.group, 'Screening & checks');
  });
}
