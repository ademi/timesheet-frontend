import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/api_paths.dart';
import '../../firebase_options.dart';

/// Top-level FCM background handler. Must stay top-level (or static) and be
/// annotated so the background isolate can find it.
///
/// Background isolates do not share the main isolate's Firebase apps, so this
/// always initializes Firebase before touching Messaging APIs.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final options = DefaultFirebaseOptions.maybeCurrentPlatform;
  if (options != null && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  } else if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  // Token registration / tap navigation are handled on the main isolate.
  // Keep this handler alive so FlutterFire does not log [core/no-app].
  debugPrint('FCM background message: ${message.messageId}');
}

/// Ensures the default Firebase app exists on the current isolate.
Future<bool> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return true;
  try {
    final options = DefaultFirebaseOptions.maybeCurrentPlatform;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      // Native auto-init (e.g. google-services) may still provide a default app.
      await Firebase.initializeApp();
    }
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Registers FCM/APNs device tokens for both staff and contractor sessions.
///
/// Navigation on notification tap is **not** wired yet. When added, map
/// payload → [AppNavigator.go]/[AppNavigator.push] with [AppRoutes] only —
/// never raw `Get.toNamed` (see Phase 6.3 in the go_router web-only plan).
class PushNotificationService {
  PushNotificationService({required Dio authenticatedDio})
    : _authenticatedDio = authenticatedDio;

  final Dio _authenticatedDio;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final ready = await ensureFirebaseInitialized();
      if (!ready) return;
      await FirebaseMessaging.instance.requestPermission();
      _initialized = true;
    } catch (_) {
      // Keep app functional when Firebase is not configured locally.
    }
  }

  Future<void> registerCurrentDeviceToken() async {
    try {
      await initialize();
      if (!_initialized) return;
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null || token.length < 16) return;
      final platform =
          kIsWeb
              ? 'web'
              : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android';
      await _authenticatedDio.post<Map<String, dynamic>>(
        ApiPaths.notificationDevices,
        data: {'token': token, 'platform': platform},
      );
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> unregisterCurrentDeviceToken() async {
    try {
      await initialize();
      if (!_initialized) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _authenticatedDio.delete<void>(ApiPaths.notificationDevice(token));
    } catch (_) {
      // Non-fatal.
    }
  }
}
