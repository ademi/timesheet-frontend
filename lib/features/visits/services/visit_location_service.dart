import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import '../data/models/visit_models.dart';

/// Result of a best-effort GPS capture for offline-first check-in.
class GpsAttempt {
  const GpsAttempt.captured(this.body)
      : status = 'captured',
        failReason = null;
  const GpsAttempt.failed(this.status, this.failReason) : body = null;

  final VisitGpsBody? body;
  final String status; // captured|unavailable|denied|timeout|skipped
  final String? failReason;
}

/// GPS helper for visit check-in / complete.
///
/// Web: always blocked (design §6.8). Mobile: requests permission + position.
/// Offline path uses [tryGps] which never blocks the punch on GPS failure.
class VisitLocationService {
  const VisitLocationService();

  bool get isWeb => kIsWeb;

  static const webBlockedMessage =
      'Check-in requires the mobile app with location enabled';

  /// Best-effort GPS; returns failed status instead of throwing (except web skip).
  Future<GpsAttempt> tryGps({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (kIsWeb) {
      return const GpsAttempt.failed('skipped', 'web_unsupported');
    }
    try {
      final body = await requireGps().timeout(timeout);
      return GpsAttempt.captured(body);
    } on VisitLocationException catch (e) {
      final lower = e.message.toLowerCase();
      final status =
          lower.contains('denied') || lower.contains('permanently')
              ? 'denied'
              : 'unavailable';
      return GpsAttempt.failed(status, e.message);
    } on TimeoutException {
      return const GpsAttempt.failed('timeout', 'gps_timeout');
    }
  }

  /// Returns GPS body, or throws [VisitLocationException].
  Future<VisitGpsBody> requireGps() async {
    if (kIsWeb) {
      throw const VisitLocationException(webBlockedMessage);
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const VisitLocationException(
        'Location services are disabled. Enable them to check in.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const VisitLocationException(
          'Location permission denied. Enable location to check in.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const VisitLocationException(
        'Location permission permanently denied. Enable it in settings.',
      );
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return VisitGpsBody(
      lat: pos.latitude,
      lng: pos.longitude,
      accuracyM: pos.accuracy,
    );
  }
}

class VisitLocationException implements Exception {
  const VisitLocationException(this.message);
  final String message;

  @override
  String toString() => message;
}
