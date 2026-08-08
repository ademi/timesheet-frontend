import 'package:url_launcher/url_launcher.dart';

/// Opens an https URL in the system browser / new tab.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
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

  final uri = Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': query},
  );
  if (!await canLaunchUrl(uri)) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
