import 'package:url_launcher/url_launcher.dart';

/// Opens an https URL in the system browser / new tab.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return _launchExternal(uri);
}

/// Opens the device map app (or Maps in a browser) for [latitude]/[longitude]
/// when available, otherwise searches by [label].
Future<bool> openMapLocation({
  double? latitude,
  double? longitude,
  String? label,
}) async {
  final hasCoords = latitude != null && longitude != null;
  final query = hasCoords
      ? '$latitude,$longitude'
      : (label?.trim().isNotEmpty == true ? label!.trim() : null);
  if (query == null) return false;

  // Prefer geo: so Android can hand off to a installed Maps app.
  if (hasCoords) {
    final geo = Uri(
      scheme: 'geo',
      path: '$latitude,$longitude',
      queryParameters: {'q': '$latitude,$longitude'},
    );
    if (await _launchExternal(geo)) return true;
  }

  final https = Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': query},
  );
  return _launchExternal(https);
}

/// Tries [launchUrl] even when [canLaunchUrl] is false (common on Android 11+
/// if `<queries>` is incomplete); still returns false if launch throws.
Future<bool> _launchExternal(Uri uri) async {
  try {
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // Fallback: package visibility can make canLaunchUrl lie; attempt anyway.
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
