import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/app/themes/app_colors.dart';
import 'package:rostiq/features/credentials/widgets/credential_provenance_chip.dart';

void main() {
  test('credentialProvenanceLabel maps known wire codes', () {
    expect(
      credentialProvenanceLabel('reviewer_sighted'),
      'Accepted by reviewer',
    );
    expect(credentialProvenanceLabel('contractor_asserted'), 'Awaiting review');
    expect(credentialProvenanceLabel('verified'), 'Verified');
    expect(credentialProvenanceLabel('self_reported'), 'Self reported');
  });

  test('credentialProvenanceColor uses green for accepted review', () {
    expect(
      credentialProvenanceColor('reviewer_sighted'),
      AppColors.success,
    );
    expect(credentialProvenanceColor('rejected'), AppColors.error);
    expect(
      credentialProvenanceColor('contractor_asserted'),
      const Color(0xFFEA580C),
    );
  });

  testWidgets('chip shows human label not underscore code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CredentialProvenanceChip(provenance: 'reviewer_sighted'),
        ),
      ),
    );

    expect(find.text('Accepted by reviewer'), findsOneWidget);
    expect(find.textContaining('reviewer_sighted'), findsNothing);
  });
}
