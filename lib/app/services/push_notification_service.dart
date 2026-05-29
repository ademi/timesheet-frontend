import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

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
      // Keep app functional even when Firebase is not configured in local env.
    }
  }

  Future<void> registerCurrentDeviceToken() async {
    try {
      await initialize();
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      final platform =
          kIsWeb
              ? 'web'
              : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android';
      await _authenticatedDio.post<Map<String, dynamic>>(
        '/v1/notifications/devices',
        data: {'token': token, 'platform': platform},
      );
    } catch (_) {
      // Non-fatal path.
    }
  }
}

