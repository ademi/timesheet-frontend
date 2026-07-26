import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

import '../data/models/visit_models.dart';

/// GPS helper for visit check-in / complete.
///
/// Web: always blocked (design §6.8). Mobile: requests permission + position.
class VisitLocationService {
  const VisitLocationService();

  bool get isWeb => kIsWeb;

  static const webBlockedMessage =
      'Check-in requires the mobile app with location enabled';

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
