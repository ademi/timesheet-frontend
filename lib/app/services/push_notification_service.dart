import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/api_paths.dart';

/// Registers FCM/APNs device tokens for both staff and contractor sessions.
class PushNotificationService {
  PushNotificationService({required Dio authenticatedDio})
      : _authenticatedDio = authenticatedDio;

  final Dio _authenticatedDio;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      await FirebaseMessaging.instance.requestPermission();
      _initialized = true;
    } catch (_) {
      // Keep app functional when Firebase is not configured locally.
    }
  }

  Future<void> registerCurrentDeviceToken() async {
    try {
      await initialize();
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null || token.length < 16) return;
      final platform = kIsWeb
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
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _authenticatedDio.delete<void>(
        ApiPaths.notificationDevice(token),
      );
    } catch (_) {
      // Non-fatal.
    }
  }
}
