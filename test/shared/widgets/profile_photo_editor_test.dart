import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/widgets/profile_photo_editor.dart';

void main() {
  testWidgets('ProfilePhotoEditor wraps content in InputDecorator label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfilePhotoEditor(label: 'Profile photo', showLabel: true),
        ),
      ),
    );
    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.byType(InputDecorator), findsOneWidget);
  });

  testWidgets('readOnly avatar skips InputDecorator chrome', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProfilePhotoEditor(
            readOnly: true,
            showLabel: false,
            size: 48,
          ),
        ),
      ),
    );
    expect(find.byType(InputDecorator), findsNothing);
    expect(find.byType(CircleAvatar), findsOneWidget);
  });
}
