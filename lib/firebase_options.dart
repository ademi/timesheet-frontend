// File generated from android/app/google-services.json.
// Regenerate with `flutterfire configure` when adding iOS/web Firebase apps.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Default [FirebaseOptions] for this project, keyed by platform.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    final options = maybeCurrentPlatform;
    if (options != null) return options;
    throw UnsupportedError(
      'DefaultFirebaseOptions are not configured for this platform. '
      'Run `flutterfire configure` to add platform support.',
    );
  }

  /// Same as [currentPlatform], or `null` when this platform has no config.
  static FirebaseOptions? get maybeCurrentPlatform {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return null;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAv7HB0e8cI0lDsfhyy2Ij5v9P-WxUbfbY',
    appId: '1:1069388513052:android:373db5c4b0f1d32af9c4d9',
    messagingSenderId: '1069388513052',
    projectId: 'temp-timesheet',
    storageBucket: 'temp-timesheet.firebasestorage.app',
  );
}
