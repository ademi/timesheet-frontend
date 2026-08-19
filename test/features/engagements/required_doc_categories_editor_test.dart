import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/credentials/data/models/credential_models.dart';
import 'package:rostiq/features/engagements/widgets/required_doc_categories_editor.dart';

void main() {
  testWidgets('tap chip calls onToggle with category code', (tester) async {
    String? toggled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RequiredDocCategoriesEditor(
            choices: const [
              CredentialCategory(code: 'first_aid', label: 'First aid'),
              CredentialCategory(code: 'cpr', label: 'CPR'),
            ],
            selected: const {'first_aid'},
            canEdit: true,
            isEnded: false,
            onToggle: (code) => toggled = code,
            onSave: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('CPR'));
    await tester.pump();

    expect(toggled, 'cpr');
  });
}
