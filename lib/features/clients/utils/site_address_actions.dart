import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/utils/external_url.dart';
import '../data/models/client_models.dart';

Future<void> openSiteInMaps(ClientSiteOut site) async {
  await openMapLocation(
    latitude: site.latitude,
    longitude: site.longitude,
    label: site.mapsQueryLabel,
  );
}

Future<void> copySiteAddress(
  BuildContext context,
  ClientSiteOut site,
) async {
  final text = site.displayAddress;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Address copied')),
  );
}
