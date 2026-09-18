import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main (release) manifest does not enable cleartext traffic', () {
    final xml = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      xml.contains('android:usesCleartextTraffic="true"'),
      isFalse,
      reason: 'Release must not allow cleartext (F-fe-002)',
    );
  });

  test('debug manifest enables cleartext for local HTTP API', () {
    final xml = File('android/app/src/debug/AndroidManifest.xml').readAsStringSync();
    expect(
      xml.contains('android:usesCleartextTraffic="true"'),
      isTrue,
      reason: 'Debug builds need cleartext for emulator/LAN HTTP',
    );
  });

  test('profile manifest enables cleartext for local HTTP API', () {
    final xml = File('android/app/src/profile/AndroidManifest.xml').readAsStringSync();
    expect(
      xml.contains('android:usesCleartextTraffic="true"'),
      isTrue,
    );
  });
}
